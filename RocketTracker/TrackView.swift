import SwiftUI
import MapKit

struct TrackView: View {
    @EnvironmentObject private var presenter: MainPresenter

    var body: some View {
        GeometryReader { geometry in
            let mapHeight = min(max(geometry.size.height * 0.55, 320), geometry.size.height * 0.68)

            VStack(spacing: 0) {
                connectionHeader
                ZStack(alignment: .bottomTrailing) {
                    mapContent
                    openInMapsButton
                        .padding(16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: mapHeight)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                TelemetryDataView(presenter: presenter)
            }
        }
        .onAppear {
            presenter.startLocationUpdates()
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

    private var mapContent: some View {
        Group {
            if let telemetry = presenter.telemetryData {
                MapView(for: nil, for: telemetry, presenter: presenter)
            } else if let userLocation = presenter.userLocation {
                MapView(for: userLocation, for: nil, presenter: presenter)
            } else {
                MapView(for: nil, for: nil, presenter: presenter)
            }
        }
    }

    private var openInMapsButton: some View {
        Button(action: openLatestCoordinateInMaps) {
            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(latestRocketCoordinate == nil)
        .opacity(latestRocketCoordinate == nil ? 0.55 : 1)
    }

    private var latestRocketCoordinate: CLLocationCoordinate2D? {
        guard let telemetry = presenter.telemetryData else { return nil }

        let coordinate = CLLocationCoordinate2D(
            latitude: telemetry.gps.lat,
            longitude: telemetry.gps.lon
        )
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private func openLatestCoordinateInMaps() {
        guard let coordinate = latestRocketCoordinate else { return }

        let placemark = MKPlacemark(coordinate: coordinate)
        let destination = MKMapItem(placemark: placemark)
        destination.name = "Rocket"
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    let bluetoothService = BluetoothService()
    let locationService = LocationService()
    let presenter = MainPresenter(bluetoothService: bluetoothService, locationService: locationService)
    return TrackView().environmentObject(presenter)
}
