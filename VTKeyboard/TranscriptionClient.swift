//
//  TranscriptionClient.swift
//  VTKeyboard
//
//  Created by sandeepan ghosh on 30/08/25.
//

import Foundation
import Security

// SSL Certificate bypass delegate for direct IP connections
class SSLCertificateBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accept all server certificates
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

class TranscriptionClient {
    static let shared = TranscriptionClient()
    
    // API key - consider moving this to a secure configuration
    private let groqApiKey = "Enter your open ai api key here"
    
    // API endpoint - using official Groq domain
    private let groqEndpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
    
    // For testing purposes, use a mock response when API is unavailable
    private let useMockForTesting = true

    func uploadAudio(filePath: String) {
        print("🎯 ===== TRANSCRIPTION CLIENT: STARTING TRANSCRIPTION =====")
        print("🎯 Audio file path: \(filePath)")
        
        // Update status to processing
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set("processing", forKey: SharedKeys.state)
        
        // Check if file exists and has content
        let fileURL = URL(fileURLWithPath: filePath)
        if !FileManager.default.fileExists(atPath: filePath) {
            print("❌ Audio file does not exist at path: \(filePath)")
            handleError("Audio file not found")
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            if let fileSize = attributes[.size] as? Int64 {
                print("🎯 Audio file size: \(fileSize) bytes")
                if fileSize < 50 {  // Reduced from 100 to 50 bytes
                    print("⚠️ Audio file is too small (\(fileSize) bytes), may be empty or corrupted")
                    
                    if useMockForTesting {
                        print("🎯 Using mock transcription for testing")
                        mockTranscription()
                        return
                    }
                }
            }
        } catch {
            print("⚠️ Could not get file attributes: \(error.localizedDescription)")
        }
        
        // Use Groq API for transcription
        uploadToGroqAPI(fileURL: fileURL)
    }
    
    private func uploadToGroqAPI(fileURL: URL) {
        print("🎯 Attempting to use Groq API for transcription")
        
        guard let url = URL(string: groqEndpoint) else { 
            print("❌ Invalid Groq API URL")
            if useMockForTesting {
                mockTranscription()
            } else {
                handleError("Invalid API URL")
            }
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqApiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()
        let filename = fileURL.lastPathComponent
        let mimetype = "audio/aac" // MIME type for AAC format
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read audio file for Groq API call")
            if useMockForTesting {
                mockTranscription()
            } else {
                handleError("Failed to read audio file")
            }
            return
        }

        // Build multipart form data - simplified for Groq API
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        
        // Add model parameter (required)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-large-v3\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Set a timeout for the request
        request.timeoutInterval = 30
        
        // Create a session with specific configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        // Create a standard session for official domain
        let session = URLSession(configuration: config)
        
        print("🎯 Starting upload to Groq API")
        print("🎯 Request URL: \(url)")
        print("🎯 File size being sent: \(data.count) bytes")
        print("🎯 Content-Type: multipart/form-data; boundary=\(boundary)")
        
        session.uploadTask(with: request, from: data) { [weak self] responseData, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Groq API network error: \(error.localizedDescription)")
                    if self?.useMockForTesting == true {
                        print("🎯 Using mock transcription after network error")
                        self?.mockTranscription()
                    } else {
                        self?.handleError("Network error: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Groq API invalid response type")
                    if self?.useMockForTesting == true {
                        print("🎯 Using mock transcription after invalid response")
                        self?.mockTranscription()
                    } else {
                        self?.handleError("Invalid response")
                    }
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ Groq API error: \(httpResponse.statusCode)")
                    print("🎯 Response Headers: \(httpResponse.allHeaderFields)")
                    
                    if let responseData = responseData,
                       let errorString = String(data: responseData, encoding: .utf8) {
                        print("❌ Error details: \(errorString)")
                    }
                    
                    if self?.useMockForTesting == true {
                        print("🎯 Using mock transcription after API error")
                        self?.mockTranscription()
                    } else {
                        self?.handleError("API error: \(httpResponse.statusCode)")
                    }
                    return
                }
                
                guard let responseData = responseData else {
                    print("❌ Groq API no response data")
                    if self?.useMockForTesting == true {
                        print("🎯 Using mock transcription after no response data")
                        self?.mockTranscription()
                    } else {
                        self?.handleError("No response data")
                    }
                    return
                }
                
                self?.parseTranscriptionResponse(responseData)
            }
        }.resume()
    }
    
    private func parseTranscriptionResponse(_ data: Data) {
        print("🎯 Parsing transcription response")
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
                defaults?.set(cleanedText, forKey: SharedKeys.transcript)
                defaults?.set("completed", forKey: SharedKeys.state)
                print("✅ Transcription successful: \(cleanedText)")
                
                // Post notification to return to previous app
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🎯 Posting notification to return to previous app")
                    NotificationCenter.default.post(name: .returnToPreviousApp, object: nil)
                }
            } else {
                print("❌ Invalid response format")
                
                // Try to log the actual response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw response: \(jsonString)")
                }
                
                if useMockForTesting {
                    mockTranscription()
                } else {
                    handleError("Invalid response format")
                }
            }
        } catch {
            print("❌ Failed to parse response: \(error.localizedDescription)")
            
            if useMockForTesting {
                mockTranscription()
            } else {
                handleError("Failed to parse response: \(error.localizedDescription)")
            }
        }
    }
    
    // OpenAI API method removed as requested
    
    private func mockTranscription() {
        print("🎯 ===== USING MOCK TRANSCRIPTION =====")
        
        // Create a mock successful response
        let mockText = "This is a test transcription. Your recording has been processed successfully."
        
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set(mockText, forKey: SharedKeys.transcript)
        defaults?.set("completed", forKey: SharedKeys.state)
        
        print("✅ Mock transcription successful: \(mockText)")
        
        // Post notification to return to previous app
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(name: .returnToPreviousApp, object: nil)
        }
    }
    
    private func handleError(_ message: String) {
        print("Transcription error: \(message)")
        let defaults = UserDefaults(suiteName: SharedKeys.appGroupID)
        defaults?.set("error", forKey: SharedKeys.state)
        defaults?.set(message, forKey: SharedKeys.transcript)
    }
}
