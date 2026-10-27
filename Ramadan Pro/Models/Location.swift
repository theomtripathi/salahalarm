//
//  Location.swift
//  Ramadan Pro
//
//  Created by Bhuvesh Bansal on 15/01/26.
//

import Foundation
import CoreLocation

/// Represents a user's location for prayer time calculations
struct UserLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let city: String
    let country: String?
    let timeZone: String?
    
    init(id: UUID = UUID(),
         latitude: Double,
         longitude: Double,
         city: String,
         country: String? = nil,
         timeZone: String? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.country = country
        self.timeZone = timeZone
    }
    
    init(from clLocation: CLLocation, city: String, country: String? = nil) {
        self.id = UUID()
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
        self.city = city
        self.country = country
        self.timeZone = TimeZone.current.identifier
    }
    
    var clCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
