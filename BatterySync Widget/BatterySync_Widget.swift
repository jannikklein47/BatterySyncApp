//
//  BatterySync_Widget.swift
//  BatterySync Widget
//
//  Created by Jannik Klein on 17.04.25.
//

import WidgetKit
import SwiftUI

struct device : Codable {
    var name : String
    var battery : Double
    var isShown : Bool
}

struct BatteryEntry : TimelineEntry {
    
    // Der BatteryEntry ist nicht einer von vielen im Widget, sondern das ganze Widget Selber, er stellt die Datenstruktur dar
    let devices : [device]
    
    // Date ist ein muss, weil sonst TimelineEntry nicht funktioniert
    let date : Date
}

struct Provider : TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(devices: [device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true), device(name: "Gerätename", battery: 1, isShown: true)], date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(BatteryEntry(devices: loadDevices(), date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let entry = BatteryEntry(devices: loadDevices(), date: Date())
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    func loadDevices() -> [device] {
        if let data = UserDefaults.standard.data(forKey: "deviceInfo"), var decoded = try? JSONDecoder().decode([device].self, from: data) {
            
            //Prepare devices: Delete all entries that have isShown = false
            decoded = decoded.filter {
                $0.isShown
            }
            
            let deviceCount = decoded.count
                        
            for _ in deviceCount...8 {
                decoded.append(device(name: " ", battery: -1, isShown: true))
            }
            
            return decoded
        }
        
        return []
    }
}

struct BatteryEntryWidgetView : View{
    @Environment(\.widgetFamily) var family
    
    var entry : Provider.Entry
    
    var columns: [GridItem] {
        let count = (family == .systemSmall) ? 1 : 2
        return Array(repeating: .init(.flexible()), count: count)
    }
    
    @ViewBuilder
    var body : some View {
        
        GeometryReader { geo in
            ZStack {
                Color(.init(red: 0.14, green: 0.15, blue: 0.18))
                    .edgesIgnoringSafeArea(.all)
                    .frame(width: geo.size.width + 32, height: geo.size.height + 32)
                    .offset(x: -16, y: -16)
                
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(entry.devices.indices, id: \.self) { i in
                        if i >= ((family == .systemSmall) ? 2 : (family == .systemMedium) ? 4 : 8) {
                            // Nichts
                        } else{
                            if (entry.devices[i].isShown) {
                                deviceEntry(deviceData: entry.devices[i]).frame(width: 150, height: 70)
                            } else {
                                // Just put the placeholder in
                                placeholderEntry()
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        
        
    }
         
}

struct BatterySync_Widget : Widget {
    let kind = "BatterySyncAppWidget"
    
    var body : some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BatteryEntryWidgetView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
        .configurationDisplayName("Batteriestatus")
        .description("Zeigt den letzten bekannten Akkustand an.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct deviceEntry : View {
    
    var deviceData : device
    
    var body : some View {
        VStack(spacing: 1) {
            Text(deviceData.name).font(.system(size: 10)).bold()//.lineLimit(1)
            BatteryView(batteryLevel: deviceData.battery).frame(width: 80, height: 24).padding(4)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct placeholderEntry : View {
    
    var body : some View {
        VStack(spacing: 1) {
            Text(" ").font(.system(size: 10)).bold().lineLimit(1)
            BatteryView(batteryLevel: -1).frame(width: 80, height: 24).padding()
        }
    }
}

struct HalfCircleShape : Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: rect.height , startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        return path
    }
}

struct BatteryView : View {
    var batteryLevel : Double

    @ViewBuilder
    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    GeometryReader { rectangle in
                        if (batteryLevel >= 0) {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(lineWidth: 3)
                                .foregroundStyle(.gray)
                            RoundedRectangle(cornerRadius: 3)
                                .padding(4)
                                .frame(width: rectangle.size.width - ((rectangle.size.width - 6) * (1 - (batteryLevel > -1 ? batteryLevel : 1))))
                                .foregroundColor(batteryColor(batteryLevel: batteryLevel))
                        } else {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(lineWidth: 3)
                                .foregroundStyle(Color.init(red: 0.2, green: 0.2, blue: 0.2))
                        }
                        
                        
                    }
                    HalfCircleShape()
                        .frame(width: geo.size.width / 4, height: geo.size.height / 4)
                        .foregroundStyle(batteryLevel >= 0 ? .gray : Color.init(red: 0.2, green: 0.2, blue: 0.2))
                    
                }
                .padding(.leading)
                
                if (batteryLevel <= 0.15 && batteryLevel > -1) {
                    //Image(systemName: "")
                    HStack {
                        Text(String(Int(batteryLevel * 100))).foregroundStyle(.foreground).bold()
                        Text("!").font(.system(size: 20)).foregroundStyle(.red).bold()
                    }
                } else if (batteryLevel > -1) {
                    Text(String(Int(batteryLevel * 100))).foregroundStyle(.foreground).bold()
                }
                
            }
            
        }
    }
}

func batteryColor(batteryLevel: Double) -> Color {
    switch batteryLevel {
        // returns red color for range %0 to %20
        case 0...0.15:
            return Color.red
        // returns yellow color for range %20 to %50
        case 0.15...0.30:
            return Color.yellow
        // returns green color for range %50 to %100
        case 0.3...1.0:
        if #available(macOS 15.0, *) {
            //return Color.green.mix(with: .primary, by: -0.2)
            return Color.init(red: 0, green: 0.6, blue: 0)
        } else {
            return Color.green
        }
        default:
            return Color.clear
    }
}

