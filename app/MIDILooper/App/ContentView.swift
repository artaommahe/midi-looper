import SwiftUI

struct ContentView: View {
    @State private var isTransportRunning = true
    @State private var midiConnected = true
    @State private var bpmText = "120 BPM"
    @State private var activeBeat = 0
    @State private var tracks = TrackPanelState.mockTracks

    var body: some View {
        GeometryReader { proxy in
            let contentHeight = proxy.size.height - 28
            let trackHeight = max(120, (contentHeight - 88) / 4)

            VStack(spacing: 12) {
                header

                VStack(spacing: 10) {
                    ForEach($tracks) { $track in
                        TrackPanel(
                            track: $track,
                            height: trackHeight
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(isTransportRunning ? "STOP" : "PLAY") {
                isTransportRunning.toggle()
            }
            .buttonStyle(HeaderButtonStyle(isRunning: isTransportRunning))
            .layoutPriority(1)

            Text(midiConnected ? "MIDI OK" : "MIDI OFF")
                .font(.headline.monospaced())
                .foregroundStyle(midiConnected ? Color.green : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(bpmText)
                .font(.headline.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)

            BeatIndicator(activeBeat: activeBeat)
                .onTapGesture {
                    activeBeat = (activeBeat + 1) % 4
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct TrackPanel: View {
    @Binding var track: TrackPanelState

    let height: CGFloat

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
                        track.advanceRecordState()
                    }
                    .buttonStyle(
                        TrackButtonStyle(
                            isEnabled: true,
                            tint: track.recordButtonTint,
                            isActive: track.isRecordActionActive
                        )
                    )
                    .frame(width: recordWidth)

                    Button("MUTE") {
                        track.queueAction = track.queueAction == .mute ? .none : .mute
                    }
                    .buttonStyle(TrackButtonStyle(isEnabled: track.canQueueMuteOrSolo))
                    .frame(width: secondaryWidth)
                    .disabled(!track.canQueueMuteOrSolo)

                    Button("SOLO") {
                        track.queueAction = track.queueAction == .solo ? .none : .solo
                    }
                    .buttonStyle(TrackButtonStyle(isEnabled: track.canQueueMuteOrSolo))
                    .frame(width: secondaryWidth)
                    .disabled(!track.canQueueMuteOrSolo)

                    Button("CLEAR") {
                        track.queueAction = track.queueAction == .clear ? .none : .clear
                    }
                    .buttonStyle(TrackButtonStyle(isDestructive: true))
                    .frame(width: clearWidth)
                    .padding(.leading, clearGap)
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
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
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
            .frame(minWidth: 84)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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
    var primaryState: PrimaryTrackState
    var overlay: TrackOverlay?
    var queueAction: QueueAction

    var stateLabel: String {
        if let overlay {
            return "\(primaryState.rawValue) (\(overlay.rawValue))"
        }

        return primaryState.rawValue
    }

    var queueLabel: String {
        "[Q: \(queueAction.rawValue)]"
    }

    var canQueueMuteOrSolo: Bool {
        primaryState != .empty
    }

    var isRecordActionActive: Bool {
        primaryState == .armed || primaryState == .recording || primaryState == .overdub
    }

    var recordButtonTitle: String {
        switch primaryState {
        case .armed:
            return "ARMED"
        case .recording:
            return "REC"
        case .overdub:
            return "OD"
        case .empty, .playing:
            return "REC /\nOD"
        }
    }

    var recordButtonTint: Color {
        switch primaryState {
        case .armed:
            return .orange
        case .recording:
            return .red
        case .overdub:
            return .orange
        case .empty, .playing:
            return .primary
        }
    }

    var stateColor: Color {
        switch primaryState {
        case .recording:
            return .red
        case .overdub:
            return .orange
        case .armed:
            return .orange
        case .empty, .playing:
            return .primary
        }
    }

    mutating func advanceRecordState() {
        switch primaryState {
        case .empty:
            primaryState = .armed
            overlay = nil
            queueAction = .none
        case .armed:
            primaryState = .recording
            queueAction = .none
        case .recording:
            primaryState = .playing
            queueAction = .none
        case .playing:
            primaryState = .overdub
            queueAction = .none
        case .overdub:
            primaryState = .playing
            queueAction = .none
        }
    }

    static let mockTracks: [TrackPanelState] = [
        TrackPanelState(
            id: 1,
            title: "TRK 1",
            primaryState: .playing,
            overlay: nil,
            queueAction: .mute
        ),
        TrackPanelState(
            id: 2,
            title: "TRK 2",
            primaryState: .empty,
            overlay: nil,
            queueAction: .none
        ),
        TrackPanelState(
            id: 3,
            title: "TRK 3",
            primaryState: .recording,
            overlay: nil,
            queueAction: .none
        ),
        TrackPanelState(
            id: 4,
            title: "TRK 4",
            primaryState: .playing,
            overlay: .solo,
            queueAction: .none
        )
    ]
}

private enum PrimaryTrackState: String {
    case empty = "EMPTY"
    case armed = "ARMED"
    case recording = "RECORDING"
    case playing = "PLAYING"
    case overdub = "OVERDUB"
}

private enum TrackOverlay: String {
    case muted = "MUTED"
    case solo = "SOLO"
}

private enum QueueAction: String {
    case none = "--"
    case mute = "MUTE"
    case solo = "SOLO"
    case clear = "CLEAR"
    case record = "REC"
    case overdub = "OD"
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
