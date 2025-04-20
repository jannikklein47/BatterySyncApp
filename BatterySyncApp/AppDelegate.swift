//
//  AppDelegate.swift
//  BatterySyncApp
//
//  Created by Jannik Klein on 17.04.25.
//


import SwiftUI
import WidgetKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem?
    var loggedIn: String?
    var configureAccountWindow: NSWindow?
    var devicesWindow: NSWindow?
    var devicesWindowContentView: (any View)?
    var accountStatusItem : NSMenuItem?
    var serviceReachable : Bool = false
    let configureAccountWindowDelegate = WindowCloseDelegate(onClose: {})  // ✅ wichtig: persistenter Delegate
    var devicesWindowDelegate : WindowCloseDelegate?
    

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        
        print("Application launch finished")
        
        devicesWindowDelegate = WindowCloseDelegate(onClose: {
            self.devicesWindow = nil
        })
        
        let authToken = UserDefaults.standard.string(forKey: "authToken")
        
        // Dies muss DIREKT beim start geschehen!
        if (authToken != nil) {
            print("AuthToken found: \(authToken!)")
            self.validateToken(authToken!) { result in
                if (result == "") {
                    // Auth-Token ist nicht mehr gültig
                    UserDefaults.standard.set(nil, forKey: "authToken")
                    self.loggedIn = nil
                    print("Automatic login resulted in error")
                } else {
                    // Auth-Token ist gültig
                    self.loggedIn = result
                    UserDefaults.standard.set(result, forKey: "email")
                    print("Automatic login successful, email: \(result)")
                }
                
            }
        } else {
            // When no token is found, validate is not called. Thus, we do not check service availability! But we need to!
            print("No AuthToken found")
            checkServiceAvailability()
            
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Battery Status")
            button.action = #selector(menuBarClicked)
        }

        // Starte dein Monitoring
        BatteryMonitor.shared.startMonitoring()
        
        _ = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) {_ in
            self.checkServiceAvailability()
        }
    }

    @objc func menuBarClicked() {
        
        let menu = NSMenu(title: "BatterySyncApp")
        
        // Titel-Section
        menu.addItem(NSMenuItem.sectionHeader(title: "BatterySyncApp"))
        menu.addItem(NSMenuItem.separator())
        //
        
        // Button-Section
        menu.addItem(NSMenuItem(title: "Batteriestatus aktualisieren", action: #selector(refresh), keyEquivalent: "R"))
        let devicesItem = NSMenuItem(title: "Geräteeinstellungen…", action: #selector(openDevicesWindow), keyEquivalent: "")
        devicesItem.target = self
        menu.addItem(devicesItem)
        let accountItem = NSMenuItem(title: "Account konfigurieren…", action: #selector(openAccountWindow), keyEquivalent: "")
        accountItem.target = self
        menu.addItem(accountItem)
        
        print("Menü bar geöffnet / Service erreichbar stand \(self.serviceReachable)")
        
        if (self.serviceReachable) {
            accountStatusItem = NSMenuItem(title: "Status: \(loggedIn != nil ? "angemeldet als \(loggedIn!)" : "nicht angemeldet")", action: nil, keyEquivalent: "")
        } else {
            accountStatusItem = NSMenuItem(title: "Dienste nicht erreichbar.", action: nil, keyEquivalent: "")
        }
        
        menu.addItem(accountStatusItem!)
        menu.addItem(NSMenuItem.separator())
        //
        
        
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(quit), keyEquivalent: "Q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil) // öffnet das Menü direkt
    }

    @objc func refresh() {
        BatteryMonitor.shared.forceCheckBatteryStatus()
    }
    
    @objc func openAccountWindow(_ sender: NSStatusBarButton) {
        // set the window width and height
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 200
        // center the window under the cursor
        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let windowX = mouseLocation.x - windowWidth / 2
        let windowY = screenHeight - windowHeight
        // construct the window
        configureAccountWindow = getOrBuildConfigureAccountWindow(size: NSRect(
          x: windowX, y: windowY, width: windowWidth, height: windowHeight)
        )
        // show or hide the window
        toggleConfigureWindowVisibility(location: NSPoint(x: windowX, y: windowY))
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        configureAccountWindow?.makeKeyAndOrderFront(nil)
        configureAccountWindow?.becomeKey()
    }
    
    @objc func openDevicesWindow(_ sender : NSStatusBarButton) {
        // set the window width and height
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 350
        // center the window under the cursor
        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let windowX = mouseLocation.x - windowWidth / 2
        let windowY = screenHeight - windowHeight
        
        devicesWindow = getOrBuildDevicesWindow(size: NSRect(
            x: windowX, y: windowY, width: windowWidth, height: windowHeight)
        )
        
        toggleDevicesWindowVisibility(location: NSPoint(x: windowX, y: windowY))
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        devicesWindow?.makeKeyAndOrderFront(nil)
        devicesWindow?.becomeKey()
    }
    
    @objc func getOrBuildConfigureAccountWindow(size: NSRect) -> NSWindow {
        if configureAccountWindow != nil {
            return configureAccountWindow.unsafelyUnwrapped
        }
        let contentView = ConfigureAccount(email: self.loggedIn == nil ? "" : self.loggedIn!, onLogin: { email, password in
            self.saveCredentials(email: email, password: password)
        }, onCancel: {_ in
            DispatchQueue.main.async {
                self.configureAccountWindow?.close()
            }
        })
        configureAccountWindow = NSWindow(
            contentRect: size,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)

        // 🧠 Hier den Delegate setzen
        configureAccountWindow?.delegate = configureAccountWindowDelegate

        
        let hostingView = NSHostingView(rootView: contentView)
        configureAccountWindow?.contentView = hostingView
        configureAccountWindow?.isReleasedWhenClosed = false
        configureAccountWindow?.collectionBehavior = .moveToActiveSpace
        configureAccountWindow?.level = .popUpMenu
        configureAccountWindow?.title = "Account konfigurieren"
        
        // Focus explicitly on the hostingView
        DispatchQueue.main.async {
            hostingView.window?.makeKeyAndOrderFront(nil)
            hostingView.window?.becomeKey()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        
        return configureAccountWindow.unsafelyUnwrapped
    }
    
    @objc func getOrBuildDevicesWindow(size: NSRect) -> NSWindow {
        if devicesWindow != nil {
            return devicesWindow.unsafelyUnwrapped
        }
        let contentView = DeviceSettings(onClose: {
            DispatchQueue.main.async {
                self.devicesWindow?.close()
            }
        })
        devicesWindow = NSWindow(
            contentRect: size,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)

        // 🧠 Hier den Delegate setzen
        devicesWindow?.delegate = devicesWindowDelegate

        
        let hostingView = NSHostingView(rootView: contentView)
        devicesWindow?.contentView = hostingView
        devicesWindow?.isReleasedWhenClosed = false
        devicesWindow?.collectionBehavior = .moveToActiveSpace
        devicesWindow?.level = .popUpMenu
        devicesWindow?.title = "Geräteeinstellungen"
        
        // Focus explicitly on the hostingView
        DispatchQueue.main.async {
            hostingView.window?.makeKeyAndOrderFront(nil)
            hostingView.window?.becomeKey()
            NSApplication.shared.activate(ignoringOtherApps: true)
            contentView.getDeviceData()
        }
        
        return devicesWindow.unsafelyUnwrapped
    }

    
    func toggleConfigureWindowVisibility(location: NSPoint) {
        // window hasn't been built yet, don't do anything
        if configureAccountWindow == nil {
            return
        }
        if configureAccountWindow!.isVisible {
            configureAccountWindow?.orderOut(nil)
        } else {
            configureAccountWindow?.setFrameOrigin(location)
            NSApp.activate(ignoringOtherApps: true)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            configureAccountWindow?.makeKeyAndOrderFront(nil)
            //window?.becomeKey()
        }

    }
    func toggleDevicesWindowVisibility(location: NSPoint) {
        // window hasn't been built yet, don't do anything
        if devicesWindow == nil {
            return
        }
        if devicesWindow!.isVisible {
            devicesWindow?.orderOut(nil)
        } else {
            devicesWindow?.setFrameOrigin(location)
            NSApp.activate(ignoringOtherApps: true)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            devicesWindow?.makeKeyAndOrderFront(nil)
            
            //window?.becomeKey()
        }

    }
    
    func saveCredentials(email: String, password: String) {
        print("Email: \(email)")
        print("Passwort: \(password)")
        
        // Beispiel: API-Call vorbereiten
        let url = URL(string: "http://localhost:3000/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Call ausführen
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Fehler: \(error)")
                self.serviceReachable = false
                self.changeLoginStatus()
                return
            }
            
            guard let data = data else {
                print("Keine Daten erhalten")
                return
            }
            
            self.serviceReachable = true
            self.changeLoginStatus()
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Antwort: \(responseString)")
                        UserDefaults.standard.set(responseString, forKey: "authToken")
                        UserDefaults.standard.set(email, forKey: "email")
                        
                        self.changeLoginStatus()
                        BatteryMonitor.shared.forceCheckBatteryStatus() // Nach dem Login direkt alles reloaden
                        
                        //self.window?.contentView.rootView.loginFailed = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.configureAccountWindow?.close()
                            self.configureAccountWindow = nil
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                } else {
                    print("Login failed / denied by server")
                    UserDefaults.standard.set("", forKey: "authToken")
                    UserDefaults.standard.set(nil, forKey: "email")
                    
                    self.changeLoginStatus()
                }
            }
            
            
        }.resume()
    }
    
    func changeLoginStatus() {
        guard let email = UserDefaults.standard.string(forKey: "email") else {
            return
        }
        self.loggedIn = email
        if (self.serviceReachable) {
            if (email == "") {
                if (accountStatusItem != nil) {
                    self.accountStatusItem!.title = "Status: Nicht angemeldet"
                }
                
            } else {
                if (accountStatusItem != nil) {
                    self.accountStatusItem!.title = "Status: angemeldet als \(email)"
                }
                
            }
            
        } else {
            self.accountStatusItem!.title = "Dienste nicht erreichbar."
        }
        print("Login status changed")
        
    }
    
    func validateToken(_ token: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "http://localhost:3000/login/auth") else {
            completion("")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Fehlerbehandlung, also timeouts, z.B. wenn man kein Internet hat:
            if let error = error {
                print("Fehler beim Validieren: \(error.localizedDescription)")
                //completion("")
                self.serviceReachable = false
                //self.changeLoginStatus()
                return
            }
            
            guard let data = data else {
                print("Keine Daten erhalten")
                //completion("")
                return
            }
            
            self.serviceReachable = true
            //self.changeLoginStatus()
            
            // Statuscode prüfen
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Token validated for email \(responseString)")
                        completion(responseString)
                        return
                    }
                    print("Auth response does not match requirements")
                    completion("")
                } else {
                    // Ungültiger Token
                    print("Ungültiger AuthToken")
                    completion("")
                }
            } else {
                print("Error in auth request")
                completion("")
            }
        }

        task.resume()
    }
    
    func checkServiceAvailability() {
        let url = URL(string: "http://localhost:3000/debug")!
        var request = URLRequest(url: url)
        
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let _ = error {
                self.serviceReachable = false
                print("ServiceCheck: Service is not reachable")
                self.changeLoginStatus()
                return
            }
            
            self.serviceReachable = true
            print("ServiceCheck: Service is reachable")
            if let token = UserDefaults.standard.string(forKey: "authToken") {
                self.validateToken(token, completion: {_ in
                    self.changeLoginStatus()
                })
            }
            
        }.resume()
        
    }


    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    final class WindowCloseDelegate: NSObject, NSWindowDelegate {
        
        var onClose : () -> Void
        
        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }
        
        func windowWillClose(_ notification: Notification) {
            print("🔒 Fenster wurde geschlossen")
            
            // Menüleistenmodus wiederherstellen
            NSApp.setActivationPolicy(.prohibited)
            
            // To force-reload UserDefaults the next time it is opened, ensuring up to date data
            onClose()
        }
    }

}
