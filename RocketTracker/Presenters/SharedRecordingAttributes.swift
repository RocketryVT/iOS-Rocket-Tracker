import Foundation
import ActivityKit

/// Attributes for the rocket recording Live Activity
/// This file should be included in BOTH the main app target and the widget extension target
struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// The ID of the rocket device being tracked
        let deviceID: UInt32?
        
        /// Number of seconds elapsed since recording started
        var elapsedSeconds: Int
        
        // You can add more fields here for richer Live Activity content:
        // var altitude: Double?
        // var velocity: Double?
        // var status: String?
    }
    
    /// The title displayed in the Live Activity
    var title: String = "Recording"
    
    // You can add more attributes here that don't change during the activity:
    // var launchSite: String?
    // var rocketName: String?
}
