//
//  ViewController.swift
//  WeatherApp
//
//  Created by ZZJ on 2019/9/14.
//  Copyright © 2019 Peking University. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        location.updatedPlacemarkHandler = self.update
        location.enableLocationServices()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { timer in
            self.update(timer: timer)
        }
        update(timer: updateTimer!)
//        createScrollView()
    }
    
    @IBOutlet weak var cityName: UILabel!
    @IBOutlet weak var cityDistrictName: UILabel!
    
    @IBOutlet weak var currentTemperature: UILabel!
    @IBOutlet weak var minMaxTemperatureOfToday: UILabel!
    
    @IBOutlet weak var currentWeatherCondition: UILabel!
    @IBOutlet weak var currentAirQuality: UILabel!
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var lastUpdatedTime: UILabel!
    
    @IBOutlet weak var twentyFourHoursScrollView: UIScrollView!
    @IBOutlet weak var twentyFourHoursView: UIView!
    @IBOutlet weak var oneHourStack: UIStackView!
    
    var twentyFourHoursStack: [UIStackView]!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var updateTimer: Timer?
    
    var weather = Weather()
    var location = LocationManager()
    
    func update(placemark: CLPlacemark?) {
        activityIndicator.startAnimating()
        
        weather.updateInfomation(at: placemark) { weather in
            DispatchQueue.main.async {
                self.updateView(with: weather)
                
                self.activityIndicator.stopAnimating()
            }
        }
        
    }
    
    @objc func update(timer: Timer) {
        weather.updateInfomation() { weather in
            DispatchQueue.main.async {
                self.updateView(with: weather)
            }
        }
    }
    
    func updateView(with weather: Weather) {
        cityName.text = weather.cityName
        cityDistrictName.text = weather.districtName
        
        let curTemp = String(format: "%.0f", weather.currentTemperature ?? "unknown")
        currentTemperature.text = curTemp
        
        let minTemp = String(format: "%.0f℃", weather.minTemperatureOfToday ?? "unknown")
        let maxTemp = String(format: "%.0f℃", weather.maxTemperatureOfToday ?? "unknown")
        minMaxTemperatureOfToday.text = minTemp + " / " + maxTemp
        
        currentWeatherCondition.text = weather.currentWeatherCondition
        currentAirQuality.text = weather.currentAirQuality
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd HH:mm"
        let updatedTime = weather.lastUpdatedTime != nil ? dateFormatter.string(from: weather.lastUpdatedTime!) : "unknown"
        lastUpdatedTime.text =  "更新于: " + updatedTime
    }
    
    func createScrollView() {
        twentyFourHoursView.frame = CGRect(x: 0, y: 0, width: 24 * 50, height: 50)
        for i in 0...23 {
            let imageView = UIImageView(image: UIImage(named: "0"))
            imageView.frame = CGRect(x: i * 50, y: 0, width: 50, height: 50)
            twentyFourHoursView.addSubview(imageView)
            
//            let anotherOneHour = oneHourStack.copy() as! UIStackView
//            anotherOneHour.frame = CGRect(x: i * 50, y: 0, width: 50, height: 50)
//            twentyFourHoursView.addSubview(anotherOneHour)
//            twentyFourHoursStack.append(anotherOneHour)
        }
        
        twentyFourHoursScrollView.contentSize = twentyFourHoursView.bounds.size
    }
}

