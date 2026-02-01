import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Manager
// Note: RecordingAttributes is defined in SharedRecordingAttributes.swift
// and must be included in BOTH the main app and widget extension targets

enum LiveActivityManager {
    private static var currentActivity: Activity<RecordingAttributes>?
    private static var timerTask: Task<Void, Never>?
    
    static func startRecording(startDate: Date, deviceID: UInt32?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled.")
            return
        }
        
        // Cancel any previous task and end previous activity
        timerTask?.cancel()
        Task {
            if let activity = currentActivity {
                let finalState = RecordingAttributes.ContentState(deviceID: nil, elapsedSeconds: 0)
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
                print("Previous live activity ended.")
                currentActivity = nil
            }
        }
        
        let initialState = RecordingAttributes.ContentState(deviceID: deviceID, elapsedSeconds: 0)
        let attributes = RecordingAttributes()
        
        Task {
            do {
                let activity: Activity<RecordingAttributes>
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    activity = try Activity<RecordingAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                } else {
                    activity = try Activity<RecordingAttributes>.request(
                        attributes: attributes,
                        contentState: initialState,
                        pushType: nil
                    )
                }
                currentActivity = activity
                print("Live activity started with id: \(activity.id)")
                
                timerTask = Task {
                    var elapsed = 0
                    while !Task.isCancelled {
                        do {
                            try await Task.sleep(nanoseconds: 15 * 1_000_000_000)
                        } catch {
                            // Likely cancelled; exit the loop
                            break
                        }
                        elapsed += 15
                        await updateElapsed(seconds: elapsed, deviceID: deviceID)
                    }
                }
            } catch {
                print("Error requesting live activity: \(error)")
            }
        }
    }
    
    @MainActor
    static func updateElapsed(seconds: Int, deviceID: UInt32?) async {
        guard let activity = currentActivity else {
            print("No live activity to update.")
            return
        }
        
        let updatedState = RecordingAttributes.ContentState(deviceID: deviceID, elapsedSeconds: seconds)
        
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: updatedState, staleDate: nil)
            await activity.update(content)
        } else {
            await activity.update(using: updatedState)
        }
        print("Live activity updated: elapsedSeconds = \(seconds)")
    }
    
    static func endRecording() {
        timerTask?.cancel()
        timerTask = nil
        
        Task {
            if let activity = currentActivity {
                let finalState = RecordingAttributes.ContentState(deviceID: nil, elapsedSeconds: 0)
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
                print("Live activity ended.")
                currentActivity = nil
            } else {
                print("No live activity to end.")
            }
        }
    }
}


