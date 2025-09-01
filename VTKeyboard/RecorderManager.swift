//
//  RecorderManager.swift
//  VTKeyboard
//
//  Created by sandeepan ghosh on 30/08/25.
//

import AVFoundation
import UIKit

class RecorderManager: NSObject, AVAudioRecorderDelegate {
    static let shared = RecorderManager()
    private var recorder: AVAudioRecorder?
    private var currentSessionId: String?
    private var isProcessingRequest = false // Prevent multiple simultaneous requests

    private func appGroupContainerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedKeys.appGroupID)
    }

    func startRecording(sessionId: String) throws {
        print("🎯 ===== RECORDERMANAGER: STARTING RECORDING =====")
        print("🎯 Session ID: \(sessionId)")
        
        // Prevent multiple simultaneous recording requests
        guard !isProcessingRequest else {
            print("⚠️ Recording request already in progress, ignoring duplicate")
            return
        }
        isProcessingRequest = true
        
        // Pre-create the audio file path and store it immediately
        if let container = appGroupContainerURL() {
            let dir = container.appendingPathComponent("recordings", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            let fileURL = dir.appendingPathComponent("\(sessionId).m4a")
            
            let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            defaults?.set(fileURL.path, forKey: SharedKeys.audioPath)
            print("✅ Pre-stored audio path: \(fileURL.path)")
        }
        
        // Request microphone permission with proper completion handling
        if #available(iOS 17.0, *) {
            print("🎯 iOS 17+ detected - using AVAudioApplication.requestRecordPermission")
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                print("🎯 Permission callback received: \(granted)")
                DispatchQueue.main.async {
                    self?.handlePermissionResult(granted: granted, sessionId: sessionId)
                }
            }
        } else {
            print("🎯 iOS 16 or earlier - using AVAudioSession.requestRecordPermission")
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                print("🎯 Permission callback received: \(granted)")
                DispatchQueue.main.async {
                    self?.handlePermissionResult(granted: granted, sessionId: sessionId)
                }
            }
        }
    }
    
    private func handlePermissionResult(granted: Bool, sessionId: String) {
        defer { isProcessingRequest = false }
        
        guard granted else {
            print("❌ Permission denied")
            let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            defaults?.set("permission_denied", forKey: SharedKeys.state)
            return
        }
        
        print("✅ Permission granted - calling setupAndStartRecording")
        do {
            try setupAndStartRecording(sessionId: sessionId)
        } catch {
            print("❌ Failed to setup recording: \(error.localizedDescription)")
            let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            defaults?.set("error", forKey: SharedKeys.state)
            defaults?.set("Setup failed: \(error.localizedDescription)", forKey: SharedKeys.transcript)
        }
    }
    
    private func setupAndStartRecording(sessionId: String) throws {
        print("🎯 ===== RECORDERMANAGER: SETUP AND START RECORDING =====")
        print("🎯 Session ID: \(sessionId)")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        // Step 1: Clean slate approach - completely reset audio session
        try resetAudioSession(audioSession)
        
        // Step 2: Configure and activate session with simplified approach
        try configureAndActivateSession(audioSession)
        
        // Step 3: Verify inputs are available
        try verifyAudioInputs(audioSession)
        
        // Step 4: Setup recorder
        try setupRecorder(sessionId: sessionId)
        
        // Step 5: Start recording
        try startActualRecording()
        
        // Step 6: Update state
        updateSuccessState(sessionId: sessionId)
        
        print("🎯 Recording started successfully for session: \(sessionId)")
    }
    
    private func resetAudioSession(_ audioSession: AVAudioSession) throws {
        print("🎯 Step 1: Resetting audio session...")
        
        // Stop any existing recorder first
        if let existingRecorder = recorder, existingRecorder.isRecording {
            existingRecorder.stop()
            recorder = nil
            print("✅ Stopped existing recorder")
        }
        
        // Reset audio session completely
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            print("✅ Deactivated audio session")
        } catch {
            print("⚠️ Could not deactivate session (might not be active): \(error.localizedDescription)")
            // This is often not a critical error
        }
        
        // Wait for system to process the deactivation
        Thread.sleep(forTimeInterval: 0.3)
    }
    
    private func configureAndActivateSession(_ audioSession: AVAudioSession) throws {
        print("🎯 Step 2: Configuring audio session...")
        
        // Use the most compatible configuration first
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        print("✅ Set audio category to .playAndRecord")
        
        // Activate with a simple, reliable approach
        var lastError: Error?
        var activationSuccessful = false
        
        // Try activation with exponential backoff
        let retryDelays: [TimeInterval] = [0.0, 0.1, 0.3, 0.5]
        
        for (attempt, delay) in retryDelays.enumerated() {
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
            
            print("🎯 Activation attempt \(attempt + 1)")
            
            do {
                try audioSession.setActive(true)
                activationSuccessful = true
                print("✅ Audio session activated successfully on attempt \(attempt + 1)")
                break
            } catch let error as NSError {
                lastError = error
                print("❌ Attempt \(attempt + 1) failed: \(error.localizedDescription) (Code: \(error.code))")
                
                // For certain errors, don't retry
                if error.code == Int(kAudioSessionNotInitialized) || error.code == Int(kAudioSessionBadPropertySizeError) {
                    print("❌ Non-recoverable error, stopping retries")
                    break
                }
            }
        }
        
        guard activationSuccessful else {
            throw lastError ?? NSError(domain: "RecorderManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to activate audio session after all attempts"])
        }
    }
    
    private func verifyAudioInputs(_ audioSession: AVAudioSession) throws {
        print("🎯 Step 3: Verifying audio inputs...")
        
        // Check current route
        let currentRoute = audioSession.currentRoute
        print("🔍 Current route: \(currentRoute.description)")
        print("🔍 Current inputs: \(currentRoute.inputs.count)")
        
        // If no inputs in current route, try to set up inputs
        if currentRoute.inputs.isEmpty {
            print("🎯 No inputs in route, attempting to configure...")
            
            // Check available inputs
            guard let availableInputs = audioSession.availableInputs, !availableInputs.isEmpty else {
                throw NSError(domain: "RecorderManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No microphone inputs available on this device"])
            }
            
            print("🔍 Available inputs: \(availableInputs.count)")
            for (index, input) in availableInputs.enumerated() {
                print("🔍 Input \(index): \(input.portType.rawValue) - \(input.portName)")
            }
            
            // Try to set the first available input as preferred
            let preferredInput = availableInputs[0]
            do {
                try audioSession.setPreferredInput(preferredInput)
                print("✅ Set preferred input: \(preferredInput.portName)")
                
                // Give the system time to update the route
                Thread.sleep(forTimeInterval: 0.2)
                
                // Check if this helped
                let updatedRoute = audioSession.currentRoute
                print("🔍 Updated route inputs: \(updatedRoute.inputs.count)")
                
                if updatedRoute.inputs.isEmpty {
                    print("⚠️ Still no inputs after setting preferred input")
                    
                    // Try deactivating and reactivating to refresh the route
                    try audioSession.setActive(false)
                    Thread.sleep(forTimeInterval: 0.2)
                    try audioSession.setActive(true)
                    
                    let finalRoute = audioSession.currentRoute
                    print("🔍 Final route inputs: \(finalRoute.inputs.count)")
                    
                    if finalRoute.inputs.isEmpty {
                        throw NSError(domain: "RecorderManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to activate microphone input. Please ensure no other app is using the microphone and try again."])
                    }
                }
            } catch {
                print("❌ Failed to set preferred input: \(error.localizedDescription)")
                throw NSError(domain: "RecorderManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to configure microphone input: \(error.localizedDescription)"])
            }
        }
        
        // Final verification
        guard audioSession.isInputAvailable else {
            throw NSError(domain: "RecorderManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Microphone input is not available"])
        }
        
        print("✅ Audio inputs verified successfully")
    }
    
    private func setupRecorder(sessionId: String) throws {
        print("🎯 Step 4: Setting up recorder...")
        
        guard let container = appGroupContainerURL() else { 
            throw NSError(domain: "Recorder", code: 6, userInfo: [NSLocalizedDescriptionKey: "App group container not accessible"])
        }
        
        let dir = container.appendingPathComponent("recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        
        let fileURL = dir.appendingPathComponent("\(sessionId).m4a")
        currentSessionId = sessionId
        
        // Remove any existing file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Removed existing audio file")
        }
        
        // Use reliable, compatible audio settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), // AAC is more universally supported than Apple Lossless
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 128000 // 128 kbps for good quality/size balance
        ]
        
        recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        
        print("✅ Recorder setup complete")
    }
    
    private func startActualRecording() throws {
        print("🎯 Step 5: Starting actual recording...")
        
        guard let recorder = recorder else {
            throw NSError(domain: "RecorderManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Recorder not initialized"])
        }
        
        // Prepare the recorder
        guard recorder.prepareToRecord() else {
            throw NSError(domain: "RecorderManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare recorder"])
        }
        print("✅ Recorder prepared successfully")
        
        // Start recording
        guard recorder.record() else {
            throw NSError(domain: "RecorderManager", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
        }
        
        print("✅ Recording started successfully")
    }
    
    private func updateSuccessState(sessionId: String) {
        print("🎯 Step 6: Updating success state...")
        
        guard let container = appGroupContainerURL() else { return }
        
        let dir = container.appendingPathComponent("recordings", isDirectory: true)
        let fileURL = dir.appendingPathComponent("\(sessionId).m4a")
        
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set("recording", forKey: SharedKeys.state)
        defaults?.set(fileURL.path, forKey: SharedKeys.audioPath)
        
        print("✅ Updated shared defaults with recording state")
    }

    func stopRecording() {
        print("🎯 ===== RECORDERMANAGER: STOPPING RECORDING =====")
        
        guard let recorder = recorder else {
            print("⚠️ No recorder instance found")
            let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            defaults?.set("stopped", forKey: SharedKeys.state)
            return
        }
        
        if recorder.isRecording {
            print("✅ Stopping active recording")
            recorder.stop()
        } else {
            print("⚠️ Recorder exists but is not recording")
        }
        
        self.recorder = nil
        currentSessionId = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("⚠️ Error deactivating audio session: \(error.localizedDescription)")
        }
        
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set("stopped", forKey: SharedKeys.state)
        print("✅ Recording stopped")
        
        // Verify the audio file exists
        verifyRecordedFile()
    }
    
    private func verifyRecordedFile() {
        guard let sessionId = currentSessionId,
              let container = appGroupContainerURL() else {
            print("⚠️ Cannot verify file - missing session ID or container")
            return
        }
        
        let dir = container.appendingPathComponent("recordings", isDirectory: true)
        let fileURL = dir.appendingPathComponent("\(sessionId).m4a")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("✅ Audio file exists at: \(fileURL.path)")
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? Int64 {
                    print("✅ Audio file size: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        print("⚠️ Audio file is empty")
                        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
                        defaults?.set("error", forKey: SharedKeys.state)
                        defaults?.set("Recording file is empty", forKey: SharedKeys.transcript)
                    }
                }
            } catch {
                print("⚠️ Could not get file attributes: \(error.localizedDescription)")
            }
        } else {
            print("❌ Audio file does not exist at expected path: \(fileURL.path)")
            let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
            defaults?.set("error", forKey: SharedKeys.state)
            defaults?.set("Audio file not found after recording", forKey: SharedKeys.transcript)
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎯 Recording finished, success: \(flag)")
        
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        if flag {
            print("✅ Recording completed successfully")
            defaults?.set("completed", forKey: SharedKeys.state)
        } else {
            print("❌ Recording failed")
            defaults?.set("failed", forKey: SharedKeys.state)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recording encode error: \(error?.localizedDescription ?? "unknown")")
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set("error", forKey: SharedKeys.state)
        defaults?.set("Encoding error: \(error?.localizedDescription ?? "unknown")", forKey: SharedKeys.transcript)
    }
}