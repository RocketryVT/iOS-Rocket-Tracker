import Foundation
import Combine
import CoreBluetooth
import MapKit
import UIKit

class MainPresenter: NSObject, ObservableObject {
    // Published properties for the view
    @Published var isConnected = false
    @Published var telemetryDataByDevice: [UInt32: TelemetryData] = [:]
    @Published var receivedMessages: [ReceivedMessage] = []
    @Published var isSending = false
    @Published var pathCoordinatesByDevice: [UInt32: [CLLocationCoordinate2D]] = [:]
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.0, longitude: -80.0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var selectedDeviceID: UInt32? = nil // Track which device is selected
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var headingToRocket: Double?
    @Published var deviceHeading: Double = 0
    @Published var relativeHeadingToRocket: Double?
    @Published var selectedDate: Date? = nil
    @Published var isRecording: Bool = false

    @Published var isDemoModeEnabled: Bool = UserDefaults.standard.bool(forKey: "DemoModeEnabled")

    var telemetryData: TelemetryData? {
        if let selected = selectedDeviceID {
            return telemetryDataByDevice[selected]
        }
        return telemetryDataByDevice.values.first
    }

    var pathCoordinates: [CLLocationCoordinate2D] {
        if let selected = selectedDeviceID {
            return pathCoordinatesByDevice[selected] ?? []
        }
        return pathCoordinatesByDevice.values.first ?? []
    }
    
    // Services
    private let bluetoothService: BluetoothServiceProtocol
    private let locationService: LocationServiceProtocol
    private let dataStore: TelemetryStore
    private var cancellables = Set<AnyCancellable>()
    
    private var demoTimer: Timer?
    private var demoMsgNum: Int = 0
    private var demoStartDate: Date?
    private var demoBaseCoordinate: CLLocationCoordinate2D?
    private var recordingStartDate: Date?
    private var currentSessionID: Int64?

    init(bluetoothService: BluetoothServiceProtocol, locationService: LocationServiceProtocol, dataStore: TelemetryStore = TelemetryDataManager()) {
        self.bluetoothService = bluetoothService
        self.locationService = locationService
        self.dataStore = dataStore

        super.init()
        
        dataStore.verifyDataStore()

        setupBindings()

        // Observe demo mode changes
        $isDemoModeEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                UserDefaults.standard.set(enabled, forKey: "DemoModeEnabled")
                if enabled { self.startDemoMode() } else { self.stopDemoMode() }
            }
            .store(in: &cancellables)

        // Start demo mode if persisted as enabled
        if isDemoModeEnabled {
            startDemoMode()
        }
    }
    
    // Get telemetry records for specific device
    func getAllTelemetryRecords() -> [TelemetryRecord] {
        return dataStore.getTelemetryRecords(deviceID: nil, from: nil, to: nil)
    }
    
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        return locationService.userLocation
    }
    
    // Get available dates for specific device
    func getAvailableDates(forDeviceID deviceID: UInt32? = nil) -> [Date] {
        return dataStore.getAvailableDates(forDeviceID: deviceID)
    }
    
    // Delete records for specific device and date
    func deleteRecordsForDate(_ date: Date, deviceID: UInt32? = nil) {
        dataStore.deleteRecordsForDate(date, deviceID: deviceID)
    }
    
    private func setupBindings() {
        // Subscribe to service publishers
        bluetoothService.connectionStatusPublisher
            .assign(to: &$isConnected)
        
        bluetoothService.telemetryPublisher
            .sink { [weak self] telemetry in
                guard let self = self, let data = telemetry else { return }
                // Use unified ingest path for both Bluetooth and demo
                self.ingestTelemetry(data)
            }
            .store(in: &cancellables)
        
        bluetoothService.messagesPublisher
            .assign(to: &$receivedMessages)

        locationService.userLocationPublisher
            .sink { [weak self] location in
                guard let self = self else { return }
                
                // Update our published property
                self.userLocation = location

//                print("User location updated: \(String(describing: location))")
                
                // If we're connected to a device, send the location
                if self.bluetoothService.isConnected, let location = location {
//                    print("Sending location update: \(location.latitude), \(location.longitude)")
                    self.bluetoothService.sendUserLocation(location)
                }
            }
            .store(in: &cancellables)
    }

    func ingestTelemetry(_ data: TelemetryData) {
        // Store data for this device
        self.telemetryDataByDevice[data.deviceID] = data

        // Log the telemetry data
        if self.isRecording { self.dataStore.logTelemetry(data, sessionID: currentSessionID) }

        // If this is a new device, select it
        if self.selectedDeviceID == nil {
            self.selectedDeviceID = data.deviceID
        }

        // Update path coordinates for this device
        let coordinate = CLLocationCoordinate2D(
            latitude: data.gps.lat,
            longitude: data.gps.lon
        )

        if self.pathCoordinatesByDevice[data.deviceID] == nil {
            self.pathCoordinatesByDevice[data.deviceID] = []
        }

        // Add the coordinate to the path
        self.pathCoordinatesByDevice[data.deviceID]?.append(coordinate)

        // Limit path length to prevent memory issues
        if let pathCount = self.pathCoordinatesByDevice[data.deviceID]?.count,
           pathCount > 1000 {
            self.pathCoordinatesByDevice[data.deviceID]?.removeFirst()
        }

        // Center map on selected device
        if let selectedID = self.selectedDeviceID,
           let selectedTelemetry = self.telemetryDataByDevice[selectedID] {
            self.mapRegion.center = CLLocationCoordinate2D(
                latitude: selectedTelemetry.gps.lat,
                longitude: selectedTelemetry.gps.lon
            )
        }
    }

    // Select a specific device to focus on
    func selectDevice(_ deviceID: UInt32?) {
        self.selectedDeviceID = deviceID
        
        // Update map region if we have data for this device
        if let deviceID = deviceID, 
        let telemetry = telemetryDataByDevice[deviceID] {
            mapRegion.center = CLLocationCoordinate2D(
                latitude: telemetry.gps.lat,
                longitude: telemetry.gps.lon
            )
        }
    }

    // Get all device IDs with telemetry data
    func getAvailableDeviceIDs() -> [UInt32] {
        // Combine current devices and historical devices
        var deviceIDs = Array(telemetryDataByDevice.keys)
        
        // Add historical devices from database
        let historicalDeviceIDs = dataStore.getAllDeviceIDs()
        for deviceID in historicalDeviceIDs {
            if !deviceIDs.contains(deviceID) {
                deviceIDs.append(deviceID)
            }
        }
        
        return deviceIDs.sorted()
    }

    func getAllDeviceIDs() -> [UInt32] {
        return dataStore.getAllDeviceIDs()
    }

    // Access methods for telemetry by device
    func getTelemetryRecords(deviceID: UInt32? = nil, from startDate: Date? = nil, to endDate: Date? = nil) -> [TelemetryRecord] {
        return dataStore.getTelemetryRecords(deviceID: deviceID, from: startDate, to: endDate)
    }

    func getPathCoordinates(for deviceID: UInt32) -> [CLLocationCoordinate2D] {
        return pathCoordinatesByDevice[deviceID] ?? []
    }
    
    // Sessions API for UI
    func getSessions(deviceID: UInt32? = nil) -> [Session] {
        if let store = dataStore as? TelemetryDataManager {
            return store.getSessions(deviceID: deviceID)
        }
        return []
    }

    func getTelemetryRecords(sessionID: Int64) -> [TelemetryRecord] {
        if let store = dataStore as? TelemetryDataManager {
            return store.getTelemetryRecords(sessionID: sessionID)
        }
        return []
    }
    
    // Public methods for the view
    func startScanning() {
        bluetoothService.startScanning()
    }
    
    func stopScanning() {
        bluetoothService.stopScanning()
    }
    
    func connect(to peripheral: CBPeripheral) {
        bluetoothService.connect(to: peripheral)
    }
    
    func disconnect() {
        bluetoothService.disconnect()
        // Force any pending saves
        self.dataStore.forceSave()
    }
    
    func getDiscoveredDevices() -> [(peripheral: CBPeripheral, rssi: NSNumber)] {
        // This could come from a published property as well
        return (bluetoothService as? BluetoothService)?.discoveredDevices ?? []
    }

    func getTelemetryData() -> TelemetryData? {
        return self.telemetryData
    }
    
    func getTelemetryData(for deviceID: UInt32) -> TelemetryData? {
        return self.telemetryDataByDevice[deviceID]
    }

    func getRecordsForSelectedDate() -> [TelemetryRecord] {
        guard let selectedDate = selectedDate else {
            return []
        }
        
        let deviceID = selectedDeviceID
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return dataStore.getTelemetryRecords(deviceID: deviceID, 
                                            from: startOfDay, 
                                            to: endOfDay)
    }

    func getAvailableDates() -> [Date] {
        let dates = dataStore.getAvailableDates(forDeviceID: nil)
        print("Retrieved \(dates.count) available dates")
        return dates
    }

    func deleteOldRecords(olderThan date: Date) {
        dataStore.deleteRecords(olderThan: date)
    }

    func deleteRecordsForDate(_ date: Date) {
        print("MainPresenter: Deleting records for \(date)")
        dataStore.deleteRecordsForDate(date, deviceID: nil)
    }

    // MARK: - Recording Control
    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordingStartDate = Date()
        // Start a new session in the data store
        let sessionName = DateFormatter.localizedString(from: recordingStartDate ?? Date(), dateStyle: .medium, timeStyle: .short)
        currentSessionID = dataStore.startNewSession(name: "Session \(sessionName)", deviceID: selectedDeviceID)
        LiveActivityManager.startRecording(startDate: recordingStartDate ?? Date(), deviceID: selectedDeviceID)
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if let sessionID = currentSessionID {
            dataStore.endSession(sessionID)
        }
        currentSessionID = nil
        LiveActivityManager.endRecording()
    }

    func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    // MARK: - Demo Mode
    private func startDemoMode() {
        stopDemoMode()
        demoMsgNum = 0
        demoStartDate = Date()
        // Use current location if available, otherwise default to Blacksburg, VA
        let base = locationService.userLocation ?? CLLocationCoordinate2D(latitude: 37.2296, longitude: -80.4139)
        demoBaseCoordinate = base
        // Generate at 1 Hz
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.generateDemoTelemetryTick()
        }
        RunLoop.main.add(demoTimer!, forMode: .common)
    }

    private func stopDemoMode() {
        demoTimer?.invalidate()
        demoTimer = nil
    }

    private func generateDemoTelemetryTick() {
        guard let start = demoStartDate, let base = demoBaseCoordinate else { return }
        demoMsgNum += 1
        let elapsed = Date().timeIntervalSince(start)
        let deviceID: UInt32 = 4242

        // Simulate a small circular path (~10-20 meters radius)
        let radiusMeters: Double = 15
        let earthRadiusMeters: Double = 6_371_000
        let angle = elapsed / 10.0 // radians per 10s
        let dLat = (radiusMeters / earthRadiusMeters) * sin(angle)
        let dLon = (radiusMeters / (earthRadiusMeters * cos(base.latitude * .pi / 180))) * cos(angle)
        let lat = base.latitude + dLat * 180 / .pi
        let lon = base.longitude + dLon * 180 / .pi

        // Altitude oscillates a bit
        let alt = 600 + 5 * sin(elapsed / 5.0)

        // Random small sensor noise
        func noise(_ scale: Double) -> Double { Double.random(in: -scale...scale) }

        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: now)

        let utc = UTCTime(
            itow: Int((elapsed * 1000).rounded()),
            time_accuracy_estimate_ns: Int.random(in: 20_000...80_000),
            year: comps.year ?? 2025,
            month: comps.month ?? 1,
            day: comps.day ?? 1,
            hour: comps.hour ?? 0,
            min: comps.minute ?? 0,
            sec: comps.second ?? 0,
            nanos: comps.nanosecond ?? 0,
            valid: 1
        )

        let telemetry = TelemetryData(
            deviceID: deviceID,
            time_since_boot: Int(elapsed * 1000),
            msg_num: demoMsgNum,
            gps: GPSData(
                alt: alt,
                fix: "3D Fix",
                lat: lat,
                lon: lon,
                num_sats: Int.random(in: 8...18),
                time: utc
            ),
            ism_primary: AccelGyroData(
                accelerometer: AccelerometerData(x: noise(0.02), y: noise(0.02), z: 1.0 + noise(0.02)),
                gyroscope: GyroscopeData(x: noise(0.5), y: noise(0.5), z: noise(0.5))
            ),
            ism_secondary: AccelGyroData(
                accelerometer: AccelerometerData(x: noise(0.02), y: noise(0.02), z: 1.0 + noise(0.02)),
                gyroscope: GyroscopeData(x: noise(0.5), y: noise(0.5), z: noise(0.5))
            ),
            lsm: AccelGyroData(
                accelerometer: AccelerometerData(x: noise(0.02), y: noise(0.02), z: 1.0 + noise(0.02)),
                gyroscope: GyroscopeData(x: noise(0.5), y: noise(0.5), z: noise(0.5))
            ),
            adxl: AccelerometerData(x: noise(0.05), y: noise(0.05), z: 1.0 + noise(0.05)),
            barometer: BarometerData(altitude: alt + noise(0.5))
        )

        // Ingest on main thread to keep UI consistent
        DispatchQueue.main.async { [weak self] in
            self?.ingestTelemetry(telemetry)
        }
    }
}

extension Double {
    func toRadians() -> Double {
        return self * .pi / 180
    }
    
    func toDegrees() -> Double {
        return self * 180 / .pi
    }
}

