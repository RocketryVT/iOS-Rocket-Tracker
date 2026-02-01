import SwiftUI
import UIKit

struct SessionsView: View {
    @EnvironmentObject private var presenter: MainPresenter

    @State private var sessions: [Session] = []
    @State private var selectedDeviceFilter: UInt32?
    @State private var isLoading = false

    @State private var exportURL: URL?
    @State private var showingExporter = false

    var body: some View {
        NavigationStack {
            VStack {
                deviceFilterPicker
                    .padding(.horizontal)

                List {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session) {
                            exportSession(session)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.name ?? defaultSessionName(for: session))
                                        .font(.headline)
                                    Text(sessionDateRangeText(session))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let deviceID = session.deviceID {
                                    Text("Device \(deviceID)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading { ProgressView() }
                }
            }
            .onAppear(perform: loadSessions)
            .onChange(of: selectedDeviceFilter) { _, _ in
                loadSessions()
            }
            .sheet(isPresented: $showingExporter) {
                if let url = exportURL {
                    ExportDocumentPicker(fileURL: url)
                }
            }
        }
    }

    private var deviceFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button {
                    selectedDeviceFilter = nil
                } label: {
                    Text("All Devices")
                        .fontWeight(selectedDeviceFilter == nil ? .bold : .regular)
                        .padding(6)
                        .background(selectedDeviceFilter == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }

                ForEach(presenter.getAllDeviceIDs(), id: \.self) { deviceID in
                    Button {
                        selectedDeviceFilter = deviceID
                    } label: {
                        Text("Device \(deviceID)")
                            .fontWeight(selectedDeviceFilter == deviceID ? .bold : .regular)
                            .padding(6)
                            .background(selectedDeviceFilter == deviceID ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func loadSessions() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let fetched = presenter.getSessions(deviceID: selectedDeviceFilter)
            DispatchQueue.main.async {
                self.sessions = fetched
                self.isLoading = false
            }
        }
    }

    private func exportSession(_ session: Session) {
        guard let id = session.id else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let records = presenter.getTelemetryRecords(sessionID: id)
            do {
                let url = try CSVExporter.export(records: records, fileNamePrefix: "Session-\(id)")
                DispatchQueue.main.async {
                    self.exportURL = url
                    self.showingExporter = true
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func sessionDateRangeText(_ session: Session) -> String {
        let startText = formattedDate(session.startDate)
        let endText = session.endDate != nil ? formattedDate(session.endDate!) : "In Progress"
        return "\(startText) - \(endText)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func defaultSessionName(for session: Session) -> String {
        if let id = session.id { return "Session #\(id)" }
        return "Session"
    }
}

private struct SessionDetailView: View {
    let session: Session
    let exportAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(session.name ?? defaultSessionName())
                .font(.largeTitle)
                .bold()
            Text(sessionDateRangeText())
                .font(.title3)
                .foregroundColor(.secondary)
            if let deviceID = session.deviceID {
                Text("Device \(deviceID)")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            Spacer()
            Button(action: exportAction) {
                Label("Export to Files", systemImage: "folder")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionDateRangeText() -> String {
        let startText = formattedDate(session.startDate)
        let endText = session.endDate != nil ? formattedDate(session.endDate!) : "In Progress"
        return "\(startText) - \(endText)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func defaultSessionName() -> String {
        if let id = session.id { return "Session #\(id)" }
        return "Session"
    }
}

struct ExportDocumentPicker: UIViewControllerRepresentable {
    var fileURL: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL])
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

#Preview {
    let bluetoothService = BluetoothService()
    let locationService = LocationService()
    let presenter = MainPresenter(bluetoothService: bluetoothService, locationService: locationService)
    return SessionsView().environmentObject(presenter)
}
