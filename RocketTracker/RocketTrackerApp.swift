//
//  RocketTrackerApp.swift
//  RocketryAtVT
//
//  Created by Gregory Wainer on 2/4/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct RocketTrackerApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    // Centralized dependencies
    @StateObject private var presenter: MainPresenter

    init() {
        let bluetoothService = BluetoothService()
        let locationService = LocationService()
        _presenter = StateObject(wrappedValue: MainPresenter(bluetoothService: bluetoothService, locationService: locationService))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(presenter)
        }
    }
}

#if canImport(UIKit)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
#endif // canImport(UIKit)
