import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    private var returnURL: URL?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Listen for return to previous app notification
        NotificationCenter.default.addObserver(
            forName: .returnToPreviousApp,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.returnToPreviousApp()
        }
        
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        print("🔗 ===== APP DELEGATE: URL RECEIVED =====")
        print("🔗 URL: \(url)")
        print("🔗 Scheme: \(url.scheme ?? "nil")")
        print("🔗 Host: \(url.host ?? "nil")")
        print("🔗 Query: \(url.query ?? "nil")")

        // Example: vttkb://record?session=<UUID>&return=<returnURL>
        if url.scheme == "vttkb", url.host == "record" {
            print("✅ URL scheme matches - processing record request")
            
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            print("🔗 Query items: \(queryItems?.description ?? "nil")")
            
            let sessionId = queryItems?.first(where: { $0.name == "session" })?.value ?? UUID().uuidString
            print("🔗 Session ID: \(sessionId)")
            
            // Store the return URL if provided
            if let returnURLString = queryItems?.first(where: { $0.name == "return" })?.value,
               let returnURL = URL(string: returnURLString) {
                self.returnURL = returnURL
                print("🔗 Return URL stored: \(returnURL)")
            } else {
                print("⚠️ No return URL found in query")
            }
            
            // Update shared state to indicate app opened
            sharedDefaults?.set("opening_app", forKey: SharedKeys.state)
            print("✅ Updated shared state to 'opening_app'")
            
            // Post notification to start recording
            NotificationCenter.default.post(name: .startRecording, object: sessionId)
            print("🔔 Posted startRecording notification with session: \(sessionId)")
        } else {
            print("❌ URL scheme does not match expected format")
        }

        return true
    }
    
    // MARK: - Return to Previous App
    func returnToPreviousApp() {
        guard let returnURL = returnURL else { return }
        
        // Clear the return URL
        self.returnURL = nil
        
        // Open the previous app
        if UIApplication.shared.canOpenURL(returnURL) {
            UIApplication.shared.open(returnURL, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
    static let returnToPreviousApp = Notification.Name("returnToPreviousApp")
}
