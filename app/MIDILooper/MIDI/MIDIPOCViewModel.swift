import Combine
import CoreMIDI
import Foundation
import OSLog
import SwiftUI

struct MIDIEndpointDescriptor: Identifiable, Equatable, Sendable {
    let id: MIDIUniqueID
    let ref: MIDIEndpointRef
    let name: String
    let detail: String
    let isPreferred: Bool
    let isNetworkSession: Bool
}

struct MIDIForwardMessage: Equatable, Sendable {
    let rawBytes: [UInt8]
    let displayText: String
}

enum MIDIMessageParser {
    nonisolated static func forwardedMessages(from bytes: [UInt8]) -> [MIDIForwardMessage] {
        var messages: [MIDIForwardMessage] = []
        var index = 0
        var runningStatus: UInt8?

        while index < bytes.count {
            let firstByte = bytes[index]

            if firstByte >= 0xF8 {
                index += 1
                continue
            }

            let statusByte: UInt8
            if firstByte & 0x80 == 0 {
                guard let runningStatus else {
                    index += 1
                    continue
                }
                statusByte = runningStatus
            } else {
                statusByte = firstByte
                if statusByte < 0xF0 {
                    runningStatus = statusByte
                } else {
                    runningStatus = nil
                }
                index += 1
            }

            let messageLength = midiMessageLength(for: statusByte)
            guard messageLength > 0 else { continue }

            let dataLength = messageLength - 1
            guard index + dataLength <= bytes.count else { break }

            let data = Array(bytes[index..<(index + dataLength)])
            index += dataLength

            guard let message = forwardedMessage(status: statusByte, data: data) else {
                continue
            }

            messages.append(message)
        }

        return messages
    }

    nonisolated private static func midiMessageLength(for status: UInt8) -> Int {
        switch status {
        case 0x80 ... 0x8F, 0x90 ... 0x9F, 0xA0 ... 0xAF, 0xB0 ... 0xBF, 0xE0 ... 0xEF:
            return 3
        case 0xC0 ... 0xDF:
            return 2
        default:
            return 0
        }
    }

    nonisolated private static func forwardedMessage(status: UInt8, data: [UInt8]) -> MIDIForwardMessage? {
        let type = status & 0xF0
        let channel = Int(status & 0x0F) + 1

        switch type {
        case 0x80:
            guard data.count == 2 else { return nil }
            return MIDIForwardMessage(
                rawBytes: [status] + data,
                displayText: "Note Off ch\(channel) \(noteName(for: data[0])) vel \(data[1])"
            )
        case 0x90:
            guard data.count == 2 else { return nil }
            let eventName = data[1] == 0 ? "Note Off" : "Note On"
            return MIDIForwardMessage(
                rawBytes: [status] + data,
                displayText: "\(eventName) ch\(channel) \(noteName(for: data[0])) vel \(data[1])"
            )
        case 0xB0:
            guard data.count == 2, data[0] == 64 else { return nil }
            let pedalState = data[1] >= 64 ? "down" : "up"
            return MIDIForwardMessage(
                rawBytes: [status] + data,
                displayText: "Sustain ch\(channel) \(pedalState) val \(data[1])"
            )
        default:
            return nil
        }
    }

    nonisolated private static func noteName(for note: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let pitchClass = names[Int(note % 12)]
        let octave = (Int(note) / 12) - 1
        return "\(pitchClass)\(octave)"
    }
}

@MainActor
final class MIDIPOCViewModel: ObservableObject {
    @Published private(set) var availableInputs: [MIDIEndpointDescriptor] = []
    @Published private(set) var availableOutputs: [MIDIEndpointDescriptor] = []
    @Published private(set) var selectedInputName = "Not connected"
    @Published private(set) var selectedOutputName = "Not connected"
    @Published private(set) var inputStatusText = "Disconnected"
    @Published private(set) var outputStatusText = "Disconnected"
    @Published private(set) var lastReceivedEvent = "No MIDI received yet"
    @Published private(set) var lastEventTimestamp = ""

    let preferredDeviceName = "Roland FP-10"

    nonisolated(unsafe) private var client = MIDIClientRef()
    nonisolated(unsafe) private var inputPort = MIDIPortRef()
    nonisolated(unsafe) private var outputPort = MIDIPortRef()
    nonisolated(unsafe) private var selectedSource = MIDIEndpointRef()
    nonisolated(unsafe) private var selectedDestination = MIDIEndpointRef()

    private let logger = Logger(subsystem: "com.mkraai.MIDILooper", category: "CoreMIDI")
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    init() {
        setupMIDI()
        refreshEndpoints()
    }

    func refreshEndpoints() {
        let inputs = enumerateEndpoints(count: MIDIGetNumberOfSources(), endpointAtIndex: MIDIGetSource)
        let outputs = enumerateEndpoints(count: MIDIGetNumberOfDestinations(), endpointAtIndex: MIDIGetDestination)

        availableInputs = inputs
        availableOutputs = outputs

        connectPreferredInput(from: inputs)
        connectPreferredOutput(from: outputs)
    }

    private func setupMIDI() {
        guard client == 0 else { return }

        var createdClient = MIDIClientRef()
        var createdInputPort = MIDIPortRef()
        var createdOutputPort = MIDIPortRef()

        let clientStatus = MIDIClientCreateWithBlock("MIDILooper" as CFString, &createdClient) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshEndpoints()
            }
        }

        guard clientStatus == noErr else {
            logger.error("Failed to create MIDI client: \(clientStatus)")
            inputStatusText = "CoreMIDI unavailable"
            outputStatusText = "CoreMIDI unavailable"
            return
        }

        let inputStatus = MIDIInputPortCreateWithBlock(createdClient, "MIDILooper Input" as CFString, &createdInputPort) { [weak self] packetList, _ in
            self?.handlePacketList(packetList)
        }

        guard inputStatus == noErr else {
            logger.error("Failed to create MIDI input port: \(inputStatus)")
            inputStatusText = "Input port failed"
            outputStatusText = "Input port failed"
            client = createdClient
            return
        }

        let outputStatus = MIDIOutputPortCreate(createdClient, "MIDILooper Output" as CFString, &createdOutputPort)
        guard outputStatus == noErr else {
            logger.error("Failed to create MIDI output port: \(outputStatus)")
            inputStatusText = "Output port failed"
            outputStatusText = "Output port failed"
            client = createdClient
            inputPort = createdInputPort
            return
        }

        client = createdClient
        inputPort = createdInputPort
        outputPort = createdOutputPort
    }

    private func enumerateEndpoints(
        count: Int,
        endpointAtIndex: (Int) -> MIDIEndpointRef
    ) -> [MIDIEndpointDescriptor] {
        (0 ..< count).compactMap { index in
            let endpoint = endpointAtIndex(index)
            guard endpoint != 0 else { return nil }

            let name = endpointName(for: endpoint)
            let detail = endpointDetail(for: endpoint)
            let combinedName = [name, detail]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let uniqueID = endpointUniqueID(for: endpoint)
            let preferred = isPreferredEndpointName(combinedName)
            let isNetworkSession = combinedName.localizedCaseInsensitiveContains("network session")

            return MIDIEndpointDescriptor(
                id: uniqueID,
                ref: endpoint,
                name: name,
                detail: detail,
                isPreferred: preferred,
                isNetworkSession: isNetworkSession
            )
        }
    }

    private func connectPreferredInput(from inputs: [MIDIEndpointDescriptor]) {
        let preferredInput = preferredEndpoint(in: inputs)

        if selectedSource != 0, selectedSource != preferredInput?.ref {
            MIDIPortDisconnectSource(inputPort, selectedSource)
            selectedSource = 0
        }

        guard let preferredInput else {
            selectedInputName = "Not connected"
            inputStatusText = "Disconnected"
            return
        }

        if selectedSource == 0 {
            let status = MIDIPortConnectSource(inputPort, preferredInput.ref, nil)
            if status != noErr {
                logger.error("Failed to connect MIDI input: \(status)")
                selectedInputName = preferredInput.name
                inputStatusText = "Connect failed"
                return
            }

            selectedSource = preferredInput.ref
        }

        selectedInputName = preferredInput.name
        inputStatusText = preferredInput.isPreferred ? "Connected to FP-10" : "Connected"
    }

    private func connectPreferredOutput(from outputs: [MIDIEndpointDescriptor]) {
        guard let preferredOutput = preferredEndpoint(in: outputs) else {
            selectedDestination = 0
            selectedOutputName = "Not connected"
            outputStatusText = "Disconnected"
            return
        }

        selectedDestination = preferredOutput.ref
        selectedOutputName = preferredOutput.name
        outputStatusText = preferredOutput.isPreferred ? "Connected to FP-10" : "Connected"
    }

    private func preferredEndpoint(in endpoints: [MIDIEndpointDescriptor]) -> MIDIEndpointDescriptor? {
        if let preferred = endpoints.first(where: \.isPreferred) {
            return preferred
        }

        if let nonNetworkEndpoint = endpoints.first(where: { !$0.isNetworkSession }) {
            return nonNetworkEndpoint
        }

        return endpoints.first
    }

    private func isPreferredEndpointName(_ text: String) -> Bool {
        let normalizedText = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return normalizedText.contains("fp-10") || normalizedText.contains("roland")
    }

    private func endpointName(for endpoint: MIDIEndpointRef) -> String {
        midiStringProperty(on: endpoint, property: kMIDIPropertyDisplayName)
            ?? midiStringProperty(on: endpoint, property: kMIDIPropertyName)
            ?? "Unnamed Endpoint"
    }

    private func endpointDetail(for endpoint: MIDIEndpointRef) -> String {
        let manufacturer = midiStringProperty(on: endpoint, property: kMIDIPropertyManufacturer)
        let model = midiStringProperty(on: endpoint, property: kMIDIPropertyModel)

        return [manufacturer, model]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " ")
    }

    private func endpointUniqueID(for endpoint: MIDIEndpointRef) -> MIDIUniqueID {
        var uniqueID: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        return status == noErr ? uniqueID : Int32(endpoint)
    }

    private func midiStringProperty(on object: MIDIObjectRef, property: CFString) -> String? {
        var value: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, property, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    nonisolated private func handlePacketList(_ packetList: UnsafePointer<MIDIPacketList>) {
        let packetListValue = packetList.pointee
        var packet = packetListValue.packet

        for packetIndex in 0 ..< packetListValue.numPackets {
            let packetBytes = withUnsafeBytes(of: packet.data) { rawBuffer in
                Array(rawBuffer.prefix(Int(packet.length)))
            }

            let messages = MIDIMessageParser.forwardedMessages(from: packetBytes)
            if !messages.isEmpty {
                forward(messages: messages)
                updateLastReceivedEvent(messages.last?.displayText ?? "")
            }

            if packetIndex < packetListValue.numPackets - 1 {
                packet = MIDIPacketNext(&packet).pointee
            }
        }
    }

    nonisolated private func forward(messages: [MIDIForwardMessage]) {
        guard outputPort != 0, selectedDestination != 0 else { return }

        let bytes = messages.flatMap(\.rawBytes)
        var packetBuffer = [UInt8](repeating: 0, count: 1024)

        let status: OSStatus = packetBuffer.withUnsafeMutableBytes { rawBuffer in
            guard let packetListPointer = rawBuffer.baseAddress?.assumingMemoryBound(to: MIDIPacketList.self) else {
                return kMIDIUnknownError
            }

            let destination = selectedDestination
            let port = outputPort
            let packetPointer = MIDIPacketListInit(packetListPointer)

            return bytes.withUnsafeBufferPointer { bytesPointer in
                guard let baseAddress = bytesPointer.baseAddress else {
                    return kMIDIMessageSendErr
                }

                let nextPacketPointer = MIDIPacketListAdd(packetListPointer, rawBuffer.count, packetPointer, 0, bytesPointer.count, baseAddress)
                guard nextPacketPointer != UnsafeMutablePointer<MIDIPacket>.init(bitPattern: 0) else {
                    return kMIDIMessageSendErr
                }

                return MIDISend(port, destination, packetListPointer)
            }
        }

        if status != noErr {
            Task { @MainActor [weak self] in
                self?.outputStatusText = "Send failed"
            }
        }
    }

    nonisolated private func updateLastReceivedEvent(_ text: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            lastReceivedEvent = text
            lastEventTimestamp = timestampFormatter.string(from: Date())
        }
    }
}
