import SwiftUI
import MapKit

struct TrackView: View {
    @EnvironmentObject private var presenter: MainPresenter

    var body: some View {
        VStack(spacing: 0) {
            connectionHeader
            mapSection
            TelemetryDataView(presenter: presenter)
        }
    }

    private var connectionHeader: some View {
        HStack {
            Image(systemName: presenter.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(presenter.isConnected ? .green : .red)
            Text(presenter.isConnected ? "Connected to RocketryAtVT Tracker" : "Not Connected")
                .font(.headline)
            if presenter.isConnected, presenter.isSending {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.trailing)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.0))
    }

    private var mapSection: some View {
        GeometryReader { geometry in
            Group {
                if let telemetry = presenter.telemetryData {
                    MapView(for: nil, for: telemetry, presenter: presenter)
                        .frame(height: min(300, geometry.size.height * 0.5))
                        .padding(8)
                } else if let userLocation = presenter.userLocation {
                    MapView(for: userLocation, for: nil, presenter: presenter)
                        .frame(height: min(300, geometry.size.height * 0.5))
                        .padding(8)
                } else {
                    MapView(for: nil, for: nil, presenter: presenter)
                        .frame(height: min(300, geometry.size.height * 0.5))
                        .padding(8)
                }
            }
        }
        .frame(minHeight: 200)
    }
}

#Preview {
    let bluetoothService = BluetoothService()
    let locationService = LocationService()
    let presenter = MainPresenter(bluetoothService: bluetoothService, locationService: locationService)
    return TrackView().environmentObject(presenter)
}
