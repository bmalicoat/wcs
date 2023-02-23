//
//  IntentHandler.swift
//  WidgetValueIntent
//
//  Created by BJ Malicoat on 9/18/22.
//

import Intents
import CoreData

class IntentHandler: INExtension, SmallWidgetIntentHandling, MediumWidgetIntentHandling, LargeWidgetIntentHandling, ExtraLargeWidgetIntentHandling {
    
    func resolveWidgetIntentData(for intent: SmallWidgetIntent, with completion: @escaping (WidgetIntentDataResolutionResult) -> Void) {
        if let value = intent.WidgetIntentData {
            completion(WidgetIntentDataResolutionResult.success(with: value))
        }
    }
    
    func resolveWidgetIntentData(for intent: MediumWidgetIntent, with completion: @escaping (WidgetIntentDataResolutionResult) -> Void) {
        if let value = intent.WidgetIntentData {
            completion(WidgetIntentDataResolutionResult.success(with: value))
        }
    }
    
    func resolveWidgetIntentData(for intent: LargeWidgetIntent, with completion: @escaping (WidgetIntentDataResolutionResult) -> Void) {
        if let value = intent.WidgetIntentData {
            completion(WidgetIntentDataResolutionResult.success(with: value))
        }
    }
    
    func resolveWidgetIntentData(for intent: ExtraLargeWidgetIntent, with completion: @escaping (WidgetIntentDataResolutionResult) -> Void) {
        if let value = intent.WidgetIntentData {
            completion(WidgetIntentDataResolutionResult.success(with: value))
        }
    }
    
    func provideWidgetIntentDataOptionsCollection(for intent: SmallWidgetIntent, with completion: @escaping (INObjectCollection<WidgetIntentData>?, Error?) -> Void) {
        provideWidgetIntentDataOptionsCollection(widget_size: "small", with: completion)
    }
    
    func provideWidgetIntentDataOptionsCollection(for intent: MediumWidgetIntent, with completion: @escaping (INObjectCollection<WidgetIntentData>?, Error?) -> Void) {
        provideWidgetIntentDataOptionsCollection(widget_size: "medium", with: completion)
    }
    
    func provideWidgetIntentDataOptionsCollection(for intent: LargeWidgetIntent, with completion: @escaping (INObjectCollection<WidgetIntentData>?, Error?) -> Void) {
        provideWidgetIntentDataOptionsCollection(widget_size: "large", with: completion)
    }
    
    func provideWidgetIntentDataOptionsCollection(for intent: ExtraLargeWidgetIntent, with completion: @escaping (INObjectCollection<WidgetIntentData>?, Error?) -> Void) {
        provideWidgetIntentDataOptionsCollection(widget_size: "extra_large", with: completion)
    }
    
    func provideWidgetIntentDataOptionsCollection(widget_size: String, with completion: @escaping (INObjectCollection<WidgetIntentData>?, Error?) -> Void) {
        var availableValues: [WidgetIntentData] = []
        
        let persistenceContainer = PersistenceController.sharedInstance.container.viewContext
        let request = NSFetchRequest<SubscribedWidget>(entityName: "SubscribedWidget")
        
        do {
            let subscribedWidgets = try persistenceContainer.fetch(request)
            
            for subscribedWidget in subscribedWidgets {
                if (subscribedWidget.size == widget_size) {
                    if let cachedWidget = getCachedWidget(id: subscribedWidget.id), let id = subscribedWidget.id, let jsonString = cachedWidget.data {
                        let convertedWidget = convertDataToWidget(id: id, data: Data(jsonString.utf8))
                        
                        if let widget = convertedWidget.widget {
                            let value = WidgetIntentData(identifier: subscribedWidget.id, display: widget.name)
                            value.size = subscribedWidget.size
                            availableValues.append(value)
                        }
                    }
                }
            }
        } catch {
            
        }
        
        let collection = INObjectCollection(items: availableValues)
        
        completion(collection, nil)
    }
}

