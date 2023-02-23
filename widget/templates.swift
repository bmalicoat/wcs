//
//  templates.swift
//  widgetExtension
//
//  Created by BJ Malicoat on 9/19/22.
//

import Foundation
import SwiftUI
import WidgetKit

struct Constants {
    static let GRID_SIZE: Double = 12.0
}

struct RenderWidgetThumbnail: View {
    var widget_data: WidgetData
    var roundCorners: Bool = true
    
    @State var thumbnail_layout_name: String = ""
    
    var body: some View {
        RenderWidgetPreview(widget_data: widget_data, layout_id: thumbnail_layout_name, inCarousel: false, roundCorners: roundCorners)
            .frame(width: 85, height: 85)
            .scaleEffect(0.6)
            .onAppear() {
                thumbnail_layout_name = widget_data.thumbnail_layout ?? widget_data.layouts.first?.key ?? ""
                let thumbnail_layout = widget_data.layouts[thumbnail_layout_name]
                
                if let thumbnail_layout = thumbnail_layout {
                    if thumbnail_layout.size != "small" {
                        thumbnail_layout_name = ""
                    }
                } else {
                    thumbnail_layout_name = ""
                }
            }
    }
}

struct RenderWidgetPreview: View {
    let widget_data: WidgetData
    let layout_id: String
    let inCarousel: Bool
    var roundCorners: Bool = true
    var selected: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    // https://developer.apple.com/design/human-interface-guidelines/components/system-experiences/widgets/#platform-considerations
    func getSize(size: String?) -> (CGFloat, CGFloat) {
        var calculated_size: (CGFloat, CGFloat) = (141, 141)
        
        switch size {
        case .none:
            calculated_size = (141, 141)
        case .some("small"):
            calculated_size =  (141, 141)
        case .some("medium"):
            calculated_size =  (292, 141)
        case .some("large"):
            calculated_size =  (292, 311)
        case .some("extra_large"):
            calculated_size =  (634.5, 305.5)
        case .some(_):
            calculated_size =  (141, 141)
        }
        
        return calculated_size
    }
    
    var body: some View {
        let widget_size = getSize(size: widget_data.layouts[layout_id]?.size)
        let styles = widget_data.layouts[layout_id]?.styles ?? Styles()
        ZStack {
            ZStack {
                RenderWidgetView(widget_data: widget_data, layout_id: layout_id, styles: styles, in_app: true)
                    .frame(width: widget_size.0, height: widget_size.1)
                    .ifCondition(roundCorners) {
                        widget in
                        widget.clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .ifCondition(inCarousel) {
                        widget in
                        widget.shadow(color: Color(colorScheme == .dark ? UIColor(Color(hashCode: "#252525")) : UIColor.systemGray), radius: 20, x: -5, y: 10)
                    }
                
                if selected {
                    Color(.clear)
                        .frame(width: widget_size.0 + 20, height: widget_size.1 + 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [Color(hashCode: "#FEE179"), Color(hashCode: "#FEB500")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing), lineWidth: 8)
                        )
                }
            }
        }
    }
}

struct RenderWidgetView: View {
    let widget_data: WidgetData
    let layout_id: String
    let styles: Styles?
    let in_app: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let layout = widget_data.layouts[layout_id] {
                    ForEach(Array((layout.layers).enumerated()), id: \.offset) { (index: Int, layer: WidgetLayer) in
                        RenderWidgetLayer(id: widget_data.id ?? "", data: widget_data.data, styles: styles, layer: layer, width: geometry.size.width, height: geometry.size.height, in_app: in_app)
                    }
                } else {
                    // Couldn't render the widget...
                    ZStack {
                        Color(colorScheme == .dark ? .white : .black)
                        Color(colorScheme == .dark ? .black : .white)
                            .cornerRadius(8)
                            .padding(8)
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("?")
                                    .font(.system(size: 72))
                                    .fontWeight(.bold)
                                    .padding()
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
            }
            .ifCondition(widget_data.data["content_url"] != nil) { widget in
                widget.widgetURL(URL(string: String(format:"widget://launch_url?url=\(widget_data.data["content_url"]!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&id=\(widget_data.id?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))!)
            }
            
        }
    }
}

struct RenderWidgetLayer: View {
    let id: String
    let data: Dictionary<String, String>
    let styles: Styles?
    let layer: WidgetLayer
    let width: Double
    let height: Double
    let in_app: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if let rows = layer.rows {
                ForEach(Array(rows.enumerated()), id: \.offset) { (index: Int, row: WidgetRow) in
                    RenderWidgetRow(id: id, data: data, styles: styles, row: row, width: width, height: height, in_app: in_app)
                }
            }
        }
    }
}

struct RenderWidgetRow: View {
    let id: String
    let data: Dictionary<String, String>
    let styles: Styles?
    let row: WidgetRow
    let width: Double
    let height: Double
    let in_app: Bool
    
    var body: some View {
        
        let cell_height = CGFloat(row.height) * height / Constants.GRID_SIZE
        
        ZStack {
            if let cells = row.cells {
                ZStack{
                    HStack(spacing: 0) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { (index: Int, cell: WidgetCell) in
                            // If we are rendering a real widget (not in app) and
                            // it has a link on this cell, add it
                            if let link_url = data[cell.link_url_data_ref ?? ""], !in_app {
                                let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                let encodedLinkUrl = link_url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                Link(destination: URL(string: String(format:"widget://link_url?url=\(encodedLinkUrl)&id=\(encodedId)&index=\(index)"))!) {
                                    RenderWidgetCell(data: data, styles: styles, cell: cell, cell_height: cell_height, width: width, height: height, in_app: in_app)
                                }
                            } else {
                                RenderWidgetCell(data: data, styles: styles, cell: cell, cell_height: cell_height, width: width, height: height, in_app: in_app)
                            }
                        }
                    }
                }
            }
            //                        Text(String(row.height)).foregroundColor(.yellow) // DEBUG to visualize
        }
        .frame(height: cell_height )
        //                                .border(Color(hashCode: "#FF00FF")) // DEBUG to visualize
    }
}

struct RenderWidgetCell: View {
    let data: Dictionary<String, String>
    let styles: Styles?
    let cell: WidgetCell
    let cell_height: Double
    let width: Double
    let height: Double
    let in_app: Bool
    
    func getFontFamily(font_styles: Dictionary<String, WidgetFontStyle>?, font_style: String?) -> String? {
        var family: String? = nil
        
        if let font_style = font_style {
            family = (font_styles?[font_style]?.family)
        }
        
        return family
    }
    
    func getFontWeight(weight: String?) -> Font.Weight {
        var font_weight = Font.Weight.medium
        
        switch weight {
        case .some("light"):
            font_weight = Font.Weight.light
        case .some("medium"):
            font_weight = Font.Weight.medium
        case .some("bold"):
            font_weight = Font.Weight.bold
        case .some("extra_bold"):
            font_weight = Font.Weight.heavy
        case .none:
            font_weight = Font.Weight.medium
        case .some(_):
            font_weight = Font.Weight.medium
        }
        
        return font_weight
    }
    
    func getTextJustifications(justification: String?) -> TextAlignment {
        var text_alignment = TextAlignment.center
        
        switch justification {
        case .some("left"):
            text_alignment = TextAlignment.leading
        case .some("center"):
            text_alignment = TextAlignment.center
        case .some("right"):
            text_alignment = TextAlignment.trailing
        case .none:
            text_alignment = TextAlignment.center
        case .some(_):
            text_alignment = TextAlignment.center
        }
        
        return text_alignment
    }
    
    func getAlignment(justification: String?) -> Alignment {
        var alignment = Alignment.center
        
        switch justification {
        case .some("left"):
            alignment = Alignment.leading
        case .some("center"):
            alignment = Alignment.center
        case .some("right"):
            alignment = Alignment.trailing
        case .none:
            alignment = Alignment.center
        case .some(_):
            alignment = Alignment.center
        }
        
        return alignment
    }
    
    func getPadding(cell: WidgetCell, width: Double, height: Double) -> EdgeInsets {
        var padding = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        if let cellPadding = cell.padding {
            let distance = cellPadding * width / Constants.GRID_SIZE
            
            padding = EdgeInsets(top: distance, leading: distance, bottom: distance, trailing: distance)
        }
        
        return padding
    }
    
    var body: some View {
        let padding = getPadding(cell: cell, width: width, height: height)
        ZStack {
            
            if let color_style = cell.background_color_style {
                if let color = styles?.colors?[color_style]?.color {
                    if color.isGradient() {
                        RenderLinearGradient(linearGradientString: color)
                    } else {
                        Color(hashCode: color)
                    }
                }
            }
            
            Group {
                //                Color(.black) // DEBUG to visualize
                if let image = cell.image {
                    RenderWidgetImage(image: image, data: data, in_app: in_app)
                }
                
                if let text = cell.text, let textString = text.string ?? data[text.data_ref ?? ""] {
                    let font_size = text.size ?? 18
                    let font_weight = getFontWeight(weight: text.weight)
                    let alignment = getAlignment(justification: text.justification)
                    let multiline_alignment = getTextJustifications(justification: text.justification)
                    let color = (styles?.colors?[(text.color_style) ?? ""]?.color) ?? "#FFFFFF"
                    let family = getFontFamily(font_styles: styles?.fonts, font_style: text.font_style)
                    
                    Group {
                        if color.isGradient(), let params = parseGradientString(linearGradientString: color) {
                            Text(textString)
                                .gradientForeground(linearGradientParams: params)
                        } else {
                            Text(textString)
                                .foregroundColor(Color(hashCode: color))
                        }
                    }
                    .ifCondition(family != nil) { text in
                        text.font(.custom(family!, fixedSize: font_size))
                    } else: {  text in
                        text.font(.system(size: font_size))
                    }
                    .fontWeight(font_weight)
                    .minimumScaleFactor(CGFloat(text.min_scale_factor ?? 1.0))
                    .lineLimit(1000) // Without a line limit, text won't scale down (???)
                    .frame(maxWidth: .infinity, alignment: alignment)
                    .multilineTextAlignment(multiline_alignment)
                }
            }
            .padding(padding)
            //                        Text(String(cell.width)).foregroundColor(.yellow) // DEBUG to visualize
        }
        .frame(width: (CGFloat(cell.width) * width / Constants.GRID_SIZE), height: cell_height)
        .clipped()
        //                                        .border(Color(hashCode: "#FF00FF")) // DEBUG to visualize
    }
}

struct AnyShape: Shape {
    init<S: Shape>(_ wrapped: S) {
        _path = { rect in
            let path = wrapped.path(in: rect)
            return path
        }
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
    
    private let _path: (CGRect) -> Path
}

struct RenderWidgetImage: View {
    let image: WidgetImageNode
    let data: Dictionary<String, String>
    let in_app: Bool
    
    func getClipShape(mask: String?) -> some Shape {
        var shape = AnyShape(Rectangle())
        
        switch mask {
        case .some("circle"):
            shape = AnyShape(Circle())
        case .none:
            shape = AnyShape(Rectangle())
        case .some(_):
            shape = AnyShape(Rectangle())
        }
        
        return shape
    }
    
    var body: some View {
        // Widgets can't use AsyncImage, so we'll use it in the app
        // and manually fetch outside of the app
        if let image_url = image.url ?? data[image.data_ref ?? ""] {
            if (in_app) {
                AsyncImage(url: URL(string: image_url), content: { img in
                    img
                        .resizable()
                        .scaledToFill()
                        .clipShape(getClipShape(mask: image.mask))
                }, placeholder: {
                    ProgressView()
                })
            } else {
                if let url = URL(string: image_url),
                   let imageData = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .clipShape(getClipShape(mask: image.mask))
                }
            }
        }
    }
}

public struct LinearGradientParams {
    let first: Color
    let second: Color
    let startPoint: UnitPoint
    let endPoint: UnitPoint
}

func parseGradientString(linearGradientString: String?) -> LinearGradientParams? {
    // TODO: replace with regex
    //"linear-gradient(45deg, #FF0000, #00FF00)"
    var params: LinearGradientParams? = nil
    
    if let linearGradientString = linearGradientString {
        
        let parts = linearGradientString.split(separator: "(")
        
        if parts.count == 2 {
            var inner = parts[1]
            inner.removeLast()
            let values = inner.split(separator: ",")
            
            if values.count == 3 {
                let degrees = Double(values[0].split(separator: "deg")[0]) ?? 0.0
                let firstColor = values[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let secondColor = values[2].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                var opposite = degrees - 180
                if (degrees < 180) {
                    opposite = degrees + 180
                }
                
                params = LinearGradientParams(first: Color(hashCode: firstColor), second: Color(hashCode: secondColor), startPoint: degreesToUnitPoint(degrees: degrees) , endPoint: degreesToUnitPoint(degrees: opposite))
            }
        }
    }
    
    return params
}

func degreesToUnitPoint(degrees: Double) -> UnitPoint {
    
    // normalize angle to be 0-360
    let degrees =  degrees.truncatingRemainder(dividingBy: 360)
    
    // map angle to 1 of 8 slots with an angle of 0-45 per slot because tangent is discontinuous
    let offset = floor(degrees.truncatingRemainder(dividingBy: 45))
    let slot = floor(degrees / 45)
    
    let tangent = tan(offset * .pi / 180.0)
    
    var point = UnitPoint(x: 1, y: 1)
    
    // map angle to square going from -1, 1 upper left to 1, -1 lower right with 0 degrees at 3 o'clock (like a unit circle where the points are (cos(theta), sin(theta))
    switch slot {
    case 0:
        point.x = 1
        point.y = tangent
    case 1:
        point.x = 1 - tangent
        point.y = 1
    case 2:
        point.x = -tangent
        point.y = 1
    case 3:
        point.x = -1
        point.y = 1 - tangent
    case 4:
        point.x = -1
        point.y = -tangent
    case 5:
        point.x = -1 + tangent
        point.y = -1
    case 6:
        point.x = tangent
        point.y = -1
    case 7:
        point.x = 1
        point.y = -1 + tangent
    default:
        break
    }
    
    // Now map to the space of UnitPoint where 0,0 is upper left and 1,1 is lower right
    point.y = -point.y
    
    point.x = (point.x + 1) / 2
    point.y = (point.y + 1) / 2
    
    // 0 degrees in css gradient is at 6 o'clock rather than our 3 o'clock start point. Css also measures degrees clockwise while we did the more traditional sin/cos anticlockwise. These two facts combined mean we can just swizzle x and y to mirror across the diagonal going from upper left to lower right which is equivalent to translated the start location and switching the rotation.
    let temp = point.x
    point.x = point.y
    point.y = temp
    
    return point
}

struct RenderLinearGradient: View {
    let linearGradientString: String?
    
    func generateGradient(linearGradientParams: LinearGradientParams) -> LinearGradient {
        
        return LinearGradient(colors: [linearGradientParams.first, linearGradientParams.second], startPoint: linearGradientParams.startPoint, endPoint: linearGradientParams.endPoint)
    }
    
    var body: some View {
        let params: LinearGradientParams? = parseGradientString(linearGradientString: linearGradientString)
        
        if let params = params {
            generateGradient(linearGradientParams: params)
        }
    }
}

extension View {
    public func gradientForeground(linearGradientParams: LinearGradientParams) -> some View {
        self.overlay(
            LinearGradient(
                colors: [linearGradientParams.first, linearGradientParams.second],
                startPoint: linearGradientParams.startPoint,
                endPoint: linearGradientParams.endPoint)
        )
        .mask(self)
    }
    
    @ViewBuilder
    func ifCondition<TrueContent: View, FalseContent: View>(_ condition: Bool, then trueContent: (Self) -> TrueContent, else falseContent: (Self) -> FalseContent) -> some View {
        if condition {
            trueContent(self)
        } else {
            falseContent(self)
        }
    }
    
    @ViewBuilder
    func ifCondition<TrueContent: View>(_ condition: Bool, then trueContent: (Self) -> TrueContent) -> some View {
        if condition {
            trueContent(self)
        } else {
            self
        }
    }
    
}

struct RenderWidgetView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        Group {
            
            RenderWidgetPreview(widget_data: WidgetData.Sample, layout_id: "hello_small", inCarousel: true)
                .previewDisplayName("Hello World")
            
            RenderWidgetPreview(widget_data: WidgetData.Sample, layout_id: "missing", inCarousel: true)
                .previewDisplayName("Missing WIdget")
            
        }
    }
}
