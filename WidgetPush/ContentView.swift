//
//  ContentView.swift
//  WidgetPush
//
//  Created by BJ Malicoat on 9/6/22.
//

import CoreData
import SwiftUI
import WidgetKit

struct AddSheetView: View {
    @ObservedObject var passwordDialog: ObservablePasswordPrompt = ObservablePasswordPrompt.sharedInstance
    @Binding var widgetId: String
    @Binding var widgetUser: String
    @Binding var widgetPassword: String
    @Binding var showAddSheetView: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) var managedObjectContext
    
    enum FocusField: Hashable {
        case field
    }
    
    @FocusState private var focusedField: FocusField?
    
    @State var widgetIdText: String = ""
    @State var layoutId: String = ""
    @State var loading: Bool = false
    @State var errorText: String? = nil
    @State var userText: String = ""
    @State var passwordText: String = ""
    @State var widget: WidgetData? = nil
    @State var subscribedWidget: SubscribedWidget? = nil
    @State private var isPresentingConfirm: Bool = false
    
    @Environment(\.hasPremiumSubscription) var hasPremiumSubscription
    
    @FetchRequest(sortDescriptors: [SortDescriptor(\.id)]) var widgets: FetchedResults<SubscribedWidget>
    
    var body: some View {
        NavigationView {
            Group {
                VStack {
                    if let widget = widget {
                        ScrollView {
                            Text(widget.name)
                                .font(.title)
                                .padding()
                                .multilineTextAlignment(.center)
                            if let description = widget.description {
                                CollapsableTextView(description, lineLimit: 10)
                                    .padding()
                            }
                            
                            Carousel(widget_data: widget, selected_layout_id: "", layout_id: $layoutId)
                                .onAppear() {
                                    subscribedWidget = widgets.first(where: { $0.id == widget.id})
                                    
                                    if let subscribedWidget = subscribedWidget {
                                        layoutId = subscribedWidget.layout_id ?? widget.default_layout ?? widget.layouts.first?.key ?? ""
                                    } else {
                                        layoutId = widget.default_layout ?? widget.layouts.first?.key ?? ""
                                    }
                                }
                            
                            if subscribedWidget != nil {
                                Button(role: .destructive, action: {
                                    isPresentingConfirm = true
                                }) {
                                    Group {
                                        ZStack {
                                            Color(.systemRed)
                                            
                                            if loading {
                                                ProgressView()
                                                    .tint(.white)
                                            } else {
                                                Text("Remove Widget")
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .padding()
                                            }
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .frame(height: 55)
                                    .padding(EdgeInsets(top: 10, leading: 40, bottom: 0, trailing: 40))
                                }
                            } else {
                                Button(action: {
                                    addWidget()
                                }) {
                                    Group {
                                        ZStack {
                                            Color(.systemBlue)
                                            (
                                                Text(Image(systemName: "plus.circle.fill"))
                                                +
                                                Text(" Add Widget")
                                            )
                                            .bold()
                                            .foregroundColor(.white)
                                            .padding()
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .frame(height: 20)
                                    .padding(EdgeInsets(top: 30, leading: 40, bottom: 50, trailing: 40))
                                }
                            }
                        }
                    } else if (loading) {
                        ProgressView()
                            .padding()
                    } else {
                        VStack {
                            Text("Create live widgets for your favorite websites.")
                                .multilineTextAlignment(.center)
                                .fontWeight(.bold)
                                .font(.title)
                                .padding()
                                .frame(minHeight: 100)
                            
                            Group {
                                TextField("example.com/widget.json", text: $widgetIdText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding()
                                    .disableAutocorrection(true)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .field)
                                    .onAppear {
                                        self.focusedField = .field
                                    }
                                    .onSubmit {
                                        loadWidget(user: passwordText, password: passwordText)
                                    }
                                if let errorText = errorText, !passwordDialog.show {
                                    Text(errorText)
                                        .padding()
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            Text("[Learn More](https://wd.gt/?utm_source=wcs)")
                                .padding()
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                        .onAppear() {
                            // Check if we were passed in a widget id via deeplink
                            if (!widgetId.isEmpty) {
                                widgetIdText = widgetId
                                
                                if hasPremiumSubscription {
                                    userText = widgetUser
                                    passwordText = widgetPassword
                                }
                                
                                loadWidget(user: userText, password: passwordText)
                            }
                        }
                        .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if widget != nil {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close").bold()
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel").bold()
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if let widget = widget, let widget_url = widget.id {
                        ShareLink(item: URL(string: "widget://add_widget?url=" + widget_url)!)
                    }
                }
            }
        }
        .confirmationDialog("Are you sure?", isPresented: $isPresentingConfirm) {
            if let widget = widget {
                Button("Remove \(widget.name)", role: .destructive) {
                    dismiss()
                    if let widgetToDelete = subscribedWidget {
                        managedObjectContext.delete(widgetToDelete)
                        if let cached_data = getCachedWidget(id: widget.id ?? "") {
                            managedObjectContext.delete(cached_data)
                        }
                        PersistenceController.sharedInstance.save()
                        WidgetCenter.shared.reloadAllTimelines()
                        subscribedWidget = nil
                    }
                }
            }
        }
        .sheet(isPresented: $passwordDialog.show) {
            PasswordEntryView(userText: $userText, passwordText: $passwordText)
        }
        .onChange(of: passwordText) { _ in
            // If we got a new password, try it out.
            if (!passwordText.isEmpty) {
                loadWidget(user: userText, password: passwordText)
            }
        }
        .onDisappear() {
            if let subscribedWidget = subscribedWidget, let widget = widget {
                if subscribedWidget.layout_id != layoutId {
                    subscribedWidget.layout_id = layoutId
                    subscribedWidget.size = widget.layouts[layoutId]?.size
                    PersistenceController.sharedInstance.save()
                    
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            
            widgetId = ""
            widgetPassword = ""
            layoutId = ""
            passwordText = ""
            errorText = nil
            loading = false
        }
    }
    
    func loadWidget(user: String, password: String) {
        if loading { return }
        
        loading = true
        errorText = nil
        layoutId = ""
        
        widgetIdText = widgetIdText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Normalize widget url
        if var url = URL(string: widgetIdText) {
            if (url.scheme == "widget") {
                if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = urlComponents.queryItems {
                    
                    url = URL(string: queryItems.filter({$0.name == "url"}).first?.value?.removingPercentEncoding ?? "")!
                }
            }
            
            widgetIdText = url.absoluteString
        }
        
        widgetId = widgetIdText
        
        fetchWidgetJSON(widget_id: widgetIdText, user: user, password: password, allowCachedData: true, cacheData: false) { new_widget_data, widget_error  in
            // Clear widget and then say we're done loading
            widgetId = ""
            
            if (new_widget_data != nil) {
                widget = new_widget_data
            } else {
                passwordText = ""
                errorText = widget_error
            }
            
            loading = false
        }
    }
    
    func addWidget() {
        var shouldAdd = true
        
        if let widget = widget, let id = widget.id {
            for existing in widgets {
                if (existing.id == widget.id) {
                    shouldAdd = false
                    break
                }
            }
            
            if (shouldAdd) {
                let newWidget = SubscribedWidget(context: managedObjectContext)
                newWidget.id = id
                newWidget.user = userText
                newWidget.password = passwordText
                newWidget.layout_id = layoutId
                newWidget.size = widget.layouts[layoutId]?.size
                
                do {
                    let newCachedWidget = CachedWidget(context: managedObjectContext)
                    newCachedWidget.id = id
                    
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    newCachedWidget.data = String(bytes: try encoder.encode(widget), encoding: .utf8)
                } catch {
                    print("Failed to cache widget data")
                }
                
                PersistenceController.sharedInstance.save()
                
                DispatchQueue.main.async {
                    ObservableCheckmarkModal.sharedInstance.show = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    ObservableCheckmarkModal.sharedInstance.show = false
                }
            }
        }
        
        dismiss()
    }
}

struct AddSheetView_Previews: PreviewProvider {
    static var previews: some View {
        AddSheetView(widgetId: .constant("https://gist.githubusercontent.com/bmalicoat/bd42c3f2d320a237930cab3ec6684d1e/raw/hello_river_milk.json"), widgetUser: .constant(""), widgetPassword: .constant(""), showAddSheetView: .constant(true)).previewDisplayName("Add Widget With Widget")
        
        AddSheetView(widgetId: .constant(""), widgetUser: .constant(""), widgetPassword: .constant(""), showAddSheetView: .constant(true))
            .previewDisplayName("Add Widget Empty")
    }
}

struct PasswordEntryView: View {
    @Binding var userText: String
    @Binding var passwordText: String
    
    @State var tempUser: String = ""
    @State var tempPassword: String = ""
    
    @Environment(\.hasPremiumSubscription) var hasPremiumSubscription
    @Environment(\.dismiss) private var dismiss
    
    enum FocusField: Hashable {
        case user
        case password
    }
    
    @FocusState private var focusedField: FocusField?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    Text("Please enter the credentials for this private widget.")
                        .font(.headline).fontWeight(.light)
                        .padding(EdgeInsets(top: 30, leading: 50, bottom: 0, trailing: 50))
                        .multilineTextAlignment(.center)
                    TextField("Username", text: $tempUser)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .user)
                        .disabled(!hasPremiumSubscription)
                        .onAppear {
                            if hasPremiumSubscription {
                                self.focusedField = .user
                            }
                        }
                        .onSubmit {
                            self.focusedField = .password
                        }
                    SecureField("Password", text: $tempPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            userText = tempUser
                            passwordText = tempPassword
                            DispatchQueue.main.async {
                                ObservablePasswordPrompt.sharedInstance.show = false
                            }
                        }
                        .disabled(!hasPremiumSubscription)
                    
                    if !hasPremiumSubscription {
                        Text("To access private widgets, you need Widget Construction Set Pro.")
                            .multilineTextAlignment(.center)
                        Button(action: {
                            Task {
                                await TryBuyPremium()
                            }
                        }) {
                            Group {
                                ZStack {
                                    Color(.systemBlue)
                                    (
                                        Text("Unlock Pro")
                                    )
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding()
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .frame(height: 20)
                            .padding(EdgeInsets(top: 30, leading: 40, bottom: 0, trailing: 40))
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .navigationBarTitle(Text("Credentials"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                passwordText = ""
                DispatchQueue.main.async {
                    ObservablePasswordPrompt.sharedInstance.show = false
                }
            }) {
                Text("Cancel").bold()
            })
        }
    }
}

struct PasswordEntryView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordEntryView(userText: .constant(""), passwordText: .constant(""))
            .previewDisplayName("PasswordEntryView")
    }
}

struct SettingsView: View {
    @Binding var showSettingsView: Bool
    @State private var isPresentingConfirm = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hasPremiumSubscription) var hasPremiumSubscription
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Widget Construction Set puts your favorite web content right on your Home Screen.\n\nAdd any URL that serves a widget.json file.")
                    .padding()
                    .multilineTextAlignment(.center)
                Button(action: {
                    WidgetCenter.shared.reloadAllTimelines()
                }) {
                    Group {
                        ZStack {
                            Color(.systemBlue)
                            (
                                Text("Refresh Widgets")
                            )
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(height: 20)
                    .padding()
                }
                
                Button(action: {
                    UIApplication.shared.open(URL(string: "https://wd.gt/?utm_source=wcs")!, options: [:], completionHandler: nil)
                }) {
                    Group {
                        ZStack {
                            Color(.systemBlue)
                            (
                                Text("Need Help?")
                            )
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(height: 20)
                    .padding()
                }
                
                Button(action: {
                    isPresentingConfirm = true
                }) {
                    Group {
                        ZStack {
                            Color(.systemRed)
                            (
                                Text("Delete App Data")
                            )
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(height: 20)
                    .padding()
                }
                .confirmationDialog("Are you sure?", isPresented: $isPresentingConfirm) {
                    Button("Delete App Data", role: .destructive) {
                        PersistenceController.sharedInstance.deleteAllData()
                        
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                
                if !hasPremiumSubscription {
                    Spacer()
                    Text("Need access to private, password-protected widgets? Unlock Widget Construction Set Pro.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button(action: {
                        Task {
                            await TryBuyPremium()
                        }
                    }) {
                        Group {
                            ZStack {
                                Color(.systemBlue)
                                (
                                    Text("Unlock Pro")
                                )
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(height: 20)
                        .padding()
                    }
                }
                Text((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "")
                    .font(.caption2).fontWeight(.light)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 40, trailing: 0))
            }
            .navigationBarItems(trailing: Button(action: {
                dismiss()
            }) {
                Text("Close").bold()
            })
            .navigationBarTitle(Text("Settings"), displayMode: .inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showSettingsView: .constant(true))
    }
}

struct ContentView: View {
    @Binding var showAddSheetView: Bool
    @Binding var widgetId: String
    @Binding var widgetUser: String
    @Binding var widgetPassword: String
    @Binding var widgetDetailsWidgetData: SubscribedWidget?
    @ObservedObject var showCheckmarkModal: ObservableCheckmarkModal = ObservableCheckmarkModal.sharedInstance
    
    @FetchRequest(sortDescriptors: []) var subscriptions: FetchedResults<Subscription>
    
    var body: some View {
        ZStack {
            HomeScreenView(showAddSheetView: $showAddSheetView, widgetId: $widgetId, widgetUser: $widgetUser, widgetPassword: $widgetPassword, widgetDetailsWidgetData: $widgetDetailsWidgetData)
                .environment(\.hasPremiumSubscription, subscriptions.first?.premium ?? false)
            
            VStack {
                if showCheckmarkModal.show {
                    CheckMarkAutoDismissModal()
                }
            }
            .animation(.easeInOut)
        }
    }
}

struct HomeScreenView: View {
    @Binding var showAddSheetView: Bool
    @Binding var widgetId: String
    @Binding var widgetUser: String
    @Binding var widgetPassword: String
    @Binding var widgetDetailsWidgetData: SubscribedWidget?
    @State var showSettingsView: Bool = false
    @State var subscribedWidget: SubscribedWidget? = nil
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.hasPremiumSubscription) var hasPremiumSubscription
    
    // TODO: Should have a sort order ID
    @FetchRequest(sortDescriptors: [SortDescriptor(\.id)]) var widgets: FetchedResults<SubscribedWidget>
    
    var body: some View {
        NavigationStack {
            VStack {
                if (widgets.isEmpty) {
                    Spacer()
                    (
                        Text("Tap ")
                        +
                        Text(Image(systemName: "plus"))
                        +
                        Text(" to get started")
                    )
                    .foregroundColor(.gray)
                    
                    Spacer()
                } else {
                    Group {
                        List {
                            ForEach(widgets) { widget_data in
                                Button(action: {
                                    widgetId = widget_data.id ?? ""
                                    widgetUser = widget_data.user ?? ""
                                    widgetPassword = widget_data.password ?? ""
                                    showAddSheetView = true
                                    
                                }) {
                                    HStack {
                                        if let existingCachedWidget = getCachedWidget(id: widget_data.id), let jsonString = existingCachedWidget.data, let cached_data = convertDataToWidget(id: widget_data.id ?? "", data: Data(jsonString.utf8)), let cached_widget = cached_data.widget {
                                            RenderWidgetThumbnail(widget_data: cached_widget)
                                            VStack {
                                                Text((cached_widget.name))
                                                    .fontWeight(.bold)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Text((widget_data.size ?? "").replacingOccurrences(of: "_", with: " ").capitalized + " Widget")
                                                    .fontWeight(.light)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                                        } else {
                                            // TODO Show placeholder if we don't know what the data is...
                                            Text("Unknown Widget")
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: removeRows)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationBarItems(leading: Button(action: { showSettingsView = true }) { Image(systemName: "gearshape").frame(height: 96, alignment: .leading)}, trailing: Button(action: { showAddSheetView = true}) { Image(systemName: "plus")
                .frame(height: 96, alignment: .trailing)})
            .navigationBarTitle(Text("Widget Construction Set"), displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAddSheetView) {
            AddSheetView(widgetId: $widgetId, widgetUser: $widgetUser, widgetPassword: $widgetPassword, showAddSheetView: $showAddSheetView)
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView(showSettingsView: $showSettingsView)
        }
    }
    
    func removeRows(at offsets: IndexSet) {
        let widget = widgets[offsets[offsets.startIndex]]
        
        if let cached_data = getCachedWidget(id: widget.id) {
            managedObjectContext.delete(cached_data)
        }
        
        // Save off the ID because we are about to delete the whole widget reference
        let id = widget.id
        managedObjectContext.delete(widget)
        PersistenceController.sharedInstance.save()
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
