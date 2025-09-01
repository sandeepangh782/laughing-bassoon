import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var buttonColor = Color.blue
    @State private var statusMessage = "Waiting for keyboard request..."
    @State private var currentSessionId: String?
    @State private var recordingStartTime: Date?
    @State private var shouldAutoRecord = false
    @State private var hasSetupObserver = false
    @State private var lastStatus = "idle"
    @State private var isProcessing = false
    
    // Timer for status updates - reduced frequency for better performance
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("VTKeyboard Companion")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Voice-to-Text Keyboard Extension")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Status Card
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundColor(statusIconColor)
                        
                        Text("Status")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(statusMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    if let sessionId = currentSessionId {
                        Text("Session: \(sessionId.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Background status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("App is running and listening for keyboard requests")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Main Recording Button
                VStack(spacing: 15) {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 50) { 
                            // Released - stop recording
                            if isRecording {
                                stopRecording()
                            }
                        } onPressingChanged: { isPressing in
                            // Started pressing - start recording
                            if isPressing && !isRecording {
                                startRecording()
                            }
                        }
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                    
                    Text(isRecording ? "Release to Stop" : "Hold to Record")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Recording Duration
                if isRecording, let startTime = recordingStartTime {
                    VStack(spacing: 8) {
                        Text("Recording Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(Date().timeIntervalSince(startTime)))s")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Instructions
                VStack(spacing: 12) {
                    Text("How to Use:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("1.")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("Switch to any app (Notes, Messages, etc.)")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("2.")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("Switch to VTKeyboard in your keyboard settings")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("3.")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("Tap the microphone button to start recording")
                                .font(.caption)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("4.")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("This app will automatically record and transcribe")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(20)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(16)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onReceive(timer) { _ in
            updateStatus()
        }
        .onAppear {
            updateStatus()
            print("🎯 ===== RECORDVIEW: VIEW APPEARED =====")
            
            // Only set up the observer once
            if !hasSetupObserver {
                print("🎯 Setting up notification observer for the first time")
                hasSetupObserver = true
                
                // Listen for start recording notification from AppDelegate
                NotificationCenter.default.addObserver(
                    forName: .startRecording,
                    object: nil,
                    queue: .main
                ) { notification in
                    print("🎯 ===== RECORDVIEW: NOTIFICATION RECEIVED =====")
                    print("🎯 Notification: \(notification)")
                    print("🎯 Object: \(notification.object ?? "nil")")
                    
                    if let sessionId = notification.object as? String {
                        print("✅ Session ID extracted: \(sessionId)")
                        currentSessionId = sessionId
                        shouldAutoRecord = true
                        print("✅ Set shouldAutoRecord to true")
                        
                        // Auto-start recording after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            print("🎯 Auto-starting recording from notification")
                            print("🎯 shouldAutoRecord: \(shouldAutoRecord)")
                            print("🎯 isRecording: \(isRecording)")
                            print("🎯 currentSessionId: \(currentSessionId ?? "nil")")
                            
                            if shouldAutoRecord && !isRecording {
                                print("🎯 Auto-starting recording...")
                                startRecording()
                            } else {
                                print("⚠️ Auto-record was cancelled - shouldAutoRecord: \(shouldAutoRecord), isRecording: \(isRecording)")
                            }
                        }
                    } else {
                        print("❌ Failed to extract session ID from notification")
                    }
                }
            }
        }
    }
    
    // Computed properties for status display
    private var statusIcon: String {
        switch lastStatus {
        case "idle": return "clock"
        case "requested": return "hourglass"
        case "recording": return "record.circle"
        case "processing": return "gear"
        case "completed": return "checkmark.circle"
        case "error": return "exclamationmark.triangle"
        case "permission_denied": return "lock"
        default: return "questionmark.circle"
        }
    }
    
    private var statusIconColor: Color {
        switch lastStatus {
        case "idle": return .gray
        case "requested": return .orange
        case "recording": return .red
        case "processing": return .orange
        case "completed": return .green
        case "error": return .red
        case "permission_denied": return .orange
        default: return .gray
        }
    }
    
    // MARK: - Recording functions
    func startRecording() {
        print("🎯 ===== RECORDVIEW: STARTING RECORDING =====")
        print("🎯 Current session ID: \(currentSessionId ?? "nil")")
        
        // Use the session ID from notification if available, otherwise create new one
        let sessionId = currentSessionId ?? UUID().uuidString
        currentSessionId = sessionId
        print("🎯 Using session ID: \(sessionId)")
        
        // Update shared state first
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set("recording", forKey: SharedKeys.state)
        print("✅ Updated shared state to 'recording'")
        
        // UI will be updated by the timer via updateUIState()
        
        do {
            print("🎯 Calling RecorderManager.startRecording...")
            try RecorderManager.shared.startRecording(sessionId: sessionId)
            print("✅ RecorderManager.startRecording called successfully")
        } catch {
            print("❌ Error starting recording: \(error)")
            let errorDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            errorDefaults?.set("error", forKey: SharedKeys.state)
            errorDefaults?.set("Error starting recording: \(error.localizedDescription)", forKey: SharedKeys.transcript)
        }
    }

    func stopRecording() {
        print("🎯 ===== RECORDVIEW: STOPPING RECORDING =====")
        shouldAutoRecord = false
        
        // First stop the recording
        RecorderManager.shared.stopRecording()
        
        // Update shared state to processing
        let processingDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        processingDefaults?.set("processing", forKey: SharedKeys.state)
        
        // Wait a short moment to ensure file is properly saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎯 Checking for audio file after delay")
            
            // Get the session ID
            let sessionId = self.currentSessionId ?? "unknown"
            print("🎯 Using session ID for transcription: \(sessionId)")
            
            // Try multiple approaches to find the audio file
            let audioDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            
            // First try: Get from shared defaults
            if let path = audioDefaults?.string(forKey: SharedKeys.audioPath) {
                print("✅ Found audio path in SharedKeys.audioPath: \(path)")
                self.startTranscription(path: path)
                return
            }
            
            print("⚠️ No audio path found in SharedKeys.audioPath, trying alternative methods")
            
            // Second try: Construct the path based on session ID
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedKeys.appGroupID) {
                let dir = container.appendingPathComponent("recordings", isDirectory: true)
                let fileURL = dir.appendingPathComponent("\(sessionId).m4a")
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    print("✅ Found audio file at constructed path: \(fileURL.path)")
                    
                    // Save the path for future reference
                    audioDefaults?.set(fileURL.path, forKey: SharedKeys.audioPath)
                    
                    self.startTranscription(path: fileURL.path)
                    return
                }
                
                print("⚠️ Audio file not found at constructed path: \(fileURL.path)")
            }
            
            // If we get here, we couldn't find the audio file
            print("❌ Could not find audio file through any method")
            self.statusMessage = "❌ No audio file found"
            let noAudioDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            noAudioDefaults?.set("error", forKey: SharedKeys.state)
            noAudioDefaults?.set("Could not locate audio recording file", forKey: SharedKeys.transcript)
        }
    }
    
    private func startTranscription(path: String) {
        print("🎯 Starting transcription with audio file: \(path)")
        TranscriptionClient.shared.uploadAudio(filePath: path)
    }
    
    // MARK: - Unified State Management
    private func updateUIState() {
        let statusDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        guard let state = statusDefaults?.string(forKey: SharedKeys.state) else { 
            setUIState(.idle)
            return 
        }
        
        // Only update if state actually changed
        if lastStatus != state {
            print("🔍 State transition: \(lastStatus) → \(state)")
            lastStatus = state
            
            // Map shared state to UI state
            switch state {
            case "idle":
                setUIState(.idle)
            case "requested":
                setUIState(.requested)
                // This state is now handled by notification from AppDelegate
            case "stop_requested":
                setUIState(.processing)
                // Stop recording when requested from keyboard
                handleKeyboardStopRequest()
            case "recording":
                setUIState(.recording)
            case "processing":
                setUIState(.processing)
            case "completed":
                setUIState(.completed)
            case "error":
                setUIState(.error)
            case "permission_denied":
                setUIState(.permissionDenied)
            default:
                setUIState(.idle)
            }
        }
    }
    
    // MARK: - Keyboard Recording Request Handler (Removed - now handled by notification)
    
    // MARK: - Keyboard Stop Request Handler
    private func handleKeyboardStopRequest() {
        print("🎯 ===== HANDLING KEYBOARD STOP REQUEST =====")
        
        if isRecording {
            print("✅ Stopping recording as requested by keyboard")
            stopRecording()
        } else {
            print("⚠️ Not currently recording, ignoring stop request")
            // Update state back to idle
            let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            defaults?.set("idle", forKey: SharedKeys.state)
        }
    }
    
    // MARK: - UI State Enum
    private enum UIState {
        case idle, requested, recording, processing, completed, error, permissionDenied
    }
    
    private func setUIState(_ state: UIState) {
        switch state {
        case .idle:
            isRecording = false
            isProcessing = false
            buttonColor = .blue
            statusMessage = "Waiting for keyboard request..."
            recordingStartTime = nil
            
        case .requested:
            isRecording = false
            isProcessing = false
            buttonColor = .orange
            statusMessage = "🎯 Keyboard requested recording - starting automatically..."
            
        case .recording:
            isRecording = true
            isProcessing = false
            buttonColor = .red
            statusMessage = "🎙️ Recording in progress... Release to stop"
            if recordingStartTime == nil {
                recordingStartTime = Date()
            }
            
        case .processing:
            isRecording = false
            isProcessing = true
            buttonColor = .orange
            statusMessage = "⚙️ Transcribing audio with AI..."
            recordingStartTime = nil
            
        case .completed:
            isRecording = false
            isProcessing = false
            buttonColor = .green
            statusMessage = "✅ Transcription complete! Text sent to keyboard"
            recordingStartTime = nil
            
            // Auto-reset after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                setUIState(.idle)
                let cleanupDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
                cleanupDefaults?.removeObject(forKey: SharedKeys.state)
            }
            
        case .error:
            isRecording = false
            isProcessing = false
            buttonColor = .orange
            let errorDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            if let errorMsg = errorDefaults?.string(forKey: SharedKeys.transcript) {
                statusMessage = "❌ Error: \(errorMsg)"
            } else {
                statusMessage = "❌ An error occurred during recording"
            }
            recordingStartTime = nil
            
            // Auto-reset after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                setUIState(.idle)
                let cleanupDefaults = UserDefaults(suiteName: SharedKeys.appGroupID)
                cleanupDefaults?.removeObject(forKey: SharedKeys.state)
            }
            
        case .permissionDenied:
            isRecording = false
            isProcessing = false
            buttonColor = .orange
            statusMessage = "🔒 Microphone permission denied. Please enable in Settings."
            recordingStartTime = nil
        }
    }
    
    // MARK: - Legacy updateStatus (simplified)
    private func updateStatus() {
        updateUIState()
    }
    }

