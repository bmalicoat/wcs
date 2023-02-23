//
//  widget.swift
//  widget
//
//  Created by BJ Malicoat on 9/6/22.
//

import CoreData
import WidgetKit
import SwiftUI

func getTimeline(widgetIntentData: WidgetIntentData?, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
    // Only show widgets that are still subscribed to and have this size layout chosen
    var widget: SubscribedWidget? = nil
    
    let subscribedWidgetFetch: NSFetchRequest<SubscribedWidget> = SubscribedWidget.fetchRequest()
    do {
        let subscribedWidgets = try PersistenceController.sharedInstance.container.viewContext.fetch(subscribedWidgetFetch)
        
        for subscribedWidget in subscribedWidgets {
            if subscribedWidget.id ?? "" == widgetIntentData?.identifier, subscribedWidget.size == widgetIntentData?.size {
                widget = subscribedWidget
            }
        }
    } catch let error {
        print("Error fetching subscribed widgets:", error)
    }
    
    var entries: [WidgetEntry] = []
    let currentDate = Date()
    let entryDate = Calendar.current.date(byAdding: .minute, value: Config.refreshIntervalInMinutes, to: currentDate)!
        
    if let widget = widget
    {
        fetchWidgetJSON(widget_id: widget.id ?? "", user: widget.user, password: widget.password, allowCachedData: false, cacheData: true, with: { widget_data, widget_error  in
            
            let entry = WidgetEntry(date: entryDate, url: widget.id ?? "", widget_data: widget_data ?? WidgetData(), widget_layout: widget.layout_id ?? "", widget_user: widget.user ?? "", widget_password: widget.password ?? "")
            
            entries.append(entry)
            
            // We want to return an entry here, even if it's default, so that the widget configuration text is shown.
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        })
    } else {
        // If we don't have a valid widget, break the widget
        let entry = WidgetEntry(date: entryDate, url: "", widget_data: WidgetData(), widget_layout: "", widget_user: "", widget_password: "")
        
        entries.append(entry)
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SmallProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry()
    }
    
    func getSnapshot(for configuration: SmallWidgetIntent, in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(WidgetEntry())
    }
    
    func getTimeline(for configuration: SmallWidgetIntent, in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        widgetExtension.getTimeline(widgetIntentData: configuration.WidgetIntentData, completion: completion)
    }
}

struct MediumProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry()
    }
    
    func getSnapshot(for configuration: MediumWidgetIntent, in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(WidgetEntry())
    }
    
    func getTimeline(for configuration: MediumWidgetIntent, in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        widgetExtension.getTimeline(widgetIntentData: configuration.WidgetIntentData, completion: completion)
    }
}

struct LargeProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry()
    }
    
    func getSnapshot(for configuration: LargeWidgetIntent, in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(WidgetEntry())
    }
    
    func getTimeline(for configuration: LargeWidgetIntent, in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        widgetExtension.getTimeline(widgetIntentData: configuration.WidgetIntentData, completion: completion)
    }
}

struct ExtraLargeProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry()
    }
    
    func getSnapshot(for configuration: ExtraLargeWidgetIntent, in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(WidgetEntry())
    }
    
    func getTimeline(for configuration: ExtraLargeWidgetIntent, in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        widgetExtension.getTimeline(widgetIntentData: configuration.WidgetIntentData, completion: completion)
    }
}

@main
struct WidgetPushWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        SmallWidget()
        MediumWidget()
        LargeWidget()
        ExtraLargeWidget()
    }
}

struct SmallWidget: Widget {
    let kind: String = "SmallWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: SmallWidgetIntent.self, provider: SmallProvider()) { entry in
            Small(data: entry)
        }
        .configurationDisplayName("Small Widget")
        .description("Configure to display any Small Widget.")
        .supportedFamilies([.systemSmall])
    }
}

struct Small: View {
    let data: WidgetEntry
    
    var body: some View {
        if !data.widget_layout.isEmpty {
            RenderWidgetView(widget_data: data.widget_data, layout_id: data.widget_layout, styles: data.widget_data.layouts[data.widget_layout]?.styles, in_app: false)
        }
        else {
            ZStack
            {
                LinearGradient(colors: [Color(hashCode: "#1961DF"),Color(hashCode: "#16B2EA")], startPoint: .bottom, endPoint: .top)
                
                ConstructionTape()
                    .frame(width:200, height: 10)
                    .rotationEffect(Angle(degrees: 45), anchor: .topTrailing)
                
                VStack {
                    Spacer()
                    Text("Configure")
                        .font(.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Text("Tap and hold and choose Edit Widget")
                        .font(.callout)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
            }
        }
    }
}

struct SmallWidget_Previews: PreviewProvider {
    static var previews: some View {
        let historical_entry = WidgetEntry(widget_data: WidgetData.Sample)
        Group {
            Small(data: historical_entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}

struct MediumWidget: Widget {
    let kind: String = "MediumWidget"
    
    var body: some WidgetConfiguration {
        
        IntentConfiguration(kind: kind, intent: MediumWidgetIntent.self, provider: MediumProvider()) { entry in
            Medium(data: entry)
        }
        .configurationDisplayName("Medium Widget")
        .description("Configure to display any Medium Widget.")
        .supportedFamilies([.systemMedium])
    }
}

struct Medium: View {
    let data: WidgetEntry
    
    var body: some View {
        if !data.widget_layout.isEmpty {
            RenderWidgetView(widget_data: data.widget_data, layout_id: data.widget_layout, styles: data.widget_data.layouts[data.widget_layout]?.styles, in_app: false)
        }
        else {
            ZStack
            {
                LinearGradient(colors: [Color(hashCode: "#1961DF"),Color(hashCode: "#16B2EA")], startPoint: .bottom, endPoint: .top)
                
                Group {
                    ConstructionTape()
                        .frame(width:200, height: 10)
                        .rotationEffect(Angle(degrees: 45), anchor: .topTrailing)
                }
                .padding(EdgeInsets(top: 0, leading: 200, bottom: 0, trailing: 0))
                
                VStack {
                    Spacer()
                    Text("Configure Widget")
                        .font(.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Text("Tap and hold and choose Edit Widget")
                        .font(.callout)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
            }
        }
    }
}

struct MediumWidget_Previews: PreviewProvider {
    static var previews: some View {
        let historical_entry = WidgetEntry(widget_data: WidgetData.Sample)
        Group {
            Medium(data: historical_entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}

struct LargeWidget: Widget {
    let kind: String = "LargeWidget"
    
    var body: some WidgetConfiguration {
        
        IntentConfiguration(kind: kind, intent: LargeWidgetIntent.self, provider: LargeProvider()) { entry in
            Large(data: entry)
        }
        .configurationDisplayName("Large Widget")
        .description("Configure to display any Large Widget.")
        .supportedFamilies([.systemLarge])
    }
}

struct Large: View {
    let data: WidgetEntry
    
    var body: some View {
        if !data.widget_layout.isEmpty {
            RenderWidgetView(widget_data: data.widget_data, layout_id: data.widget_layout, styles: data.widget_data.layouts[data.widget_layout]?.styles, in_app: false)
        }
        else {
            ZStack
            {
                LinearGradient(colors: [Color(hashCode: "#1961DF"),Color(hashCode: "#16B2EA")], startPoint: .bottom, endPoint: .top)
                
                Group {
                    ConstructionTape()
                        .frame(width:200, height: 10)
                        .rotationEffect(Angle(degrees: 45), anchor: .topTrailing)
                }
                .padding(EdgeInsets(top: -70, leading: 220, bottom: 0, trailing: 0))
                
                VStack {
                    Spacer()
                    Text("Configure Widget")
                        .font(.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Text("Tap and hold and choose Edit Widget")
                        .font(.callout)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
            }
        }
    }
}

struct LargeWidget_Previews: PreviewProvider {
    static var previews: some View {
        let historical_entry = WidgetEntry(widget_data: WidgetData.Sample)
        Group {
            Large(data: historical_entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}

struct ExtraLargeWidget: Widget {
    let kind: String = "ExtraLargeWidget"
    
    var body: some WidgetConfiguration {
        
        IntentConfiguration(kind: kind, intent: ExtraLargeWidgetIntent.self, provider: ExtraLargeProvider()) { entry in
            ExtraLarge(data: entry)
        }
        .configurationDisplayName("Extra Large Widget")
        .description("Configure to display any Extra Large Widget.")
        .supportedFamilies([.systemExtraLarge])
    }
}

struct ExtraLarge: View {
    let data: WidgetEntry
    
    var body: some View {
        if !data.widget_layout.isEmpty {
            RenderWidgetView(widget_data: data.widget_data, layout_id: data.widget_layout, styles: data.widget_data.layouts[data.widget_layout]?.styles, in_app: false)
        }
        else {
            ZStack
            {
                LinearGradient(colors: [Color(hashCode: "#1961DF"),Color(hashCode: "#16B2EA")], startPoint: .bottom, endPoint: .top)
                
                Group {
                    ConstructionTape()
                        .frame(width:200, height: 10)
                        .rotationEffect(Angle(degrees: 45), anchor: .topTrailing)
                }
                .padding(EdgeInsets(top: -70, leading: 640, bottom: 0, trailing: 0)) // This offset only works on iPad
                
                VStack {
                    Spacer()
                    Text("Configure Widget")
                        .font(.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Text("Tap and hold and choose Edit Widget")
                        .font(.callout)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
            }
        }
    }
}

struct ExtraLargeWidget_Previews: PreviewProvider {
    static var previews: some View {
        let historical_entry = WidgetEntry(widget_data: WidgetData.Sample)
        Group {
            ExtraLarge(data: historical_entry)
                .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
        }
    }
}

struct ConstructionTape: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let banner_width = 20.0
                
                path.addLines([
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: width, y: 0),
                    CGPoint(x: width, y: banner_width),
                    CGPoint(x: 0, y: banner_width),
                ])
            }
        }.foregroundColor(Color.black)
        HStack {
            ForEach(0..<3) { _ in
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let banner_width = 20.0
                        
                        
                        path.addLines([
                            CGPoint(x: 0, y: 0),
                            CGPoint(x: width/2, y: 0),
                            CGPoint(x: width, y: banner_width),
                            CGPoint(x: width/2, y: banner_width),
                        ])
                    }
                }
            }.foregroundColor(Color.yellow)
        }
    }
}
