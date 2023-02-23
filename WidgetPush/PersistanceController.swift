//
//  PersistanceController.swift
//  WidgetPush
//
//  Created by BJ Malicoat on 10/12/22.
//

import CoreData
import Foundation

struct PersistenceController {
    static let sharedInstance = PersistenceController()
    
    let container: NSPersistentContainer
    
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // TODO create sample data in this context
        
        return controller
    }()
    
    init(inMemory: Bool = false) {
        
        let directory: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bmalicoat.wdgt")!
        let containerName: String = "wdgt_widgets"
        
        container = NSPersistentContainer(name: containerName)
        
        guard let _ = try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil) else {
            fatalError()
        }
        
        let persistentStoreUrl = directory.appendingPathComponent("\(containerName).sqlite")
        
        print("Saving data to " + persistentStoreUrl.absoluteString)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let persistentStoreDescription = NSPersistentStoreDescription(url: persistentStoreUrl)
            
            // Tell CoreData to watch for changes that happen outside our app.
            // When the widget fetches data, we want to be notified in-app.
            persistentStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            persistentStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [ persistentStoreDescription ]
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
            }
        }
    }
    
    // Since widgets on the Home Screen might still exist even after removed from the app,
    // they might still be getting fetched and cached. Let's check to see if we have cached data
    // for widgets we don't subscribe to. If we do, delete that cached data.
    func clearDanglingCache() {
        let subscribedWidgetFetch: NSFetchRequest<SubscribedWidget> = SubscribedWidget.fetchRequest()
        let cachedWidgetFetch: NSFetchRequest<CachedWidget> = CachedWidget.fetchRequest()
        var dbDirty = false
        do {
            let subscribedWidgets = try container.viewContext.fetch(subscribedWidgetFetch)
            let cachedWidgets = try container.viewContext.fetch(cachedWidgetFetch)
            
            for cachedWidget in cachedWidgets {
                if subscribedWidgets.first(where: { $0.id == cachedWidget.id}) == nil {
                    dbDirty = true
                    container.viewContext.delete(cachedWidget)
                }
            }
        } catch let error {
            print("Error deleting subscribed widgets:", error)
        }
        
        if dbDirty {
            save()
        }
    }
    
    func deleteAllData() {
        let entities = ["SubscribedWidget", "CachedWidget", "TelemetryData", "Subscription"]

        for entity in entities {
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                batchDeleteRequest.resultType = .resultTypeObjectIDs
                let result = try container.viewContext.execute(batchDeleteRequest) as! NSBatchDeleteResult
                let changes: [AnyHashable: Any] = [
                    NSDeletedObjectsKey: result.result as! [NSManagedObjectID]
                ]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
            } catch let error {
                print("Error deleting \(entity): \(error)")
            }
        }
    }
}
