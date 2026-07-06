//
//  LocationManager.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import CoreLocation
import Combine

/// Manages user location for prayer time calculations
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: UserLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var errorMessage: String?
    
    private var locationUpdateHandler: ((UserLocation?) -> Void)?
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestWhenInUseAuthorization() {
        requestPermission()
    }
    
    /// Start updating location
    func startUpdatingLocation(completion: @escaping (UserLocation?) -> Void) {
        locationUpdateHandler = completion
        
        switch authorizationStatus {
        case .notDetermined:
            requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable it in Settings."
            completion(nil)
        @unknown default:
            errorMessage = "Unknown location authorization status"
            completion(nil)
        }
    }
    
    /// Stop updating location
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Get city name from coordinates using reverse geocoding
    private func getCityName(from location: CLLocation, completion: @escaping (String?, String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                completion(nil, nil)
                return
            }
            
            if let placemark = placemarks?.first {
                let city = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown"
                let country = placemark.country
                completion(city, country)
            } else {
                completion("Unknown", nil)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        getCityName(from: location) { [weak self] city, country in
            guard let self = self, let city = city else { return }
            
            let userLocation = UserLocation(
                from: location,
                city: city,
                country: country
            )
            
            DispatchQueue.main.async {
                self.currentLocation = userLocation
                self.locationUpdateHandler?(userLocation)
                self.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Failed to get location: \(error.localizedDescription)"
        locationUpdateHandler?(nil)
    }
}
