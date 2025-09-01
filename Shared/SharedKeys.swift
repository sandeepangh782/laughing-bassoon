
import Foundation

struct SharedKeys {
    static let appGroupID = "group.com.sandeepan.vttkeyboard"
    static let state = "recording_state"
    static let audioPath = "audio_file_path"
    static let transcript = "transcribed_text"
}

var sharedDefaults: UserDefaults? {
    let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
    
    // Debug: Check if app group is accessible
    if defaults == nil {
        print("⚠️ Warning: Could not access app group: \(SharedKeys.appGroupID)")
        print("Make sure both main app and extension have the same app group ID in entitlements")
    } else {
        print("✅ Successfully accessed app group: \(SharedKeys.appGroupID)")
    }
    
    return defaults
}

// MARK: - Debug Functions
func logAppGroupStatus() {
    print("🔍 Checking App Group Status...")
    
    if let defaults = sharedDefaults {
        print("✅ App Group accessible: \(SharedKeys.appGroupID)")
        
        // Test write
        let testKey = "debug_test_\(Date().timeIntervalSince1970)"
        let testValue = "test_value"
        defaults.set(testValue, forKey: testKey)
        
        // Test read
        if let retrievedValue = defaults.string(forKey: testKey) {
            print("✅ Read/Write test successful: \(retrievedValue)")
        } else {
            print("❌ Read test failed")
        }
        
        // Clean up
        defaults.removeObject(forKey: testKey)
        
        // Check current values
        print("📊 Current App Group contents:")
        for key in ["recording_state", "transcribed_text", "audio_file_path"] {
            if let value = defaults.string(forKey: key) {
                print("   \(key): \(value)")
            } else {
                print("   \(key): nil")
            }
        }
    } else {
        print("❌ App Group not accessible")
    }
}

// Helper function to test app group functionality
func testAppGroupAccess() {
    let testKey = "test_app_group_access"
    let testValue = "test_value_\(Date().timeIntervalSince1970)"
    
    if let defaults = sharedDefaults {
        defaults.set(testValue, forKey: testKey)
        let retrievedValue = defaults.string(forKey: testKey)
        
        if retrievedValue == testValue {
            print("✅ App group read/write test successful")
        } else {
            print("❌ App group read/write test failed")
        }
        
        // Clean up test data
        defaults.removeObject(forKey: testKey)
    } else {
        print("❌ Cannot test app group - sharedDefaults is nil")
    }
}


