//
//  TrackerWidgetLiveActivity.swift
//  TrackerWidget
//
//  Created by Gregory Wainer on 1/20/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct TrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            // Lock Screen/banner UI
            RecordingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Text("Recording")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if let deviceID = context.state.deviceID {
                        Text("ID: \(deviceID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        Image(systemName: "rocket.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                        
                        Text(formatElapsedTime(context.state.elapsedSeconds))
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                        Text("Tracking rocket telemetry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading (left side of Dynamic Island)
                HStack(spacing: 3) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 8))
                    Image(systemName: "rocket.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } compactTrailing: {
                // Compact trailing (right side of Dynamic Island)
                Text(formatCompactTime(context.state.elapsedSeconds))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } minimal: {
                // Minimal presentation (when multiple Live Activities are running)
                Image(systemName: "rocket.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    // Format elapsed time as MM:SS
    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // Format compact time for Dynamic Island
    private func formatCompactTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", remainingSeconds)
        }
    }
}

// MARK: - Lock Screen View
struct RecordingLockScreenView: View {
    let context: ActivityViewContext<RecordingAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Recording indicator
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text(context.attributes.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Device ID
                if let deviceID = context.state.deviceID {
                    Text("Device \(deviceID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.quaternary)
                        }
                }
            }
            
            // Elapsed time display
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Image(systemName: "rocket.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Elapsed Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatElapsedTime(context.state.elapsedSeconds))
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                
                Spacer()
                
                // Visual indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Text("Tracking")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.3))
        .activitySystemActionForegroundColor(.white)
    }
    
    private func formatElapsedTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%02d:%02d", minutes, remainingSeconds)
        }
    }
}

// MARK: - Preview
#Preview("Notification", as: .content, using: RecordingAttributes()) {
    TrackerWidgetLiveActivity()
} contentStates: {
    RecordingAttributes.ContentState(deviceID: 12345, elapsedSeconds: 0)
    RecordingAttributes.ContentState(deviceID: 12345, elapsedSeconds: 45)
    RecordingAttributes.ContentState(deviceID: 12345, elapsedSeconds: 125)
    RecordingAttributes.ContentState(deviceID: 12345, elapsedSeconds: 3665)
}
