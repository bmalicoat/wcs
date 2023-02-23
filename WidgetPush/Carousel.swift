//
//  Carousel.swift
//  WidgetPush
//
//  Created by BJ Malicoat on 9/29/22.
//

import SwiftUI

struct Carousel: View {
    let widget_data: WidgetData
    let selected_layout_id: String
    
    @Binding var layout_id: String
    
    @State private var snapPosition = 0.0
    @State private var dragPosition = 0.0
    
    var body: some View {
        ZStack {
            ForEach(Array((widget_data.layout_display_order ?? widget_data.layouts.map{$0.key}).enumerated()), id: \.offset) { (index: Int, layout: String) in
                ZStack {
                    // Gestures only happen on visible views (where alpha > 0).
                    // This is a hack for now because I don't know enough swift ui.
                    // ContentShape() should allegedly work, but I couldn't get it to.
                    Color(hashCode: "#00000001")
                    RenderWidgetPreview(widget_data: widget_data, layout_id: layout, inCarousel: true, selected: selected_layout_id == layout)
                        .scaleEffect(widget_data.layouts[layout]?.size == "large" ? 0.7 : 1.0)
                        .scaleEffect(widget_data.layouts[layout]?.size == "extra_large" ? 0.65 : 1.0)
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
                .scaleEffect(1.0 - abs(distance(index)) * 0.4 )
                .offset(x: -spacing(index), y: 0)
                .zIndex(1.0 - abs(distance(index)) * 0.6)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragPosition = snapPosition - value.translation.width / 200
                    
                    // Clamp the drag position
                    if (dragPosition > Double(widget_data.layouts.count) - 0.5) {
                        dragPosition = Double(widget_data.layouts.count) - 0.5
                    }
                    
                    if (dragPosition < -0.5) {
                        dragPosition = -0.5
                    }
                }
                .onEnded { value in
                    withAnimation {
                        dragPosition = snapPosition - value.predictedEndTranslation.width / 300
                        dragPosition = round(dragPosition)
                        
                        // Clamp the snapped position
                        if (dragPosition < 0) {
                            dragPosition = 0
                        }
                        
                        if (dragPosition >= Double(widget_data.layouts.count)) {
                            dragPosition = Double(widget_data.layouts.count-1)
                        }
                        
                        snapPosition = dragPosition
                        
                        updateCurrentItem()
                    }
                }
        )
        .onAppear() {
            scrollToItem(item: layout_id)
            updateCurrentItem()
        }
        .onChange(of: layout_id) { _ in
            scrollToItem(item: layout_id)
        }
    }
    
    func scrollToItem(item: String) {
        if (item == "") {
            return
        }
        
        while (getCurrentItem() != item) {
            dragPosition = dragPosition + 1.0
            
            // TODO: How to limit this if item isn't found?
            if (dragPosition > 1000.0)
            {
                break
            }
        }
        
        snapPosition = dragPosition
    }
    
    func getCurrentItem() -> String {
        var best_distance_index = 0
        var best_distance: Double = Double.greatestFiniteMagnitude
        
        let list = widget_data.layout_display_order ?? widget_data.layouts.map{$0.key}
            var item = ""
            
            for index in list.indices {
                if (abs(distance(index)) < best_distance) {
                    best_distance = abs(distance(index))
                    best_distance_index = index
                }
            }
            
            if (list.count > best_distance_index) {
                item = list[best_distance_index]
            }
        
        
        return item
    }
    
    func updateCurrentItem() {
        layout_id = getCurrentItem()
    }
    
    func distance(_ item: Int) -> Double {
        return (dragPosition - Double(item)).remainder(dividingBy: Double(widget_data.layouts.count * 5))
    }
    
    func spacing(_ item: Int) -> Double {
        return distance(item) * 200
    }
    
}
