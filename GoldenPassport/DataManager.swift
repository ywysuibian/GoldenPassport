//
//  DataManager.swift
//  GoldenPassport
//
//  Created by StanZhai on 2017/2/26.
//  Copyright © 2017年 StanZhai. All rights reserved.
//

import Foundation

final class DataManager {
    static let shared = DataManager()
    private let authDataFile = "gp.secrets"
    private let configFile = "config.plist"

    private var authData: [String: String]
    private var config: [String: String]

    private init() {
        authData = [:]
        config = [:]
        authData = loadData(authDataFile)
        config = loadData(configFile)
    }

    func addOTPAuthURL(tag: String, url: String) {
        authData[tag] = url
        saveData(authDataFile, data: authData)
    }

    func removeOTPAuthURL(tag: String) {
        authData.removeValue(forKey: tag)
        saveData(authDataFile, data: authData)
    }
    
    func getOTPAuthURL(tag: String) -> String {
        let url = authData[tag]
        return url!
    }

    func allAuthCode() -> [(key: String, value: String)] {
        var result: [String: String] = [:]
        for d in authData {
            let url = d.value
            let otpData = OTPAuthURLParser(url)!

            let data = OTPAuthURL.base32Decode(otpData.secret)
            let gen = TOTPGenerator(secret: data,
                                    algorithm: TOTPGenerator.defaultAlgorithm(),
                                    digits: TOTPGenerator.defaultDigits(),
                                    period: TOTPGenerator.defaultPeriod())
            let code = gen?.generateOTP(for: Date())

            result[d.key] = code
        }
        return result.sorted { (r1, r2) -> Bool in
            return r1.key < r2.key
        }
    }

    func dataCount() -> Int {
        return authData.count
    }

    func getHttpServerAutoStart() -> Bool {
        let auto = getConfig("http_server_auto_start")
        if (auto == nil || auto == "true") {
            return true;
        } else {
            return false;
        }
    }

    func saveHttpServerAutoStart(auto: Bool) {
        saveConfig(key: "http_server_auto_start", value: "\(auto)")
    }

    func getHttpServerPort() -> String {
        return getConfig("http_server_port") ?? "\(DEFAULT_HTTP_PORT)"
    }

    func saveHttpServerPort(port: String) {
        saveConfig(key: "http_server_port", value: port)
    }

    func getConfig(_ key: String) -> String? {
        return config[key]
    }

    func saveConfig(key: String, value: String) {
        config[key] = value
        saveData(configFile, data: config)
    }
    
    func importData(dist: URL) -> Int {
        let d = NSKeyedUnarchiver.unarchiveObject(withFile: dist.path)
        if d == nil {
            return 0
        }
        let data = d as! [String: String]
        var count = 0;
        for k in data {
            if authData[k.key] == nil {
                authData[k.key] = k.value
                count = count + 1
            }
        }
        saveData(authDataFile, data: authData)
        return count
    }
    
    func exportData(dist: URL) {
        let fileLocation = "\(dataFilePath)\(authDataFile)"
        let fileUrl = URL(fileURLWithPath: fileLocation)
        let manager = FileManager.default
        try? manager.copyItem(at: fileUrl, to: dist)
    }

    private func saveData(_ dataFile: String, data: [String: String]) {
        let fileLocation = "\(dataFilePath)\(dataFile)"
        let fileUrl = URL(fileURLWithPath: fileLocation)
        try? NSKeyedArchiver.archivedData(withRootObject: data).write(to: fileUrl)
    }

    private func loadData(_ dataFile: String) -> [String: String] {
        let fileLocation = "\(dataFilePath)\(dataFile)"
        let d = NSKeyedUnarchiver.unarchiveObject(withFile: fileLocation)
        if d != nil {
            return d as! [String: String]
        }
        return [:]
    }

    private var dataFilePath: String {
        let fileManager = FileManager.default
        let path = NSSearchPathForDirectoriesInDomains(
            Foundation.FileManager.SearchPathDirectory.applicationSupportDirectory,
            Foundation.FileManager.SearchPathDomainMask.userDomainMask,
            true).first! + "/GoldenPassport/"
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error)
            }
        }
        
        return path
    }
    
}
