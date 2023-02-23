//
//  Subscription.swift
//  WidgetPush
//
//  Created by BJ Malicoat on 10/31/22.
//

import CoreData
import Foundation

struct SubscriptionManager {
    static let sharedInstance = SubscriptionManager()
    
    let managedObjectContext = PersistenceController.sharedInstance.container.viewContext
    
    func grantSubscription() {
        let fetchRequest: NSFetchRequest<Subscription>
        fetchRequest = Subscription.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            if let existingSubscription = try managedObjectContext.fetch(fetchRequest).first {
                existingSubscription.premium = true
            } else {
                let subscription = Subscription(context: managedObjectContext)
                subscription.premium = true
            }
        } catch {
            
        }
        
        PersistenceController.sharedInstance.save()
    }
    
    func revokeSubscription() {
        let fetchRequest: NSFetchRequest<Subscription>
        fetchRequest = Subscription.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            if let existingSubscription = try managedObjectContext.fetch(fetchRequest).first {
                existingSubscription.premium = false
            } else {
                let subscription = Subscription(context: managedObjectContext)
                subscription.premium = false
            }
        } catch {
            
        }
        
        PersistenceController.sharedInstance.save()
    }
    
    func checkSubscriptionReceipt() {
        // TODO Restore Purchases 
    }
}
