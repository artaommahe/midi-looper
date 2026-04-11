import Foundation

enum LooperTrackPrimaryState: String, Equatable, Sendable {
    case empty = "EMPTY"
    case armed = "ARMED"
    case recording = "RECORDING"
    case playing = "PLAYING"
}

enum LooperQueuedAction: String, Equatable, Sendable {
    case none = "--"
    case clear = "CLEAR"
}

struct SingleTrackLooperSnapshot: Equatable, Sendable {
    var transportIsRunning: Bool
    var bpm: Int?
    var activeBeat: Int
    var trackState: LooperTrackPrimaryState
    var queuedAction: LooperQueuedAction
    var recordButtonTitle: String
    var recordButtonEnabled: Bool
    var clearButtonEnabled: Bool

    static let empty = SingleTrackLooperSnapshot(
        transportIsRunning: false,
        bpm: nil,
        activeBeat: 0,
        trackState: .empty,
        queuedAction: .none,
        recordButtonTitle: "REC",
        recordButtonEnabled: true,
        clearButtonEnabled: false
    )
}

struct RecordedMIDIEvent: Equatable, Sendable {
    var offset: TimeInterval
    let rawBytes: [UInt8]
}

struct SingleTrackLooperEngine {
    private enum Constants {
        static let beatCount = 4.0
        static let minimumLoopDuration = 0.2
        static let playbackLookaheadEpsilon = 0.000_001
    }

    private struct ChannelNote: Hashable {
        let channel: UInt8
        let note: UInt8
    }

    private(set) var transportIsRunning = false
    private(set) var trackState: LooperTrackPrimaryState = .empty
    private(set) var queuedAction: LooperQueuedAction = .none
    private(set) var bpm: Int?
    private(set) var loopDuration: TimeInterval?

    private var recordedEvents: [RecordedMIDIEvent] = []
    private var recordingStartTime: TimeInterval?
    private var playbackCycleStartTime: TimeInterval?
    private var lastPlaybackTime: TimeInterval?
    private var activePlaybackNotes: Set<ChannelNote> = []
    private var sustainChannels: Set<UInt8> = []

    mutating func snapshot(at now: TimeInterval) -> SingleTrackLooperSnapshot {
        SingleTrackLooperSnapshot(
            transportIsRunning: transportIsRunning,
            bpm: bpm,
            activeBeat: activeBeat(at: now),
            trackState: trackState,
            queuedAction: queuedAction,
            recordButtonTitle: recordButtonTitle,
            recordButtonEnabled: recordButtonEnabled,
            clearButtonEnabled: clearButtonEnabled
        )
    }

    mutating func toggleTransport(at now: TimeInterval) -> [[UInt8]] {
        if transportIsRunning {
            transportIsRunning = false
            queuedAction = .none
            playbackCycleStartTime = nil
            lastPlaybackTime = nil

            if loopDuration == nil {
                trackState = .empty
                recordingStartTime = nil
                recordedEvents.removeAll()
            }

            return releasePlaybackState()
        }

        transportIsRunning = true

        if trackState == .playing, loopDuration != nil {
            playbackCycleStartTime = now
            lastPlaybackTime = now
        }

        return []
    }

    mutating func handleRecordButton(at now: TimeInterval) -> [[UInt8]] {
        switch trackState {
        case .empty:
            transportIsRunning = true
            trackState = .armed
            queuedAction = .none
            return []
        case .armed:
            trackState = .empty
            return []
        case .recording:
            return finalizeLoop(at: now)
        case .playing:
            return []
        }
    }

    mutating func handleClearButton(at now: TimeInterval) -> [[UInt8]] {
        switch trackState {
        case .empty:
            return []
        case .armed:
            trackState = .empty
            queuedAction = .none
            return []
        case .recording:
            return clearImmediately()
        case .playing:
            if transportIsRunning {
                queuedAction = queuedAction == .clear ? .none : .clear
                return []
            }

            return clearImmediately()
        }
    }

    mutating func handleIncomingMessages(_ rawMessages: [[UInt8]], at now: TimeInterval) {
        guard !rawMessages.isEmpty else { return }

        if trackState == .armed {
            trackState = .recording
            recordingStartTime = now
            recordedEvents.removeAll()
            queuedAction = .none
        }

        guard trackState == .recording, let recordingStartTime else {
            return
        }

        let offset = max(0, now - recordingStartTime)
        for rawBytes in rawMessages {
            recordedEvents.append(RecordedMIDIEvent(offset: offset, rawBytes: rawBytes))
        }
    }

    mutating func advancePlayback(to now: TimeInterval) -> [[UInt8]] {
        guard transportIsRunning,
              trackState == .playing,
              let loopDuration,
              let playbackCycleStartTime,
              let lastPlaybackTime else {
            return []
        }

        let previousElapsed = max(0, lastPlaybackTime - playbackCycleStartTime)
        let currentElapsed = max(0, now - playbackCycleStartTime)
        guard currentElapsed > previousElapsed else { return [] }

        var emittedMessages: [[UInt8]] = []
        var scanElapsed = previousElapsed

        while scanElapsed < currentElapsed {
            let cycleIndex = floor(scanElapsed / loopDuration)
            let cycleBase = cycleIndex * loopDuration
            let windowStart = scanElapsed - cycleBase
            let windowEnd = min(currentElapsed - cycleBase, loopDuration)

            emittedMessages.append(contentsOf: eventsBetween(start: windowStart, end: windowEnd))

            if windowEnd < loopDuration {
                break
            }

            scanElapsed = cycleBase + loopDuration

            if queuedAction == .clear {
                self.lastPlaybackTime = now
                emittedMessages.append(contentsOf: clearImmediately())
                return emittedMessages
            }

            emittedMessages.append(contentsOf: loopStartEvents())
            scanElapsed += Constants.playbackLookaheadEpsilon
        }

        self.lastPlaybackTime = now
        return emittedMessages
    }

    private var recordButtonTitle: String {
        switch trackState {
        case .empty:
            return "REC"
        case .armed:
            return "ARMED"
        case .recording:
            return "STOP"
        case .playing:
            return "REC /\nOD"
        }
    }

    private var recordButtonEnabled: Bool {
        trackState != .playing
    }

    private var clearButtonEnabled: Bool {
        trackState != .empty
    }

    private mutating func finalizeLoop(at now: TimeInterval) -> [[UInt8]] {
        guard let recordingStartTime, !recordedEvents.isEmpty else {
            return clearImmediately()
        }

        let duration = max(Constants.minimumLoopDuration, now - recordingStartTime)
        let upperBound = max(0, duration - Constants.playbackLookaheadEpsilon)

        recordedEvents = recordedEvents.map { event in
            RecordedMIDIEvent(offset: min(event.offset, upperBound), rawBytes: event.rawBytes)
        }
        recordedEvents.sort { lhs, rhs in
            if lhs.offset == rhs.offset {
                return lhs.rawBytes.lexicographicallyPrecedes(rhs.rawBytes)
            }

            return lhs.offset < rhs.offset
        }

        loopDuration = duration
        bpm = Int((60.0 * Constants.beatCount / duration).rounded())
        trackState = .playing
        queuedAction = .none
        self.recordingStartTime = nil
        playbackCycleStartTime = now
        let immediateEvents = eventsBetween(start: 0, end: Constants.playbackLookaheadEpsilon)
        lastPlaybackTime = now + Constants.playbackLookaheadEpsilon
        return immediateEvents
    }

    private mutating func clearImmediately() -> [[UInt8]] {
        let releases = releasePlaybackState()
        trackState = .empty
        queuedAction = .none
        bpm = nil
        loopDuration = nil
        recordingStartTime = nil
        playbackCycleStartTime = nil
        lastPlaybackTime = nil
        recordedEvents.removeAll()
        return releases
    }

    private mutating func releasePlaybackState() -> [[UInt8]] {
        let noteOffs = activePlaybackNotes
            .sorted { lhs, rhs in
                if lhs.channel == rhs.channel {
                    return lhs.note < rhs.note
                }

                return lhs.channel < rhs.channel
            }
            .map { note in
                [0x80 | note.channel, note.note, 0]
            }
        let sustainOffs = sustainChannels
            .sorted()
            .map { channel in
                [0xB0 | channel, 64, 0]
            }

        activePlaybackNotes.removeAll()
        sustainChannels.removeAll()
        return noteOffs + sustainOffs
    }

    private mutating func eventsBetween(start: TimeInterval, end: TimeInterval) -> [[UInt8]] {
        guard let loopDuration else { return [] }
        let includeZeroOffset = start == 0

        let dueEvents = recordedEvents.filter { event in
            let isAfterStart = event.offset > start || (includeZeroOffset && event.offset == 0)
            return isAfterStart && event.offset <= min(end, loopDuration)
        }

        for event in dueEvents {
            trackPlaybackState(for: event.rawBytes)
        }

        return dueEvents.map(\.rawBytes)
    }

    private mutating func loopStartEvents() -> [[UInt8]] {
        let dueEvents = recordedEvents.filter { $0.offset == 0 }

        for event in dueEvents {
            trackPlaybackState(for: event.rawBytes)
        }

        return dueEvents.map(\.rawBytes)
    }

    private mutating func trackPlaybackState(for rawBytes: [UInt8]) {
        guard rawBytes.count == 3 else { return }

        let status = rawBytes[0] & 0xF0
        let channel = rawBytes[0] & 0x0F

        switch status {
        case 0x80:
            activePlaybackNotes.remove(ChannelNote(channel: channel, note: rawBytes[1]))
        case 0x90:
            let note = ChannelNote(channel: channel, note: rawBytes[1])
            if rawBytes[2] == 0 {
                activePlaybackNotes.remove(note)
            } else {
                activePlaybackNotes.insert(note)
            }
        case 0xB0 where rawBytes[1] == 64:
            if rawBytes[2] >= 64 {
                sustainChannels.insert(channel)
            } else {
                sustainChannels.remove(channel)
            }
        default:
            break
        }
    }

    private func activeBeat(at now: TimeInterval) -> Int {
        guard transportIsRunning,
              trackState == .playing,
              let loopDuration,
              let playbackCycleStartTime,
              loopDuration > 0 else {
            return 0
        }

        let elapsed = max(0, now - playbackCycleStartTime)
        let position = elapsed.truncatingRemainder(dividingBy: loopDuration)
        let normalized = min(max(position / loopDuration, 0), 0.999_999)
        return Int(normalized * Constants.beatCount)
    }
}
