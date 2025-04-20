//
//  BatterySyncAppApp.swift
//  BatterySyncApp
//
//  Created by Jannik Klein on 17.04.25.
//

import SwiftUI
//import WidgetKit

@main
struct BatterySyncAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
