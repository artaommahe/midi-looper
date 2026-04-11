import SwiftUI

struct ContentView: View {
    @StateObject private var midi = MIDIPOCViewModel()

    @State private var showsMIDIDebugOverlay = false

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let contentHeight = proxy.size.height - 28
                let trackHeight = max(120, (contentHeight - 88) / 4)

                VStack(spacing: 12) {
                    header

                    VStack(spacing: 10) {
                        ForEach(trackStates) { track in
                            TrackPanel(
                                track: track,
                                height: trackHeight,
                                onRecord: {
                                    handleRecordTap(for: track.id)
                                },
                                onMute: {},
                                onSolo: {},
                                onClear: {
                                    handleClearTap(for: track.id)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGroupedBackground))
            }

            if showsMIDIDebugOverlay {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showsMIDIDebugOverlay = false
                    }

                MIDIDebugOverlay(
                    entries: midi.debugEntries,
                    inputStatusText: midi.inputStatusText,
                    outputStatusText: midi.outputStatusText,
                    liveThruEnabled: midi.liveThruEnabled,
                    selectedInputName: midi.selectedInputName,
                    selectedOutputName: midi.selectedOutputName,
                    lastReceivedEvent: midi.lastReceivedEvent,
                    lastEventTimestamp: midi.lastEventTimestamp,
                    onToggleLiveThru: {
                        midi.toggleLiveThru()
                    },
                    onClose: {
                        showsMIDIDebugOverlay = false
                    }
                )
                .padding(.top, 76)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showsMIDIDebugOverlay)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(midi.looperSnapshot.transportIsRunning ? "STOP" : "PLAY") {
                midi.toggleTransport()
            }
            .buttonStyle(HeaderButtonStyle(isRunning: midi.looperSnapshot.transportIsRunning))
            .frame(width: 92)

            Spacer(minLength: 10)

            Button {
                showsMIDIDebugOverlay.toggle()
            } label: {
                Text(midiStatusTitle)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(midiStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .frame(width: 68)

            Spacer(minLength: 10)

            Text(bpmText)
                .font(.subheadline.weight(.semibold).monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 74, alignment: .center)

            Spacer(minLength: 10)

            BeatIndicator(activeBeat: midi.looperSnapshot.activeBeat)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var midiStatusTitle: String {
        switch midi.connectionDisplayState {
        case .ok:
            return "MIDI OK"
        case .off:
            return "MIDI OFF"
        case .error:
            return "MIDI ERR"
        }
    }

    private var midiStatusColor: Color {
        switch midi.connectionDisplayState {
        case .ok:
            return .green
        case .off:
            return .secondary
        case .error:
            return .red
        }
    }

    private var bpmText: String {
        guard let bpm = midi.looperSnapshot.bpm else {
            return "-- BPM"
        }

        return "\(bpm) BPM"
    }

    private var trackStates: [TrackPanelState] {
        [trackOneState] + TrackPanelState.placeholderTracks
    }

    private var trackOneState: TrackPanelState {
        let snapshot = midi.looperSnapshot

        return TrackPanelState(
            id: 1,
            title: "TRK 1",
            primaryStateLabel: snapshot.trackState.rawValue,
            queueLabel: "[Q: \(snapshot.queuedAction.rawValue)]",
            stateColor: stateColor(for: snapshot.trackState),
            recordButtonTitle: snapshot.recordButtonTitle,
            recordButtonTint: recordTint(for: snapshot.trackState),
            isRecordActionActive: snapshot.trackState == .armed || snapshot.trackState == .recording,
            recordButtonEnabled: snapshot.recordButtonEnabled,
            muteButtonEnabled: false,
            soloButtonEnabled: false,
            clearButtonEnabled: snapshot.clearButtonEnabled
        )
    }

    private func stateColor(for state: LooperTrackPrimaryState) -> Color {
        switch state {
        case .empty, .playing:
            return .primary
        case .armed:
            return .orange
        case .recording:
            return .red
        }
    }

    private func recordTint(for state: LooperTrackPrimaryState) -> Color {
        switch state {
        case .empty, .playing:
            return .primary
        case .armed:
            return .orange
        case .recording:
            return .red
        }
    }

    private func handleRecordTap(for trackID: Int) {
        guard trackID == 1 else { return }
        midi.handleTrackOneRecordButton()
    }

    private func handleClearTap(for trackID: Int) {
        guard trackID == 1 else { return }
        midi.handleTrackOneClearButton()
    }
}

private struct MIDIDebugOverlay: View {
    let entries: [MIDIDebugEntry]
    let inputStatusText: String
    let outputStatusText: String
    let liveThruEnabled: Bool
    let selectedInputName: String
    let selectedOutputName: String
    let lastReceivedEvent: String
    let lastEventTimestamp: String
    let onToggleLiveThru: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MIDI DEBUG")
                    .font(.headline.weight(.semibold).monospaced())

                Spacer()

                Button("CLOSE", action: onClose)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                debugRow("INPUT", value: "\(inputStatusText) | \(selectedInputName)")
                debugRow("OUTPUT", value: "\(outputStatusText) | \(selectedOutputName)")
                debugRow("THRU", value: liveThruEnabled ? "Enabled" : "Disabled")
                debugRow("LAST", value: lastEventLine)
            }

            Button(liveThruEnabled ? "LIVE THRU ON" : "LIVE THRU OFF", action: onToggleLiveThru)
                .buttonStyle(.bordered)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if entries.isEmpty {
                        Text("No MIDI debug events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            Text("[\(entry.timestamp)] \(entry.message)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    private var lastEventLine: String {
        if lastEventTimestamp.isEmpty {
            return lastReceivedEvent
        }

        return "\(lastEventTimestamp) | \(lastReceivedEvent)"
    }

    private func debugRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.monospaced())
    }
}

private struct TrackPanel: View {
    let track: TrackPanelState
    let height: CGFloat
    let onRecord: () -> Void
    let onMute: () -> Void
    let onSolo: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold).monospaced())

                Text("|")
                    .foregroundStyle(.secondary)

                Text(track.stateLabel)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(track.stateColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(track.queueLabel)
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }

            GeometryReader { proxy in
                let spacing: CGFloat = 10
                let clearGap: CGFloat = 12
                let availableWidth = proxy.size.width - (spacing * 3) - clearGap
                let unit = availableWidth / 5.0
                let recordWidth = unit * 1.4
                let secondaryWidth = unit * 1.05
                let clearWidth = unit * 1.5

                HStack(spacing: spacing) {
                    Button(track.recordButtonTitle) {
                        onRecord()
                    }
                    .buttonStyle(
                        TrackButtonStyle(
                            isEnabled: track.recordButtonEnabled,
                            tint: track.recordButtonTint,
                            isActive: track.isRecordActionActive
                        )
                    )
                    .frame(width: recordWidth)
                    .disabled(!track.recordButtonEnabled)

                    Button("MUTE") {
                        onMute()
                    }
                    .buttonStyle(TrackButtonStyle(isEnabled: track.muteButtonEnabled))
                    .frame(width: secondaryWidth)
                    .disabled(!track.muteButtonEnabled)

                    Button("SOLO") {
                        onSolo()
                    }
                    .buttonStyle(TrackButtonStyle(isEnabled: track.soloButtonEnabled))
                    .frame(width: secondaryWidth)
                    .disabled(!track.soloButtonEnabled)

                    Button("CLEAR") {
                        onClear()
                    }
                    .buttonStyle(TrackButtonStyle(isEnabled: track.clearButtonEnabled, isDestructive: true))
                    .frame(width: clearWidth)
                    .padding(.leading, clearGap)
                    .disabled(!track.clearButtonEnabled)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

private struct BeatIndicator: View {
    let activeBeat: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == activeBeat ? Color.primary : Color.clear)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 9)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .accessibilityLabel("Beat indicator")
        .accessibilityValue("Beat \(activeBeat + 1) of 4")
    }
}

private struct HeaderButtonStyle: ButtonStyle {
    let isRunning: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.monospaced())
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var foregroundColor: Color {
        isRunning ? Color.red : Color.green
    }

    private var backgroundColor: Color {
        isRunning ? Color.red.opacity(0.12) : Color.green.opacity(0.12)
    }

    private var borderColor: Color {
        isRunning ? Color.red.opacity(0.45) : Color.green.opacity(0.45)
    }
}

private struct TrackButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isDestructive: Bool
    let tint: Color
    let isActive: Bool

    init(
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        tint: Color = .primary,
        isActive: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.tint = tint
        self.isActive = isActive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold).monospaced())
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor(configuration: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.55)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if !isEnabled {
            return Color(.tertiarySystemFill)
        }

        if isDestructive {
            return configuration.isPressed ? Color.red.opacity(0.2) : Color(.systemBackground)
        }

        if isActive {
            return configuration.isPressed ? tint.opacity(0.26) : tint.opacity(0.18)
        }

        return configuration.isPressed ? Color(.tertiarySystemFill) : Color(.systemBackground)
    }

    private var borderColor: Color {
        if isDestructive {
            return .red.opacity(0.5)
        }

        if isActive {
            return tint.opacity(0.75)
        }

        return Color(.separator)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return .secondary
        }

        if isActive {
            return tint
        }

        return .primary
    }
}

private struct TrackPanelState: Identifiable {
    let id: Int
    let title: String
    let primaryStateLabel: String
    let queueLabel: String
    let stateColor: Color
    let recordButtonTitle: String
    let recordButtonTint: Color
    let isRecordActionActive: Bool
    let recordButtonEnabled: Bool
    let muteButtonEnabled: Bool
    let soloButtonEnabled: Bool
    let clearButtonEnabled: Bool

    var stateLabel: String { primaryStateLabel }

    static let placeholderTracks: [TrackPanelState] = [
        TrackPanelState(
            id: 2,
            title: "TRK 2",
            primaryStateLabel: "EMPTY",
            queueLabel: "[Q: --]",
            stateColor: .primary,
            recordButtonTitle: "REC /\nOD",
            recordButtonTint: .primary,
            isRecordActionActive: false,
            recordButtonEnabled: false,
            muteButtonEnabled: false,
            soloButtonEnabled: false,
            clearButtonEnabled: false
        ),
        TrackPanelState(
            id: 3,
            title: "TRK 3",
            primaryStateLabel: "EMPTY",
            queueLabel: "[Q: --]",
            stateColor: .primary,
            recordButtonTitle: "REC /\nOD",
            recordButtonTint: .primary,
            isRecordActionActive: false,
            recordButtonEnabled: false,
            muteButtonEnabled: false,
            soloButtonEnabled: false,
            clearButtonEnabled: false
        ),
        TrackPanelState(
            id: 4,
            title: "TRK 4",
            primaryStateLabel: "EMPTY",
            queueLabel: "[Q: --]",
            stateColor: .primary,
            recordButtonTitle: "REC /\nOD",
            recordButtonTint: .primary,
            isRecordActionActive: false,
            recordButtonEnabled: false,
            muteButtonEnabled: false,
            soloButtonEnabled: false,
            clearButtonEnabled: false
        )
    ]
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
