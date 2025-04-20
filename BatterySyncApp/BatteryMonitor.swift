//
//  BatteryMonitor.swift
//  BatterySyncApp
//
//  Created by Jannik Klein on 17.04.25.
//

import SwiftUI
import WidgetKit
import IOKit.ps

struct device : Codable, Equatable {
    var name : String
    var battery : Double
    var isShown : Bool
}

class BatteryMonitor {
    
    static let shared = BatteryMonitor()

    private var lastLevel: Int = -1
    private var timer: Timer?
    
    private var localBatteryMonitoring = LocalBatteryMonitoring()
    
    var errorMessage : String = ""
    var serviceReachable : Bool = false

    func startMonitoring() {
        self.checkBatteryStatus()
        self.localBatteryMonitoring.checkBatteryStatus(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.checkBatteryStatus()
            self.localBatteryMonitoring.checkBatteryStatus(force: false)
        }
    }
    
    func forceCheckBatteryStatus() {
        self.checkBatteryStatus()
        self.localBatteryMonitoring.checkBatteryStatus(force: true)
    }
    
    func checkBatteryStatus() {
        // Erstmal muss der aktuelle authToken geladen werden.
        
        let authToken = UserDefaults.standard.string(forKey: "authToken")
        
        if (authToken == nil) {
            print("Es gibt keinen aktuellen authToken. Darum wird keine GET-Request für Akkus gesendet.")
            // Idee: Anzeigen, dass man sich anmelden muss.
            return
        }
        
        guard let url = URL(string: "http://localhost:3000/battery") else {return}
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        //print("Test")
        
        URLSession.shared.dataTask(with: req) { data, response, error in
            
            if let error = error {
                // Fehler in der Anfrage
                print("BatteryMonitor GET: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                return
                
            }
            
            guard let data = data else {
                print("BatteryMonitor GET: Keine Daten")
                self.serviceReachable = false
                return
            }
        
            let responseString = String(data: data, encoding: .utf8)!
            
            print("Antwort von GET: \(responseString)")
            
            
            //print("Antwort des Backends: \(responseString).\nVerarbeitete Daten:")

            if let jsonData = responseString.data(using: .utf8) {
                let decoder = JSONDecoder()
                do {
                    let collection = try decoder.decode([device].self, from: jsonData)
                    
                    self.serviceReachable = true
                    
                    self.updateWidget(devices: collection)
                    
                    
                } catch {
                    //print("Fehler beim Dekodieren: \(error)")
                    self.serviceReachable = false
                    self.errorMessage = error.localizedDescription
                }
            } else {
                //print("Ungültiger JSON-String")
                self.serviceReachable = false
                //errorMessage = error.localizedDescription
            }
            
            
        }.resume()
        
    }
    
    func updateWidget(devices : [device]) {
        guard let data = UserDefaults.standard.data(forKey: "deviceInfo"),
                  let currentStatuses = try? JSONDecoder().decode([device].self, from: data) else {
                // Kein vorheriger Eintrag -> speichern
                print("Noch kein Default-Eintrag!")
                saveDevicesToUserDefaults(devices: devices)
                return
            }
        
        print("Defaults: \(currentStatuses)")

            if currentStatuses != devices {
                // Nur speichern, wenn sich was geändert hat
                saveDevicesToUserDefaults(devices: devices)
            }
    }
    
    func saveDevicesToUserDefaults(devices: [device]) {
        print("Neue Defaults werden gespeichert...")
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: "deviceInfo")
            UserDefaults.standard.set(Date(), forKey: "lastUpdate")
            
            print("Jetzt versuchen wir, die Timelines zu reloaden!")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}


class LocalBatteryMonitoring {
    private var lastBatteryLevel: Double = -1

    public func checkBatteryStatus(force: Bool) {
        
        if force { lastBatteryLevel = -1}
        
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let description = IOPSGetPowerSourceDescription(info, sources.first!)?.takeUnretainedValue() as? [String: Any],
              let currentCapacityInt = description[kIOPSCurrentCapacityKey as String] as? Int else {
            return
        }
        
        let currentCapacityDouble : Double = Double(currentCapacityInt) / 100

        if currentCapacityDouble != lastBatteryLevel {
            lastBatteryLevel = currentCapacityDouble
            print("Akkustand geändert: \(currentCapacityDouble)%")
            self.sendBatteryUpdate(level: currentCapacityDouble)
        }
    }

    private func sendBatteryUpdate(level: Double) {
        
        let authToken = UserDefaults.standard.string(forKey: "authToken")
        
        if (authToken == nil) {
            print("Keinen authToken gefunden, also keine POST gesendet")
        }
        
        guard let url = URL(string: "http://localhost:3000/battery?device=Macbook+Pro+von+Jannik&battery=\(level)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request).resume()
    }
}
