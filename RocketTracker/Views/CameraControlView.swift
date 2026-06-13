import SwiftUI

struct CameraControlView: View {
    @StateObject private var cameraService = CameraControlService()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBand: SG2VtxBand = .a
    @State private var selectedChannel: Int = 1
    @State private var selectedPower: SG2VtxPowerLevel = .vtxPit
    @State private var rfEnabled = false
    @State private var cameraRecording = false

    var body: some View {
        NavigationStack {
            Form {
                connectionSection

                if cameraService.isConnected {
                    statusSection
                    radioSection
                    cameraSection
                }
            }
            .navigationTitle("RocketCam")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if cameraService.isConnected {
                        Button(action: cameraService.requestStatus) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .onChange(of: cameraService.cameraConfig) { _, config in
                guard let config else { return }
                selectedBand = config.band
                selectedChannel = max(1, Int(config.channel))
                selectedPower = config.power
                rfEnabled = config.rfEnabled
                cameraRecording = config.cameraRecording
            }
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Label(
                    cameraService.isConnected ? "Connected" : cameraService.statusMessage,
                    systemImage: cameraService.isConnected ? "checkmark.circle.fill" : "video"
                )
                Spacer()
                if cameraService.isScanning {
                    ProgressView()
                }
            }

            if cameraService.isConnected {
                Button(role: .destructive, action: cameraService.disconnect) {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
            } else {
                Button(action: cameraService.isScanning ? cameraService.stopScanning : cameraService.startScanning) {
                    Label(cameraService.isScanning ? "Stop Scanning" : "Scan for RocketCam", systemImage: "dot.radiowaves.left.and.right")
                }

                ForEach(cameraService.discoveredDevices) { camera in
                    Button(action: { cameraService.connect(to: camera) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(camera.name)
                                Text(camera.peripheral.identifier.uuidString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(camera.rssi.intValue) dBm")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            if let config = cameraService.cameraConfig {
                LabeledContent("Frequency", value: config.freqMhz == 0 ? "Unknown" : "\(config.freqMhz) MHz")
                LabeledContent("Output", value: "\(config.actualPowerMw) mW")
                LabeledContent("VTX", value: config.vtxResponsive ? "Responsive" : "No response")
                LabeledContent("Flight State", value: flightStateLabel(config.flightState))
                LabeledContent("Altitude", value: String(format: "%.1f m", config.altitudeAglM))
            } else {
                Text("Waiting for camera status")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var radioSection: some View {
        Section("Video Radio") {
            Picker("Band", selection: $selectedBand) {
                Text("A").tag(SG2VtxBand.a)
                Text("B").tag(SG2VtxBand.b)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedBand) { _, newValue in
                cameraService.setBand(newValue, channel: UInt32(selectedChannel))
            }

            Stepper("Channel \(selectedChannel)", value: $selectedChannel, in: 1...8)
                .onChange(of: selectedChannel) { _, newValue in
                    cameraService.setBand(selectedBand, channel: UInt32(newValue))
                }

            Picker("Power", selection: $selectedPower) {
                Text("Pit").tag(SG2VtxPowerLevel.vtxPit)
                Text("25 mW").tag(SG2VtxPowerLevel.vtx25Mw)
                Text("200 mW").tag(SG2VtxPowerLevel.vtx200Mw)
                Text("1 W").tag(SG2VtxPowerLevel.vtx1000Mw)
                Text("4 W").tag(SG2VtxPowerLevel.vtx4000Mw)
            }
            .onChange(of: selectedPower) { _, newValue in
                cameraService.setPower(newValue)
            }

            Toggle("RF Enabled", isOn: $rfEnabled)
                .onChange(of: rfEnabled) { _, newValue in
                    cameraService.setRFEnabled(newValue)
                }
        }
    }

    private var cameraSection: some View {
        Section("Camera") {
            Toggle("Recording", isOn: $cameraRecording)
                .onChange(of: cameraRecording) { _, newValue in
                    cameraService.setCameraRecording(newValue)
                }
        }
    }

    private func flightStateLabel(_ state: SG2FlightState) -> String {
        switch state {
        case .fsUnknown:
            return "Unknown"
        case .fsPad:
            return "Pad"
        case .fsBoost:
            return "Boost"
        case .fsCoast:
            return "Coast"
        case .fsApogee:
            return "Apogee"
        case .fsRecovery:
            return "Recovery"
        case .fsLanded:
            return "Landed"
        case .UNRECOGNIZED(let value):
            return "State \(value)"
        }
    }
}

#Preview {
    CameraControlView()
}
