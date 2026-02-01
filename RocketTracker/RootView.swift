import SwiftUI

struct RootView: View {
    @EnvironmentObject private var presenter: MainPresenter
    @State private var showDeviceSelector = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Rocket Tracker")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showDeviceSelector = true }) {
                            Label("Connect", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if presenter.isConnected {
                            Button(action: { presenter.disconnect() }) {
                                Label("Disconnect", systemImage: "xmark.circle")
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { presenter.toggleRecording() }) {
                            Label(presenter.isRecording ? "Stop" : "Record", systemImage: presenter.isRecording ? "record.circle.fill" : "record.circle")
                        }
                        .tint(presenter.isRecording ? .red : .primary)
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: AppSettingsView()) {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
        }
        .sheet(isPresented: $showDeviceSelector) {
            DeviceSelectorView(presenter: presenter, isPresented: $showDeviceSelector)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isRegularWidth {
            // iPad or large iPhone in landscape: side-by-side layout
            HStack(spacing: 0) {
                TrackView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                LogsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            // iPhone portrait: tabbed layout
            TabView {
                TrackView()
                    .tabItem { Label("Track", systemImage: "map") }
                LogsView()
                    .tabItem { Label("Logs", systemImage: "list.bullet.clipboard") }
                SessionsView()
                    .tabItem { Label("Sessions", systemImage: "folder") }
                AppSettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
    }

    private var isRegularWidth: Bool {
        #if os(iOS)
        return UIScreen.main.traitCollection.horizontalSizeClass == .regular
        #else
        return false
        #endif
    }
}

#Preview {
    let bluetoothService = BluetoothService()
    let locationService = LocationService()
    let presenter = MainPresenter(bluetoothService: bluetoothService, locationService: locationService)
    return RootView().environmentObject(presenter)
}
