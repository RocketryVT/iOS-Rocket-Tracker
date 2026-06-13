//
//  LocationService.swift
//  RocketTracker
//
//  Created by Gregory Wainer on 5/22/25.
//

import CoreLocation
import Combine

protocol LocationServiceProtocol {
    var userLocation: CLLocationCoordinate2D? { get }
    var userLocationPublisher: AnyPublisher<CLLocationCoordinate2D?, Never> { get }

    func setupLocationServices()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

class LocationService: NSObject, LocationServiceProtocol, ObservableObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager
    
    @Published var userLocation: CLLocationCoordinate2D?
    
    func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .otherNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    var userLocationPublisher: AnyPublisher<CLLocationCoordinate2D?, Never> {
        return $userLocation.eraseToAnyPublisher()
    }
    
    func startUpdatingLocation() {
//        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last?.coordinate {
            userLocation = location
        }
    }
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        setupLocationServices()
    }
    
}
