import SwiftUI

/// Example usage of the LiveActivityManager in your app's UI
struct LiveActivityUsageExample: View {
    @State private var isRecording = false
    @State private var deviceID: UInt32 = 12345
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rocket Tracker")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Recording status
            HStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(isRecording ? "Recording" : "Not Recording")
                    .font(.headline)
            }
            
            // Device ID input
            if !isRecording {
                HStack {
                    Text("Device ID:")
                    TextField("Enter Device ID", value: $deviceID, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                .padding(.horizontal)
            }
            
            // Main action button
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Label(
                    isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: isRecording ? "stop.circle.fill" : "record.circle"
                )
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRecording ? Color.red : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            // Information
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Activity Features:")
                    .font(.headline)
                
                Label("Lock Screen display", systemImage: "lock.fill")
                Label("Dynamic Island (iPhone 14 Pro+)", systemImage: "circle.circle")
                Label("Real-time elapsed time updates", systemImage: "clock.fill")
                Label("Device ID tracking", systemImage: "number.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func startRecording() {
        isRecording = true
        
        // Start the Live Activity
        LiveActivityManager.startRecording(
            startDate: Date(),
            deviceID: deviceID
        )
        
        // Your actual recording logic here
        print("Started recording from device \(deviceID)")
    }
    
    private func stopRecording() {
        isRecording = false
        
        // End the Live Activity
        LiveActivityManager.endRecording()
        
        // Your actual stop recording logic here
        print("Stopped recording")
    }
}

// MARK: - Alternative: Using in a ViewModel

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var deviceID: UInt32 = 0
    @Published var elapsedTime: TimeInterval = 0
    
    private var recordingStartDate: Date?
    
    func startRecording(deviceID: UInt32) {
        self.deviceID = deviceID
        self.isRecording = true
        self.recordingStartDate = Date()
        
        // Start Live Activity
        LiveActivityManager.startRecording(
            startDate: Date(),
            deviceID: deviceID
        )
        
        // Your recording logic
        print("Recording started")
    }
    
    func stopRecording() {
        self.isRecording = false
        self.recordingStartDate = nil
        
        // End Live Activity
        LiveActivityManager.endRecording()
        
        // Your stop logic
        print("Recording stopped")
    }
    
    func updateRecordingData() {
        guard isRecording else { return }
        
        // Calculate elapsed time
        if let startDate = recordingStartDate {
            elapsedTime = Date().timeIntervalSince(startDate)
        }
        
        // The LiveActivityManager updates automatically every 15 seconds
        // But you can also trigger manual updates if you have new data:
        // Task {
        //     await LiveActivityManager.updateElapsed(
        //         seconds: Int(elapsedTime),
        //         deviceID: deviceID
        //     )
        // }
    }
}

// MARK: - Integration with existing MainPresenter

extension MainPresenter {
    /// Call this when starting a recording session
    func beginRecordingWithLiveActivity(deviceID: UInt32) {
        // Start your existing recording logic
        // ...
        
        // Start Live Activity
        LiveActivityManager.startRecording(
            startDate: Date(),
            deviceID: deviceID
        )
    }
    
    /// Call this when stopping a recording session
    func endRecordingWithLiveActivity() {
        // Stop your existing recording logic
        // ...
        
        // End Live Activity
        LiveActivityManager.endRecording()
    }
}

#Preview {
    LiveActivityUsageExample()
}
