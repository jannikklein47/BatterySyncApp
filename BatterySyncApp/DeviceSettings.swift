//
//  DeviceSettings.swift
//  BatterySyncApp
//
//  Created by Jannik Klein on 18.04.25.
//

import AppKit
import SwiftUI
import WidgetKit

struct DeviceSettings : View {
    
    @State var devices : [device] = []
    var onClose : () -> Void
    
    @ViewBuilder
    var body : some View {
        VStack {
            Text("Geräteeinstellungen").font(.system(size: 20)).bold()
            Divider()
            
            ScrollView {
                if (devices.count == 0) {
                    ProgressView()

                } else {
                    
                    ForEach(devices.indices, id: \.self) {i in
                        HStack {
                            Image(systemName: devices[i].isShown ? "pin" : "pin.slash")
                            Text("\(devices[i].name)").bold().font(.system(size: 15)).foregroundStyle(devices[i].isShown ? Color.primary : Color.gray)
                            Text("(\(Int(devices[i].battery * 100))%)").foregroundStyle(devices[i].isShown ? Color.primary : Color.gray)
                            Spacer()
                            Button(devices[i].isShown ? "Verstecken" : "Anzeigen") {
                                devices[i].isShown = !devices[i].isShown
                                self.saveIsShown(name: devices[i].name, value: devices[i].isShown)
                            }
                            Button("Löschen") {
                                self.deleteDevice(name: devices[i].name, originalIndex: i)
                            }
                        }.transition(.scale)
                    }
                }
            }
            
            Divider()
            HStack {
                Button("Aktualisieren") {
                    self.devices = []
                    self.getDeviceData()
                }
                Spacer()
                Button("Schließen") {
                    onClose()
                }
            }
            
        }.padding().frame(width: 600, height: 350).onAppear {
            getDeviceData()
        }
    }
    
    func getDeviceData() {
        if let data = UserDefaults.standard.data(forKey: "deviceInfo"), let decoded = try? JSONDecoder().decode([device].self, from: data) {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                print("Device Data loaded")
                self.devices = decoded
            }
        } else {
            print("Keine DeviceInfo, versuche es in 5 Sekunden erneut...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                getDeviceData()
            }
        }
    }
    
    func saveIsShown(name: String, value: Bool) {
        guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
            print("No AuthToken to update isShown")
            return
        }
        let url = URL(string: "http://\(Globals.IPADDRESS):3000/device")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        let body = [
            "name": name,
            "isShown": value
        ] as [String : Any]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Fehler: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Keine Daten erhalten")
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("SaveIsShown Antwort: \(responseString)")
                // Jetzt aber auch UserDefaults aktualisieren!
                saveToDefaults()
                
            } else {
                print("Login failed / denied by server")
            }
            
            
            
        }.resume()
    }
    
    func deleteDevice(name: String, originalIndex: Int) {
        guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
            print("No AuthToken to update isShown")
            return
        }
        let url = URL(string: "http://\(Globals.IPADDRESS):3000/device")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        let body = [
            "name": name,
        ] as [String : Any]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Fehler: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Keine Daten erhalten")
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Antwort: \(responseString)")
                self.devices.remove(at: originalIndex)
                saveToDefaults()
            } else {
                print("Login failed / denied by server")
            }
            
            
            
        }.resume()
    }
    
    func saveToDefaults() {
        
        if let encoded = try? JSONEncoder().encode(self.devices) {
            
            UserDefaults.standard.set(encoded, forKey: "deviceInfo")
            UserDefaults.standard.set(Date(), forKey: "lastUpdate")
            
            print("Jetzt versuchen wir, die Timelines zu reloaden!")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

#Preview {
    DeviceSettings(onClose: {})
}
