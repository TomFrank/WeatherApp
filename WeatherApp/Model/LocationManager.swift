//
//  Location.swift
//  WeatherApp
//
//  Created by ZZJ on 2019/9/16.
//  Copyright © 2019 Peking University. All rights reserved.
//

// reference to https://zhuanlan.zhihu.com/p/54078744

import Foundation
import Contacts
import Intents
import CoreLocation


class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private static let geoCoder = CLGeocoder()
    
    var updatedPlacemarkHandler: ((CLPlacemark?) -> ())?
    
    func enableLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = kCLLocationAccuracyThreeKilometers
        if !CLLocationManager.locationServicesEnabled() {
            print("location services not enabled")
            return
        }
        if !CLLocationManager.significantLocationChangeMonitoringAvailable() {
            print("significant Location Change services not available")
            return
        }
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
//            locationManager.startMonitoringVisits()
//            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
        }
    }
    
//    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
//        print("Visits: \(visit)")
//        let location = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
//
//        Location.geoCoder.reverseGeocodeLocation(location) { placemarks, _ in
//            if let place = placemarks?.first {
//                self.updatedPlacemark = place
//                print("placemark is not nil in locationManager")
//            } else {
//                self.updatedPlacemark = nil
//                print("placemark is nil in locationManager")
//            }
//        }
//    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last!
        print("location: \(lastLocation.coordinate)")
        
        LocationManager.geoCoder.reverseGeocodeLocation(lastLocation) { placemarks, _ in
            if let place = placemarks?.first {
                print("success : got placemark from location")
                self.updatedPlacemarkHandler?(place)
                
            } else {
                print("fail: got placemark from location")
                self.updatedPlacemarkHandler?(nil)
                
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            // Location updates are not authorized.
            print("\(error)")
            manager.stopMonitoringSignificantLocationChanges()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            // Request when-in-use authorization initially
            manager.requestAlwaysAuthorization()
        case .restricted, .denied:
            // Disable location features
//            manager.stopMonitoringVisits()
//            manager.stopMonitoringSignificantLocationChanges()
            manager.stopUpdatingLocation()
            print("Restricted or Denied Authorization")
        case .authorizedWhenInUse:
            // Enable basic location features
            print("When-In-Use Authorization success")
        case .authorizedAlways:
            // Enable any of your app's location features
//            manager.startMonitoringVisits()
//            manager.startMonitoringSignificantLocationChanges()
            manager.startUpdatingLocation()
            print("Always Authorization success")
        default:
            break
        }
    }
    
}

