//
//  Common.swift
//  WidgetPush
//
//  Created by BJ Malicoat on 9/24/22.
//

import CoreData
import Foundation
import SwiftUI
import WidgetKit
import StoreKit

struct Config {
    static let refreshIntervalInMinutes = 15
}

class ObservablePasswordPrompt: ObservableObject {
    static let sharedInstance = ObservablePasswordPrompt()
    @Published var show: Bool = false
}

class ObservableCheckmarkModal: ObservableObject {
    static let sharedInstance = ObservableCheckmarkModal()
    @Published var show: Bool = false
}

extension String {
    func capitalizeFirstCharacter() -> String {
        var result = self
        
        let substr1 = String(self[startIndex]).uppercased()
        result.replaceSubrange(...startIndex, with: substr1)
        
        return result
    }
    
    func stableHash() -> UInt64 {
        var result = UInt64 (5381)
        let buf = [UInt8](self.utf8)
        for b in buf {
            result = 127 * (result & 0x00ffffffffffffff) + UInt64(b)
        }
        return result
    }
    
    func isGradient() -> Bool {
        return self.hasPrefix("linear-gradient")
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
    
    // Parses colors of #rrggbb or #rrggbbaa
    init(hashCode: String) {
        
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var opacity = 1.0
        
        var color_string = hashCode
        color_string.remove(at: color_string.startIndex)
        
        var alpha_present = false;
        
        if color_string.count == 8 {
            alpha_present = true
        }
        
        let color_uint = UInt(color_string, radix: 16) ?? 0
        
        if color_uint > 0 {
            var alpha_offset = 0
            
            if alpha_present {
                alpha_offset = 8
            }
            
            red = Double((color_uint >> (16 + alpha_offset)) & 0xff) / 255
            green = Double((color_uint >> (08 + alpha_offset)) & 0xff) / 255
            blue = Double((color_uint >> (00 + alpha_offset)) & 0xff) / 255
            
            if alpha_present {
                opacity = Double((color_uint >> 00) & 0xff) / 255
            }
        }
        
        self.init(.sRGB,
                  red: red,
                  green: green,
                  blue: blue,
                  opacity: opacity)
    }
}

struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

func fetchWidgetJSON(widget_id: String, user: String?, password: String?, allowCachedData: Bool, cacheData: Bool, with completion: @escaping (WidgetData?, String) -> Void) {
    let managedObjectContext = PersistenceController.sharedInstance.container.viewContext
    let sanitized_widget_id = widget_id.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    
    let genericError = "Please check URL and try again."
    
    if allowCachedData {
        if let existingCachedWidget = getCachedWidget(id: sanitized_widget_id), let jsonString = existingCachedWidget.data {
            let convertedWidget = convertDataToWidget(id: sanitized_widget_id, data: Data(jsonString.utf8))
            completion(convertedWidget.widget, convertedWidget.errorText)
            return
        }
    }
    
    if let url = URL(string: sanitized_widget_id) {
        var request = URLRequest(url: url)
        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        if let user = user, let password = password, !user.isEmpty, !password.isEmpty {
            request.addValue("Basic " + (user + ":" + password).data(using: .utf8)!.base64EncodedString(), forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                completion(nil, genericError)
                return
            }
            var new_widget: WidgetData? = nil
            var errorText: String = genericError
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    let widget_id = httpResponse.url?.absoluteString ?? sanitized_widget_id
                    let convertedWidget = convertDataToWidget(id: widget_id, data: data)
                    new_widget = convertedWidget.widget
                    errorText = convertedWidget.errorText
                    
                    if (cacheData) {
                        // Upsert this widget into our cache
                        let existingCachedWidget = getCachedWidget(id: widget_id)
                        
                        if let existingCachedWidget = existingCachedWidget {
                            existingCachedWidget.data = String(bytes:data, encoding: .utf8)
                        } else {
                            let cachedWidget = CachedWidget(context: managedObjectContext)
                            cachedWidget.id = widget_id
                            cachedWidget.data = String(bytes: data, encoding: .utf8)
                        }
                        
                        PersistenceController.sharedInstance.save()
                    }
                    
                case 401:
                    DispatchQueue.main.async {
                        ObservablePasswordPrompt.sharedInstance.show = true
                    }
                default:
                    print("unknown http error")
                }
                
                completion(new_widget, errorText)
            }
            
        }.resume()
    } else {
        completion(nil, genericError)
    }
}

func getCachedWidget(id: String?) -> CachedWidget? {
    if (id == nil) {
        return nil
    }
    
    let managedObjectContext = PersistenceController.sharedInstance.container.viewContext
    
    let fetchRequest: NSFetchRequest<CachedWidget>
    fetchRequest = CachedWidget.fetchRequest()
    fetchRequest.fetchLimit = 1
    fetchRequest.predicate = NSPredicate(
        format: "id LIKE %@", id!
    )
    
    do {
        let existingCachedWidget = try managedObjectContext.fetch(fetchRequest).first
        
        return existingCachedWidget
        
    } catch {
        return nil
    }
}

func convertDataToWidget(id: String, data: Data) -> (widget: WidgetData?, errorText: String) {
    let decoder =  JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
        let res = try decoder.decode(WidgetData.self, from: data)
        
        // Filter out extra large widgets that only work on iPad
        if (UIScreen.main.traitCollection.userInterfaceIdiom == .phone) {
            res.layouts = res.layouts.filter({ $0.value.size != "extra_large"})
            res.layout_display_order = res.layout_display_order?.filter({res.layouts[$0] != nil})
        }
        res.id = id
        
        return (res, "")
    } catch DecodingError.keyNotFound(let error) {
        var errorString = "Malformed widget.json\n\nMissing or invalid property: `\(error.0.stringValue)`"
        
        if let path = error.1.codingPath.first?.stringValue {
            errorString += " in object `\(path)`"
        }
        
        return (nil, errorString)
    } catch let error {
        print("Error deserializing json: ", error)
        return (nil, "Please check the URL and try again.")
    }
}

class WidgetData: Codable, Identifiable {
    var id: String? = ""
    var name: String = ""
    var content_last_modified: Date? = nil
    var data: Dictionary<String, String> = [:]
    var default_layout: String? = ""
    var thumbnail_layout: String? = ""
    var description: String? = ""
    var version: Int64? = nil
    var layout_display_order: [String]? = []
    var layouts: Dictionary<String, WidgetLayout> = [:]
}

struct WidgetLayout: Codable {
    var size: String
    var styles: Styles
    var layers: [WidgetLayer]
}

struct Styles: Codable {
    var colors: Dictionary<String, WidgetColorStyle>? = [:]
    var fonts: Dictionary<String, WidgetFontStyle>? = [:]
}

struct WidgetColorStyle: Codable {
    var label: String?
    var color: String
}

struct WidgetFontStyle: Codable {
    var label: String?
    var family: String?
}

struct WidgetLayer: Codable {
    var rows: [WidgetRow]?
}

struct WidgetRow: Codable {
    var height: Double
    var cells: [WidgetCell]?
}

struct WidgetCell: Codable {
    var width: Double
    var padding: Double?
    var background_color_style: String?
    var text: WidgetTextNode?
    var image: WidgetImageNode?
    var link_url_data_ref: String?
}

struct WidgetTextNode: Codable {
    var string: String?
    var data_ref: String?
    var color_style: String? // default #ffffff
    var font_style: String? // https://developer.apple.com/fonts/system-fonts/ default San Francisco
    var size: Double? // default is 18
    var weight: String? // light, medium, bold, extra-bold, default medium
    var justification: String? // left, center, right, default center
    var min_scale_factor: Double? // default 1.0
}

struct WidgetImageNode: Codable {
    var data_ref: String?
    var url: String?
    var mask: String?
}

struct WidgetEntry: TimelineEntry {
    var date: Date = Date()
    var url: String = ""
    var widget_data: WidgetData = WidgetData()
    var widget_layout: String = ""
    var widget_user: String = ""
    var widget_password: String = ""
}

private struct SubscriptionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var hasPremiumSubscription: Bool {
        get { self[SubscriptionKey.self] }
        set { self[SubscriptionKey.self] = newValue }
    }
}




extension WidgetData {
    
    // For some reason these samples JSONs can't have \'s in them...
    static var sample = """
{
  "name": "Hello World",
  "description": "My first widget.json.",
  "data": {
    "content_url": "https://wd.gt/"
  },
  "layouts": {
    "hello_small": {
      "size": "small",
      "styles": {
        "colors": {
          "cool_purple": {
            "color": "#626DFF"
          }
        }
      },
      "layers": [
        {
          "rows": [
            {
              "height": 12,
              "cells": [
                {
                  "width": 12,
                  "background_color_style": "cool_purple",
                  "text": {
                    "string": "hello world"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  }
}
"""
    
    static var Sample = loadPreviewData(jsonString: sample)
    
    static private func loadPreviewData(jsonString: String) -> WidgetData  {
        
        var widget_data = WidgetData()
        do {
            
            if let jsonData = jsonString.data(using: .utf8) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                widget_data = try decoder.decode(self, from: jsonData)
                
                widget_data.id = "sample_id"
                
                return widget_data
            }
        } catch let error {
            widget_data.name = error.localizedDescription
        }
        return widget_data
    }
}

struct CollapsableTextView: View {
    let lineLimit: Int
    
    @State private var expanded: Bool = false
    @State private var showViewButton: Bool = false
    private var text: String
    
    init(_ text: String, lineLimit: Int) {
        self.text = text
        self.lineLimit = lineLimit
        
    }
    
    private var moreLessText: String {
        if showViewButton {
            return expanded ? "View Less" : "Read More"
            
        } else {
            return ""
            
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Text(text)
                    .font(.body)
                    .lineLimit(expanded ? nil : lineLimit)
                
                ScrollView(.vertical) {
                    Text(text)
                        .font(.body)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear {
                                        showViewButton = proxy.size.height > CGFloat(22 * lineLimit)
                                    }
                                    .onChange(of: text) { _ in
                                        showViewButton = proxy.size.height > CGFloat(22 * lineLimit)
                                    }
                            }
                        )
                    
                }
                .opacity(0.0)
                .disabled(true)
                .frame(height: 0.0)
            }
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        expanded.toggle()
                    }
                    showViewButton = false
                }, label: {
                    Text(moreLessText)
                        .font(.caption)
                        .foregroundColor(.blue)
                })
                .opacity(showViewButton ? 1.0 : 0.0)
                .disabled(!showViewButton)
                .frame(height: showViewButton ? nil : 0.0)
            }
        }
    }
}

struct BlurView: UIViewRepresentable {
    typealias UIViewType = UIVisualEffectView
    
    let style: UIBlurEffect.Style
    
    init(style: UIBlurEffect.Style = .systemMaterial) {
        self.style = style
    }
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: self.style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: self.style)
    }
}

struct CheckMarkAutoDismissModal: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color(.clear)
            VStack {
                Spacer()
                Image(systemName: "checkmark")
                    .resizable()
                    .frame(width:80, height: 80)
                    .foregroundColor(colorScheme == .dark ? .white : .gray)
                Spacer()
                Text("Widget Added")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .gray)
                Spacer()
            }
            
        }
        .frame(width:200, height: 200)
        .background(BlurView())
        .cornerRadius(20)
    }
}

struct CheckMarkAutoDismissModal_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CheckMarkAutoDismissModal()
        }
    }
}

func fetchProducts() async -> Product? {
    do {
        let productIdentifiers = ["pro"]
        let appProducts = try await Product.products(for: productIdentifiers)
        
        return appProducts.first
    } catch {
        return nil
    }
}

func TryBuyPremium() async {
    if let product = await fetchProducts() {
        if let purchase = try? await product.purchase() {
            if case let .success(result) = purchase {
                if case let .verified(transaction) = result {
                    DispatchQueue.main.async {
                        SubscriptionManager.sharedInstance.grantSubscription()
                    }
                    await transaction.finish()
                    return
                }
            }
        }
    }
}

func TryRestorePurchases() async {
    for await result in Transaction.currentEntitlements {
        if case let .verified(transaction) = result {
            DispatchQueue.main.async {
                SubscriptionManager.sharedInstance.grantSubscription()
            }
            await transaction.finish()
            return
        }
    }
}
