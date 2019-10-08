//
//  Weather.swift
//  WeatherApp
//
//  Created by ZZJ on 2019/9/14.
//  Copyright © 2019 Peking University. All rights reserved.
//

import Foundation
import CoreLocation
import Dispatch

class Weather {
    var countryName: String
    var provinceName: String
    var cityName: String
    var districtName: String
    var isMunicipality: Bool
    
    var currentTemperature: Float?
    var minTemperatureOfToday: Float?
    var maxTemperatureOfToday: Float?
    var currentWeatherCondition: String?
    var lastUpdatedTime: Date?
    var currentAirQualityIndex: Int?
    var currentAirQuality: String?
    
    var basicGeoInfo: GeographicInfomation?
    var province: Province?
    var city: City?
    
    let provinceURL = "http://www.nmc.cn/f/rest/province/"
    let realWeatherBaseURL = "http://www.nmc.cn/f/rest/real/"
    let detailedWeatherBaseURL = "http://www.nmc.cn/f/rest/weather/"
    
    let provinceDataURL = FileManager.documentDirectory.appendingPathComponent("provinceData")
    let citieDataURL = FileManager.documentDirectory.appendingPathComponent("cityData")
    
    private let session = URLSession.shared
    
    init() {
        countryName = "中国"
        provinceName = "北京"
        cityName = "北京市"
        districtName = "大兴区"
        isMunicipality = false
        
        city = City(province: "北京市", city: "大兴", code: "54594", url: "", id: "")
        province = Province(code: "ABJ", name: "北京市", url: "")
        
        // loadOrDownloadBasicInfomation()
    }
    
    func updateInfomation(on complete: @escaping (Weather) -> Void) {
        fetchRealWeatherData(on: complete)
        fetchDetailedlWeatherData(on: complete)
        // TODO: fetch more
    }
    
    func updateInfomation(at placemark: CLPlacemark?, complete: @escaping (Weather) -> Void) {
        guard placemark != nil else {
            fetchRealWeatherData(on: complete)
            return
        }
        
        countryName = placemark!.country ?? "unknown"
        provinceName = placemark!.administrativeArea ?? "unknown"
        cityName = placemark!.locality ?? "unknown"
        districtName = placemark!.subLocality ?? "unknown"
        if placemark!.administrativeArea == nil {
            isMunicipality = true
        }
        print("\(provinceName) \(cityName) \(districtName)")
        
        province = basicGeoInfo?.provinceList.first(where: {$0.name == (isMunicipality ? cityName : provinceName)})
        guard province != nil else {
            print("fail: can't find \(isMunicipality ? cityName : provinceName)")
            return
        }
        
        city = basicGeoInfo?.citiesOfProvince[province!]?.first(where: {$0.city == (isMunicipality ? String(districtName.dropLast(1)) : cityName)})
        guard city != nil else {
            print("fail: can't find \(isMunicipality ? districtName : cityName)")
            return
        }
        
        if let cityCode = city?.code {
            print("success: city code is \(cityCode)")
        } else {
            print("fail: get city code")
        }
        self.updateInfomation(on: complete)
    }
    
    func fetchRealWeatherData(on complete: @escaping (Weather) -> Void) {
        guard let realDataBaseURL = URL(string: realWeatherBaseURL) else {
            return
        }
        
        guard let cityCode = self.city?.code else {
            return
        }
        
        let cityRealDataURL = realDataBaseURL.appendingPathComponent(cityCode)
        
        session.dataTask(with: cityRealDataURL) {
            switch $0 {
            case .success(let data, _):
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let realData = try! decoder.decode(RealData.self, from: data)
                
                self.currentTemperature = realData.weather.temperature
                self.lastUpdatedTime = realData.publishTime
                self.currentWeatherCondition = realData.weather.info
                
                // TODO: wind
                complete(self)
            case .failure:
                print("fail: get real data")
            }
        }.resume()
    }
    
    func fetchDetailedlWeatherData(on complete: @escaping (Weather) -> Void) {
        guard let detailedDataBaseURL = URL(string: detailedWeatherBaseURL) else {
            return
        }
        
        guard let cityCode = self.city?.code else {
            return
        }
        
        let cityDetailedDataURL = detailedDataBaseURL.appendingPathComponent(cityCode)
        
        session.dataTask(with: cityDetailedDataURL) {
            switch $0 {
            case .success(let data, _):
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // dateFormatterWithoutTime
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                    // dateFormatterWithTime
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                let detailedData = try! decoder.decode([WeatherDetail].self, from: data).first!
                
                let dayTemperature = detailedData.detail.first!.day.weather.temperature
                let nightTemperature = detailedData.detail.first!.night.weather.temperature
                self.minTemperatureOfToday = Float(nightTemperature)
                self.maxTemperatureOfToday = Float(dayTemperature)
//                print("\(dayTemperature)℃ / \(nightTemperature)℃")
                complete(self)
            case .failure:
                print("fail: get detailed data")
            }
        }.resume()
        
    }
    
    func loadOrDownloadBasicInfomation() {
        if let data = fetchBasicGeoDataFromDisk() {
            basicGeoInfo = data
            print("success: fetch from disk")
        } else if case .success(let data) = fetchBasicGeoDataFromServer() {
            basicGeoInfo = data
            saveBasicGeoDataToDisk()
            print("success: fetch from server")
        } else {
            basicGeoInfo = nil
            print("fail: fetch basic info")
        }
        
    }
    
    func fetchBasicGeoDataFromDisk() -> GeographicInfomation? {
        guard let provinceData = try? Data(contentsOf: provinceDataURL),
            let citiesData = try? Data(contentsOf: citieDataURL) else {
                print("failed: read file from disk")
                return nil
        }
        let provinceList = try! JSONDecoder().decode([Province].self, from: provinceData)
        let citiesOfProvince = try! JSONDecoder().decode([Province:[City]].self, from: citiesData)
        
        return GeographicInfomation(provinceList: provinceList, citiesOfProvince: citiesOfProvince)
//        let bjs = Province(code: "ABJ", name: "北京市", url: "")
//        let daxing = City(province: "北京市", city: "大兴", code: "54594", url: "", id: "")
//        let haidian = City(province: "北京市", city: "海淀", code: "54399", url: "", id: "")
//        return GeographicInfomation(
//            provinceList: [bjs],
//            citiesOfProvince: [bjs: [daxing, haidian]])
    }
    
    func saveBasicGeoDataToDisk() {
        let provinceData = try? JSONEncoder().encode(basicGeoInfo?.provinceList)
        let citiesOfProvinceData = try? JSONEncoder().encode(basicGeoInfo?.citiesOfProvince)
        
        do {
            try provinceData?.write(to: provinceDataURL)
            try citiesOfProvinceData?.write(to: citieDataURL)
        } catch let error {
            print("error: \(error)")
        }
        
    }
    
    func fetchBasicGeoDataFromServer() -> Result<GeographicInfomation, NetworkError> {
        guard let url = URL(string: provinceURL) else {
            return .failure(.badurl)
        }
        
        // get the province data firt, then get cities
        var stageOneCompleted = false
        let semaphore = DispatchSemaphore(value: 0)
        var provinceList = [Province]()
        
        session.dataTask(with: url) {
            switch $0 {
            case .success(let data, _):
                provinceList = try! JSONDecoder().decode([Province].self, from: data)
                stageOneCompleted = true
            case .failure:
                stageOneCompleted = false
            }
            semaphore.signal()
        }.resume()
        
        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            return .failure(.timeout)
        }
        
        guard stageOneCompleted else {
            return .failure(.server)
        }
        // fetch cities from province list
        var stageTwoCompleted = true
        let group = DispatchGroup()
        var citiesOfProvince = [Province: [City]]()
        for province in provinceList {
            let cityURL = url.appendingPathComponent(province.code)
            group.enter()
            session.dataTask(with: cityURL) {
                switch $0 {
                case .success(let data, _):
                    let cities = try! JSONDecoder().decode([City].self, from: data)
                    citiesOfProvince[province] = cities
                case .failure:
                    stageTwoCompleted = false
                }
                group.leave()
            }.resume()
        }
        
        // wait until all cities' data downloaded
        let timeOutResult = group.wait(timeout: .now() + 10)
        switch timeOutResult {
        case .success:
            if stageTwoCompleted {
                return .success(GeographicInfomation(provinceList: provinceList, citiesOfProvince: citiesOfProvince))
            } else {
                return .failure(.network)
            }
        default:
            return .failure(.timeout)
        }
    }
    
}

extension URLSession {
    func dataTask(with url: URL, result: @escaping (Result<(Data, URLResponse), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url) { data, response, error in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                result(.failure(error!))
                return
            }
            if let data = data {
                result(.success((data, httpResponse)))
            }
        }
    }
}

extension FileManager {
    static var documentDirectory : URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

struct GeographicInfomation {
    let provinceList: [Province]
    let citiesOfProvince: [Province: [City]]
}

struct City: Codable {
    let province: String
    let city: String
    let code: String
    let url: String
    let id: String
}

struct Province: Codable, Hashable {
    let code: String
    let name: String
    let url: String
    
    static func ==(lhs: Province, rhs: Province) -> Bool {
        return lhs.code == rhs.code
    }
}

struct WeatherDetail: Codable {
    let station: City
    let publishTime: Date // 2019-10-06 14:15
    let temperature: Float
    let detail: [detail]
    
    enum CodingKeys: String, CodingKey {
        case station
        case publishTime = "publish_time"
        case temperature
        case detail
    }
    
    struct detail: Codable {
        let date: Date // 2019-10-06
        let pt: Date // 2019-10-06 12:00
        let day: DayNight
        let night: DayNight
        
        struct DayNight: Codable {
            let weather: Weather
            let wind: Wind
            
            struct Weather: Codable {
                let info: String
                let img: String
                let temperature: String
            }
            
            struct Wind: Codable {
                let direct: String
                let power: String
            }
        }
    }
}

struct RealData: Codable {
    let station: City
    let week: String
    let moon: String
    let jieQi: String
    let publishTime: Date
    let weather: WeatherData
    let wind: WindData
    let warn: WarnData
    
    enum CodingKeys: String, CodingKey {
        case station
        case week
        case moon
        case jieQi = "jie_qi"
        case publishTime = "publish_time"
        case weather
        case wind
        case warn
    }
    
    struct WeatherData: Codable {
        let temperature: Float
        let temperatureDiff: Float
        let airPressure: Float
        let humidity: Float
        let rain: Float
        let rcomfort: Float
        let icomfort: Float
        let info: String
        let img: String
        let feelst: Float
        
        enum CodingKeys: String, CodingKey {
            case temperature
            case temperatureDiff
            case airPressure = "airpressure"
            case humidity
            case rain
            case rcomfort
            case icomfort
            case info
            case img
            case feelst
        }
    }
    
    struct WindData: Codable {
        let direct: String
        let power: String
        let speed: String
    }
    
    struct WarnData: Codable {
        let alert: String
        let pic: String
        let province: String
        let city: String
        let url: String
        let issuecontent: String
        let fmeans: String
    }
}

struct TwentyFourHourForecast: Codable {
    let TempDiff: String
    let rain1h: Float
    let rain6h: Float
    let rain12h: Float
    let rain24h: Float
    let temperature: Float
    let humidity: Float
    let pressure: Float
    let windDirection: Float
    let windSpeed: Float
    let time: Date
}

struct SevenDayForecast: Codable {
    let realTime: Date
    let maxTemp: Float
    let minTemp: Float
    let dayImg: String
    let nightImg: String
}

enum NetworkError: Error {
    case badurl
    case network
    case server
    case timeout
}
