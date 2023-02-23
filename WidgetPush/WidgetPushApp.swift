//
//  WidgetPushApp.swift
//  WidgetPush
//
//  Created by BJ Malicoat on 9/6/22.
//

import CoreData
import SwiftUI

@main
struct WidgetPushApp: App {
    @State var showAddSheetView = false
    @State var widgetId: String = ""
    @State var widgetUser: String = ""
    @State var widgetPassword: String = ""
    @State var widgetDetailsWidgetData: SubscribedWidget? = nil
    @Environment(\.scenePhase) var scenePhase
    
    let persistenceController = PersistenceController.sharedInstance
    
    init() {
        Task {
            await TryRestorePurchases()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(showAddSheetView: $showAddSheetView, widgetId: $widgetId, widgetUser: $widgetUser, widgetPassword: $widgetPassword, widgetDetailsWidgetData: $widgetDetailsWidgetData)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    if let scheme = url.scheme {
                        if (scheme == "widget") {
                            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), let action = urlComponents.host, let queryItems = urlComponents.queryItems {
                                
                                print(url)
                                switch action {
                                case "link_url":
                                    let url = queryItems.filter({$0.name == "url"}).first?.value?.removingPercentEncoding ?? ""
                                    let id = queryItems.filter({$0.name == "id"}).first?.value?.removingPercentEncoding ?? ""
                                    let index = Int(queryItems.filter({$0.name == "index"}).first?.value ?? "")
                                    
                                    if let url = URL(string: url) {
                                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                    }
                                case "launch_url":
                                    let url = queryItems.filter({$0.name == "url"}).first?.value?.removingPercentEncoding ?? ""
                                    let id = queryItems.filter({$0.name == "id"}).first?.value?.removingPercentEncoding ?? ""
                                    
                                    if let url = URL(string: url) {
                                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                    }
                                case "add_widget":
                                    let url = queryItems.filter({$0.name == "url"}).first?.value?.removingPercentEncoding ?? ""
                                    let user = queryItems.filter({$0.name == "user"}).first?.value?.removingPercentEncoding ?? ""
                                    let password = queryItems.filter({$0.name == "password"}).first?.value?.removingPercentEncoding ?? ""
                                    
                                    widgetId = url
                                    widgetUser = user
                                    widgetPassword = password
                                    showAddSheetView = true
                                default:
                                    print("Unknown launch action!")
                                }
                            }
                        } else if (scheme == "https") {
                            widgetId = url.absoluteString
                            showAddSheetView = true
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                persistenceController.save()
            } else if phase == .active {
                persistenceController.clearDanglingCache()
            }
        }
    }
}
