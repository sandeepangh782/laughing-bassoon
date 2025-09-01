import SwiftUI

@main
struct VTKeyboardApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RecordView() // your main recording screen
        }
    }
}

