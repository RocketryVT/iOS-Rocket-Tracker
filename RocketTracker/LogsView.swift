import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var presenter: MainPresenter
    @State private var selectedDate: Date?
    @State private var recordsForDate: [TelemetryRecord] = []
    @State private var showingDataDetail = false
    @State private var logDates: [Date] = []
    @State private var isLoading = false
    @State private var showingDeleteAlert = false
    @State private var dateToDelete: Date?
    @State private var selectedDeviceFilter: UInt32?
    @State private var availableDevices: [UInt32] = []

    var body: some View {
        VStack {
            if availableDevices.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: {
                            selectedDeviceFilter = nil
                            refreshLogDates()
                        }) {
                            Text("All Devices")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((selectedDeviceFilter == nil) ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(16)
                                .foregroundColor((selectedDeviceFilter == nil) ? .white : .primary)
                        }
                        ForEach(availableDevices, id: \.self) { deviceID in
                            Button(action: {
                                selectedDeviceFilter = deviceID
                                refreshLogDates()
                            }) {
                                Text("Device \(deviceID)")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background((selectedDeviceFilter == deviceID) ? Color.blue : Color.gray.opacity(0.2))
                                    .cornerRadius(16)
                                    .foregroundColor((selectedDeviceFilter == deviceID) ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            ZStack {
                List {
                    if logDates.isEmpty {
                        Text("No telemetry data recorded").foregroundColor(.gray)
                    } else {
                        ForEach(logDates, id: \.self) { date in
                            Button(action: { loadRecordsForDate(date) }) {
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(dateFormatter.string(from: date))
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    dateToDelete = date
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                if isLoading {
                    ProgressView("Loading records...")
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                }
            }
        }
        .onAppear {
            loadAvailableDevices()
            refreshLogDates()
        }
        .alert("Delete Records", isPresented: $showingDeleteAlert, presenting: dateToDelete) { date in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete(for: date) }
        } message: { date in
            let deviceText = selectedDeviceFilter != nil ? " for Device \(selectedDeviceFilter!)" : ""
            Text("Are you sure you want to delete all telemetry records\(deviceText) for \(dateFormatter.string(from: date))?")
        }
        .sheet(isPresented: $showingDataDetail) {
            if let date = selectedDate {
                TelemetryLogDetailView(date: date, records: recordsForDate, deviceFilter: selectedDeviceFilter)
            }
        }
    }

    private func loadAvailableDevices() {
        DispatchQueue.global(qos: .userInitiated).async {
            let devices = presenter.getAllDeviceIDs()
            DispatchQueue.main.async { self.availableDevices = devices }
        }
    }

    private func performDelete(for date: Date) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            presenter.deleteRecordsForDate(date, deviceID: selectedDeviceFilter)
            DispatchQueue.main.async { refreshLogDates() }
        }
    }

    private func loadRecordsForDate(_ date: Date) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let records = presenter.getTelemetryRecords(deviceID: selectedDeviceFilter, from: startOfDay, to: endOfDay)
            DispatchQueue.main.async {
                recordsForDate = records
                selectedDate = date
                isLoading = false
                showingDataDetail = true
            }
        }
    }

    private func refreshLogDates() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let dates = presenter.getAvailableDates(forDeviceID: selectedDeviceFilter)
            DispatchQueue.main.async {
                logDates = dates
                isLoading = false
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }
}

#Preview {
    let bluetoothService = BluetoothService()
    let locationService = LocationService()
    let presenter = MainPresenter(bluetoothService: bluetoothService, locationService: locationService)
    return LogsView().environmentObject(presenter)
}
