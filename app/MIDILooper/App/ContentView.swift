import SwiftUI

struct ContentView: View {
    @StateObject private var midi = MIDIPOCViewModel()

    var body: some View {
        NavigationStack {
            List {
                statusSection
                selectionSection
                endpointsSection(title: "Inputs", endpoints: midi.availableInputs)
                endpointsSection(title: "Outputs", endpoints: midi.availableOutputs)
                eventSection
            }
            .navigationTitle("MIDI Thru")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        midi.refreshEndpoints()
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Connection") {
            statusRow(title: "Preferred Device", value: midi.preferredDeviceName)
            statusRow(title: "Input", value: midi.inputStatusText)
            statusRow(title: "Output", value: midi.outputStatusText)
            statusRow(title: "Thru Filter", value: "Note on/off + sustain pedal")
        }
    }

    private var selectionSection: some View {
        Section("Selected Endpoints") {
            statusRow(title: "Input Source", value: midi.selectedInputName)
            statusRow(title: "Output Destination", value: midi.selectedOutputName)
        }
    }

    private func endpointsSection(title: String, endpoints: [MIDIEndpointDescriptor]) -> some View {
        Section(title) {
            if endpoints.isEmpty {
                Text("No endpoints detected")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(endpoints) { endpoint in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(endpoint.name)
                            Spacer()
                            if endpoint.isPreferred {
                                Text("FP-10")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }

                        if !endpoint.detail.isEmpty {
                            Text(endpoint.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var eventSection: some View {
        Section("Last Received Event") {
            Text(midi.lastReceivedEvent)
                .font(.body.monospaced())
            if !midi.lastEventTimestamp.isEmpty {
                Text(midi.lastEventTimestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
