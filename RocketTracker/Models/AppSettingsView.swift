import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var presenter: MainPresenter

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        Toggle("Demo Mode (Generate Fake Telemetry)", isOn: $presenter.isDemoModeEnabled)

                        HStack {
                            Label("Status", systemImage: presenter.isDemoModeEnabled ? "play.circle" : "pause.circle")
                            Text(presenter.isDemoModeEnabled ? "Running (Device 4242)" : "Off")
                                .foregroundStyle(.secondary)
                        }
                    },
                    header: { Text("Development") },
                    footer: {
                        Text("When Demo Mode is enabled, the app generates a steady stream of fake telemetry (Device 4242) once per second. Records are saved to the same database as real telemetry so you can test UI and export features.")
                    }
                )

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Rocket Tracker")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    let bluetoothService = BluetoothService()
    let locationService = LocationService()
    let presenter = MainPresenter(bluetoothService: bluetoothService, locationService: locationService)
    return AppSettingsView().environmentObject(presenter)
}
