import UIKit

class KeyboardViewController: UIInputViewController {
    
    // MARK: - UI Elements
    private let recordButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Properties
    private var transcriptTimer: Timer?
    private var isRecording = false
    private var isWaitingForResponse = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🎯 ===== KEYBOARD EXTENSION VIEW DID LOAD =====")
        print("🎯 Timestamp: \(Date())")
        print("🎯 Thread: \(Thread.current)")
        print("🎯 Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Test app group access
        print("🔍 ===== TESTING APP GROUP ACCESS =====")
        if let defaults = sharedDefaults {
            print("✅ App group accessible in keyboard extension")
            print("🔍 App group ID: \(SharedKeys.appGroupID)")
            print("🔍 Current shared state: \(defaults.string(forKey: SharedKeys.state) ?? "nil")")
            print("🔍 Current transcript: \(defaults.string(forKey: SharedKeys.transcript) ?? "nil")")
            print("🔍 Current audio path: \(defaults.string(forKey: SharedKeys.audioPath) ?? "nil")")
            
            // Test writing to shared defaults
            let testKey = "keyboard_test_\(Date().timeIntervalSince1970)"
            let testValue = "keyboard_test_value"
            print("🔍 Testing write with key: \(testKey), value: \(testValue)")
            
            defaults.set(testValue, forKey: testKey)
            defaults.synchronize() // Force immediate save
            
            if let retrievedValue = defaults.string(forKey: testKey) {
                print("✅ App group write/read test successful: \(retrievedValue)")
            } else {
                print("❌ App group write/read test failed - could not retrieve written value")
            }
            
            // Clean up test data
            defaults.removeObject(forKey: testKey)
            defaults.synchronize()
            print("🔍 Test data cleaned up")
        } else {
            print("❌ ===== CRITICAL ERROR: APP GROUP NOT ACCESSIBLE =====")
            print("❌ App group ID: \(SharedKeys.appGroupID)")
            print("❌ This means:")
            print("❌ - Entitlements are not properly configured")
            print("❌ - App group ID mismatch between targets")
            print("❌ - Code signing issues")
            print("❌ - iOS security restrictions")
        }
        
        print("🎯 Setting up UI...")
        setupUI()
        print("🎯 UI setup complete")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPollingTranscript()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPollingTranscript()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        print("🎨 ===== SETTING UP KEYBOARD UI =====")
        print("🎨 View frame: \(view.frame)")
        print("🎨 View background color: \(view.backgroundColor?.description ?? "nil")")
        
        view.backgroundColor = .systemBackground
        
        // Record Button
        recordButton.setTitle("🎤", for: .normal)
        recordButton.titleLabel?.font = .systemFont(ofSize: 32)
        recordButton.backgroundColor = .systemBlue
        recordButton.tintColor = .white
        recordButton.layer.cornerRadius = 50
        recordButton.clipsToBounds = true
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tap gesture to toggle recording
        recordButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        
        view.addSubview(recordButton)
        
        // Status Label
        statusLabel.text = "Tap to Record"
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Activity Indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            recordButton.widthAnchor.constraint(equalToConstant: 100),
            recordButton.heightAnchor.constraint(equalToConstant: 100),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 15),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        print("🎨 UI constraints activated")
        print("🎨 Record button frame: \(recordButton.frame)")
        print("🎨 Status label frame: \(statusLabel.frame)")
        print("🎨 Activity indicator frame: \(activityIndicator.frame)")
        print("🎨 ===== KEYBOARD UI SETUP COMPLETE =====")
    }
    
    // MARK: - Toggle Recording
    @objc private func toggleRecording() {
        print("🎯 ===== TOGGLING RECORDING =====")
        print("🎯 Current recording state: \(isRecording)")
        print("🎯 Timestamp: \(Date())")
        
        if isRecording {
            // Stop recording
            stopRecordingFromKeyboard()
        } else {
            // Start recording
            startRecordingFromKeyboard()
        }
    }
    
    // MARK: - Start Recording from Keyboard
    private func startRecordingFromKeyboard() {
        print("🎯 ===== STARTING RECORDING FROM KEYBOARD =====")
        
        guard !isWaitingForResponse else {
            print("⚠️ Already waiting for response from main app")
            return
        }
        
        isWaitingForResponse = true
        
        // Create session ID for this recording
        let sessionId = UUID().uuidString
        print("🎯 Generated session ID: \(sessionId)")
        
        // Update UI to show we're opening main app
        updateUIForState("opening_app")
        
        // Store session ID in shared defaults
        if let defaults = sharedDefaults {
            defaults.set("requested", forKey: SharedKeys.state)
            defaults.set(sessionId, forKey: "recording_session_id")
            defaults.set(Date().timeIntervalSince1970, forKey: "recording_timestamp")
            defaults.synchronize()
            
            print("✅ Stored recording request in shared defaults")
            print("🎯 Session ID: \(sessionId)")
        }
        
        // Open main app with custom URL scheme
        openMainAppForRecording(sessionId: sessionId)
    }
    
    // MARK: - Open Main App for Recording
    private func openMainAppForRecording(sessionId: String) {
        print("🎯 ===== OPENING MAIN APP FOR RECORDING =====")
        
        // Create return URL for keyboard
        let returnURL = "vttkb-extension://return"
        let urlString = "vttkb://record?session=\(sessionId)&return=\(returnURL)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Failed to create URL for main app")
            isWaitingForResponse = false
            updateUIForState("error")
            return
        }
        
        print("🎯 Opening main app with URL: \(url)")
        
        // Open main app
        print("🎯 About to call extensionContext?.open with URL: \(url)")
        print("🎯 extensionContext is nil: \(extensionContext == nil)")
        
        if extensionContext == nil {
            print("❌ CRITICAL ERROR: extensionContext is nil")
            isWaitingForResponse = false
            updateUIForState("error")
            return
        }
        
        extensionContext?.open(url) { [weak self] success in
            print("🎯 Main app open result: \(success)")
            
            if success {
                print("✅ Main app opened successfully")
                // Start polling for completion after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.startPollingForCompletion()
                }
            } else {
                print("❌ Failed to open main app")
                self?.isWaitingForResponse = false
                self?.updateUIForState("error")
            }
        }
    }
    
    // MARK: - Stop Recording from Keyboard
    private func stopRecordingFromKeyboard() {
        print("🎯 ===== STOPPING RECORDING FROM KEYBOARD =====")
        
        // Send stop signal to main app
        if let defaults = sharedDefaults {
            defaults.set("stop_requested", forKey: SharedKeys.state)
            defaults.synchronize()
            print("✅ Sent stop request to main app")
            
            // Update UI to show we're stopping
            updateUIForState("stopping")
            
            // Start polling for completion
            startPollingForCompletion()
        } else {
            print("❌ Cannot communicate with main app")
            updateUIForState("error")
        }
    }
    
    private func useAppGroupCommunication() {
        print("🎯 ===== USING APP GROUP COMMUNICATION =====")
        
        // Set a flag in shared defaults to signal the main app
        if let defaults = sharedDefaults {
            let sessionId = UUID().uuidString
            let timestamp = Date().timeIntervalSince1970
            
            // Store the recording request in shared defaults
            defaults.set("requested", forKey: SharedKeys.state)
            defaults.set(sessionId, forKey: "recording_session_id")
            defaults.set(timestamp, forKey: "recording_timestamp")
            defaults.synchronize()
            
            print("✅ Stored recording request in shared defaults")
            print("🎯 Session ID: \(sessionId)")
            print("🎯 Timestamp: \(timestamp)")
            
            // Main app will detect this via UserDefaults polling
            print("🎯 Main app will detect recording request via UserDefaults polling")
            
            // Update UI to show we're waiting for main app
            DispatchQueue.main.async {
                self.updateUIForState("opening_app")
                self.statusLabel.text = "Requesting recording..."
            }
            
            // Start polling for response from main app
            self.startPollingForMainAppResponse()
        } else {
            print("❌ Cannot use app group communication - app group not accessible")
            DispatchQueue.main.async {
                self.updateUIForState("error")
                self.statusLabel.text = "Communication failed"
            }
        }
    }
    
    private func startPollingForMainAppResponse() {
        print("🎯 Starting to poll for main app response...")
        
        var timeoutCounter = 0
        
        // Create a timer to check for main app response
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            timeoutCounter += 1
            
            if let defaults = sharedDefaults {
                let state = defaults.string(forKey: SharedKeys.state)
                let transcript = defaults.string(forKey: SharedKeys.transcript)
                
                print("🔍 Polling main app response - State: \(state ?? "nil"), Transcript: \(transcript ?? "nil"), Attempt: \(timeoutCounter)")
                
                if state == "recording" {
                    print("✅ Main app started recording!")
                    timer.invalidate()
                    self.isWaitingForResponse = false
                    self.isRecording = true
                    DispatchQueue.main.async {
                        self.updateUIForState("recording")
                    }
                } else if state == "error" {
                    print("❌ Main app reported error")
                    timer.invalidate()
                    self.isWaitingForResponse = false
                    DispatchQueue.main.async {
                        self.updateUIForState("error")
                    }
                } else if state == "requested" {
                    print("🎯 Still waiting for main app to respond... (Attempt \(timeoutCounter))")
                    
                    if timeoutCounter > 20 { // 10 seconds timeout
                        print("❌ Timeout waiting for main app response")
                        timer.invalidate()
                        self.isWaitingForResponse = false
                        DispatchQueue.main.async {
                            self.updateUIForState("error")
                            self.statusLabel.text = "Main app not responding"
                        }
                    }
                }
            }
        }
    }
    
    private func startPollingForCompletion() {
        print("🎯 Starting to poll for completion...")
        
        var timeoutCounter = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            timeoutCounter += 1
            
            if let defaults = sharedDefaults {
                let state = defaults.string(forKey: SharedKeys.state)
                let transcript = defaults.string(forKey: SharedKeys.transcript)
                
                print("🔍 Polling for completion - State: \(state ?? "nil"), Transcript: \(transcript ?? "nil"), Attempt: \(timeoutCounter)")
                
                if let transcript = transcript, !transcript.isEmpty {
                    print("✅ Transcription completed!")
                    timer.invalidate()
                    self.isWaitingForResponse = false
                    DispatchQueue.main.async {
                        self.insertTranscript(transcript)
                        self.updateUIForState("completed")
                    }
                } else if state == "error" {
                    print("❌ Transcription failed")
                    timer.invalidate()
                    self.isWaitingForResponse = false
                    DispatchQueue.main.async {
                        self.updateUIForState("error")
                    }
                } else if state == "completed" {
                    print("🎯 Recording completed, waiting for transcript...")
                    // Continue polling for transcript
                } else if timeoutCounter > 60 { // 60 seconds timeout (user might be recording long audio)
                    print("❌ Timeout waiting for transcription")
                    timer.invalidate()
                    self.isWaitingForResponse = false
                    DispatchQueue.main.async {
                        self.updateUIForState("error")
                        self.statusLabel.text = "Transcription timeout"
                    }
                }
            }
        }
    }
    
    private func openCustomURL(_ url: URL) {
        print("🎯 ===== OPENING CUSTOM URL =====")
        print("🎯 About to call extensionContext?.open with URL: \(url)")
        print("🎯 extensionContext is nil: \(extensionContext == nil)")
        
        // Check if we can open the main app
        let mainAppURL = URL(string: "vttkb://")!
        print("🎯 Testing if main app is accessible with URL: \(mainAppURL)")
        
        if extensionContext == nil {
            print("❌ ===== CRITICAL ERROR: EXTENSION CONTEXT IS NIL =====")
            print("❌ This means the keyboard extension is not properly initialized")
            print("❌ Check if the extension is properly enabled in iOS Settings")
            print("❌ Check if the extension target is properly built and signed")
            DispatchQueue.main.async {
                self.updateUIForState("error")
                self.statusLabel.text = "Extension not initialized"
            }
            return
        }
        
        print("🎯 Extension context is available, proceeding with URL open...")
        
        // Check if main app is running by trying to write to shared defaults
        if let defaults = sharedDefaults {
            let testKey = "keyboard_test_main_app_\(Date().timeIntervalSince1970)"
            let testValue = "keyboard_test_main_app_value"
            defaults.set(testValue, forKey: testKey)
            defaults.synchronize()
            
            // Wait a moment and check if main app can read it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let retrievedValue = defaults.string(forKey: testKey) {
                    print("✅ Main app appears to be running - can read shared data")
                } else {
                    print("⚠️ Main app might not be running - cannot read shared data")
                }
                // Clean up test data
                defaults.removeObject(forKey: testKey)
                defaults.synchronize()
            }
        }
        
        extensionContext?.open(url, completionHandler: { [weak self] success in
            print("🎯 4. App open completion called with success: \(success)")
            print("🎯 Completion timestamp: \(Date())")
            print("🎯 Completion thread: \(Thread.current)")
            
            if !success {
                print("❌ ===== APP OPENING FAILED =====")
                print("❌ Failed to open containing app")
                print("❌ This usually means:")
                print("❌ - URL scheme not registered in main app")
                print("❌ - Main app not installed")
                print("❌ - URL format is incorrect")
                print("❌ - App not properly signed/installed")
                print("❌ - Main app crashed or is not responding")
                print("❌ - iOS security restrictions blocking the URL")
                print("❌ - Main app not running in background")
                
                // Try to get more diagnostic information
                if let defaults = sharedDefaults {
                    print("🔍 App group is accessible, checking for any error states...")
                    let currentState = defaults.string(forKey: SharedKeys.state) ?? "nil"
                    let currentTranscript = defaults.string(forKey: SharedKeys.transcript) ?? "nil"
                    print("🔍 Current shared state: \(currentState)")
                    print("🔍 Current transcript: \(currentTranscript)")
                } else {
                    print("❌ App group is NOT accessible - this is a critical issue")
                }
                
                DispatchQueue.main.async {
                    self?.updateUIForState("error")
                    self?.statusLabel.text = "Failed to open recording app"
                }
            } else {
                print("✅ Successfully opened containing app")
                print("✅ Main app should now be receiving the URL")
            }
        })
    }
    
    // MARK: - Polling for Transcript
    private func startPollingTranscript() {
        transcriptTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkTranscriptAndStatus()
        }
    }
    
    private func stopPollingTranscript() {
        transcriptTimer?.invalidate()
        transcriptTimer = nil
    }
    
    private func checkTranscriptAndStatus() {
        print("🔍 ===== CHECKING TRANSCRIPT AND STATUS =====")
        print("🔍 Timestamp: \(Date())")
        print("🔍 Polling interval: 0.5 seconds")
        
        // Check app group accessibility first
        guard let defaults = sharedDefaults else {
            print("❌ Cannot check transcript - app group not accessible")
            return
        }
        
        // Check for transcript
        let transcript = defaults.string(forKey: SharedKeys.transcript)
        if let transcript = transcript, !transcript.isEmpty {
            print("📝 Found transcript: \(transcript)")
            print("📝 Transcript length: \(transcript.count) characters")
            insertTranscript(transcript)
        } else {
            print("🔍 No transcript found or transcript is empty")
            print("🔍 Transcript value: \(transcript ?? "nil")")
        }
        
        // Check for status updates
        let state = defaults.string(forKey: SharedKeys.state)
        if let state = state {
            print("🔄 Status update: \(state)")
            print("🔄 Previous status: \(self.statusLabel.text ?? "nil")")
            updateUIForState(state)
        } else {
            print("🔍 No status found in shared defaults")
        }
        
        // Check if we should stop polling (when recording is complete)
        if let state = state,
           state == "completed" || state == "error" {
            print("🔄 Final state detected: \(state) - will stop polling soon")
            // Stop polling after a delay to ensure transcript is processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("⏹️ Stopping transcript polling due to final state: \(state)")
                self.stopPollingTranscript()
            }
        }
        
        // Log current UI state for debugging
        print("🔍 Current UI state:")
        print("🔍 - Button title: \(recordButton.title(for: .normal) ?? "nil")")
        print("🔍 - Button background color: \(recordButton.backgroundColor?.description ?? "nil")")
        print("🔍 - Status label text: \(statusLabel.text ?? "nil")")
        print("🔍 - Activity indicator animating: \(activityIndicator.isAnimating)")
    }
    
    // MARK: - UI State Management
    private func updateUIForState(_ state: String) {
        print("🎨 ===== UPDATING UI STATE =====")
        print("🎨 New state: \(state)")
        print("🎨 Current thread: \(Thread.current)")
        print("🎨 Previous button title: \(recordButton.title(for: .normal) ?? "nil")")
        print("🎨 Previous status text: \(statusLabel.text ?? "nil")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ Self is nil in updateUIForState")
                return
            }
            
            print("🎨 Executing UI update on main thread")
            
            switch state {
            case "opening_app":
                print("🎨 Setting UI to 'opening_app' state")
                self.recordButton.backgroundColor = .systemOrange
                self.recordButton.setTitle("⏳ Opening", for: .normal)
                self.statusLabel.text = "Opening recording app..."
                print("✅ UI updated to 'opening_app' state")
                
            case "starting":
                print("🎨 Setting UI to 'starting' state")
                self.recordButton.backgroundColor = .systemOrange
                self.recordButton.setTitle("⏳ Starting", for: .normal)
                self.statusLabel.text = "Starting recording..."
                self.activityIndicator.startAnimating()
                print("✅ UI updated to 'starting' state")
                
            case "requested":
                print("🎨 Setting UI to 'requested' state")
                self.recordButton.backgroundColor = .systemOrange
                self.recordButton.setTitle("⏳ Requesting", for: .normal)
                self.statusLabel.text = "Requesting recording..."
                print("✅ UI updated to 'requested' state")
                
            case "recording":
                print("🎨 Setting UI to 'recording' state")
                self.recordButton.backgroundColor = .systemRed
                self.recordButton.setTitle("⏹️ Recording", for: .normal)
                self.statusLabel.text = "Tap to Stop"
                self.activityIndicator.stopAnimating()
                print("✅ UI updated to 'recording' state")
                
            case "stopping":
                print("🎨 Setting UI to 'stopping' state")
                self.recordButton.backgroundColor = .systemOrange
                self.recordButton.setTitle("⏳ Stopping", for: .normal)
                self.statusLabel.text = "Stopping recording..."
                self.activityIndicator.startAnimating()
                print("✅ UI updated to 'stopping' state")
                
            case "processing":
                print("🎨 Setting UI to 'processing' state")
                self.recordButton.backgroundColor = .systemOrange
                self.recordButton.setTitle("⏳ Processing", for: .normal)
                self.statusLabel.text = "Transcribing audio..."
                self.activityIndicator.startAnimating()
                print("✅ UI updated to 'processing' state")
                
            case "completed":
                print("🎨 Setting UI to 'completed' state")
                self.recordButton.backgroundColor = .systemGreen
                self.recordButton.setTitle("✅ Done", for: .normal)
                self.statusLabel.text = "Transcription complete!"
                self.activityIndicator.stopAnimating()
                print("✅ UI updated to 'completed' state")
                
                // Reset after showing completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    print("🎨 Auto-resetting UI after completion")
                    self.resetUI()
                }
                
            case "error":
                print("🎨 Setting UI to 'error' state")
                self.recordButton.backgroundColor = .systemRed
                self.recordButton.setTitle("❌ Error", for: .normal)
                
                let errorMsg = sharedDefaults?.string(forKey: SharedKeys.transcript)
                if let errorMsg = errorMsg {
                    self.statusLabel.text = "Error: \(errorMsg)"
                    print("🎨 Error message from shared defaults: \(errorMsg)")
                } else {
                    self.statusLabel.text = "An error occurred"
                    print("🎨 No specific error message found")
                }
                
                self.activityIndicator.stopAnimating()
                print("✅ UI updated to 'error' state")
                
                // Reset after showing error
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    print("🎨 Auto-resetting UI after error")
                    self.resetUI()
                }
                
            case "idle":
                print("🎨 Setting UI to 'idle' state")
                self.recordButton.backgroundColor = .systemBlue
                self.recordButton.setTitle("🎤", for: .normal)
                self.statusLabel.text = "Tap to Record"
                self.activityIndicator.stopAnimating()
                print("✅ UI updated to 'idle' state")
                
            case "permission_denied":
                print("🎨 Setting UI to 'permission_denied' state")
                self.recordButton.backgroundColor = .systemOrange
                self.recordButton.setTitle("🔒 Denied", for: .normal)
                self.statusLabel.text = "Microphone access denied"
                print("✅ UI updated to 'permission_denied' state")
                
            default:
                print("⚠️ Unknown state: \(state)")
                break
            }
            
            print("🎨 Final UI state:")
            print("🎨 - Button title: \(self.recordButton.title(for: .normal) ?? "nil")")
            print("🎨 - Status text: \(self.statusLabel.text ?? "nil")")
            print("🎨 - Button background: \(self.recordButton.backgroundColor?.description ?? "nil")")
        }
    }
    
    private func resetUI() {
        print("🔄 ===== RESETTING UI =====")
        print("🔄 Previous button title: \(recordButton.title(for: .normal) ?? "nil")")
        print("🔄 Previous status text: \(statusLabel.text ?? "nil")")
        
        isRecording = false
        isWaitingForResponse = false
        
        recordButton.backgroundColor = .systemBlue
        recordButton.setTitle("🎤", for: .normal)
        statusLabel.text = "Tap to Record"
        activityIndicator.stopAnimating()
        
        // Clear shared state
        if let defaults = sharedDefaults {
            defaults.removeObject(forKey: SharedKeys.state)
            defaults.synchronize()
            print("✅ Cleared shared state")
        } else {
            print("❌ Could not clear shared state - app group not accessible")
        }
        
        print("✅ UI reset complete")
        print("🔄 Final button title: \(recordButton.title(for: .normal) ?? "nil")")
        print("🔄 Final status text: \(statusLabel.text ?? "nil")")
    }
    
    // MARK: - Text Insertion
    private func insertTranscript(_ transcript: String) {
        // Clear transcript so we don't insert again
        sharedDefaults?.removeObject(forKey: SharedKeys.transcript)
        
        // Insert the transcribed text at cursor position
        textDocumentProxy.insertText(transcript)
        
        // Show confirmation
        updateUIForState("completed")
        
        // Reset UI after showing confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.resetUI()
        }
    }
    
    // MARK: - Handle Return URL
    func handleReturnURL() {
        print("🎯 ===== HANDLING RETURN URL =====")
        
        // Check if we have a transcript ready
        if let defaults = sharedDefaults,
           let transcript = defaults.string(forKey: SharedKeys.transcript),
           !transcript.isEmpty {
            print("✅ Found transcript: \(transcript)")
            insertTranscript(transcript)
        } else {
            print("⚠️ No transcript found, checking state")
            if let defaults = sharedDefaults,
               let state = defaults.string(forKey: SharedKeys.state) {
                print("🔍 Current state: \(state)")
                updateUIForState(state)
            } else {
                print("🔍 No state found, resetting UI")
                resetUI()
            }
        }
    }
}