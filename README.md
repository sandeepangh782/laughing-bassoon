# 🎤 VTKeyboard - Voice-to-Text Keyboard Extension

A powerful iOS keyboard extension that converts speech to text using AI transcription, with a companion app for handling microphone permissions and audio processing.

## 🏗️ **Architecture Overview**

### 1. App Groups
- **App Group ID**: `group.com.sandeepan.vttkeyboard`
- **Purpose**: Enables data sharing between the main app and keyboard extension
- **Implementation**: Both targets have the same app group in their entitlements

### 2. URL Schemes
- **Main App**: `vttkb://` (e.g., `vttkb://record?session=UUID&return=URL`)
- **Keyboard Extension**: `vttkb-extension://` (for return handling)


VTKeyboard consists of two main components:

### 1. **Main App (VTKeyboard)**
- **Purpose**: Companion app that handles microphone permissions and audio recording
- **Features**: 
  - Microphone access management
  - Audio recording and processing
  - AI transcription via Groq API
  - Real-time status updates
  - Beautiful, intuitive UI

### 2. **Keyboard Extension (VTKeyboardExtension)**
- **Purpose**: iOS keyboard that users can switch to for voice input
- **Features**:
  - Microphone button for voice input
  - Seamless integration with any text field
  - Real-time status feedback
  - Automatic text insertion

## Key Components

### KeyboardViewController.swift
- **Location**: `VTKeyboardExtension/KeyboardViewController.swift`
- **Responsibilities**:
  - Display microphone button
  - Open main app for recording
  - Poll for transcript updates
  - Insert transcribed text into text field
  - Handle UI state changes

### RecordViewController.swift
- **Location**: `VTKeyboard/RecordViewController.swift`
- **Responsibilities**:
  - Listen for recording notifications
  - Handle audio recording
  - Manage recording UI states
  - Trigger transcription

### AppDelegate.swift
- **Location**: `VTKeyboard/AppDelegate.swift`
- **Responsibilities**:
  - Handle custom URL scheme
  - Manage app-to-app communication
  - Handle return to previous app

### TranscriptionClient.swift
- **Location**: `VTKeyboard/TranscriptionClient.swift`
- **Responsibilities**:
  - Upload audio to Groq API
  - Parse transcription response
  - Save transcript to shared storage
  - Trigger return to previous app

### SharedKeys.swift
- **Location**: `Shared/SharedKeys.swift`
- **Responsibilities**:
  - Define shared constants
  - Provide shared UserDefaults access
  - Include debug utilities


## 🔄 **How It Works**

```
1. User switches to VTKeyboard in any app
2. User taps microphone button in keyboard
3. Keyboard extension signals main app via App Group
4. Main app opens and automatically starts recording
5. Audio is transcribed using Groq AI
6. Transcribed text is sent back to keyboard
7. Text is automatically inserted into active field input cursor.
```

## 🚀 **Getting Started**

### **Prerequisites**
- Xcode 15.0+
- iOS 17.0+
- Apple Developer Account (for device testing)
- Groq API key

### **Installation**

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd VTKeyboard
   ```

2. **Open in Xcode**
   ```bash
   open VTKeyboard.xcodeproj
   ```

3. **Configure App Groups**
   - Select both targets (VTKeyboard and VTKeyboardExtension)
   - Go to Signing & Capabilities
   - Add App Groups capability
   - Use: `group.com.sandeepan.vttkeyboard`

4. **Add Groq API Key**
   - Open `TranscriptionClient.swift`
   - Replace `YOUR_GROQ_API_KEY` with your actual API key

5. **Build and Run**
   - First run the main app (VTKeyboard target)
   - Keep it running in the background
   - Switch to another app and enable VTKeyboard in keyboard settings

## 📱 **Usage Instructions**

### **Step 1: Enable the Keyboard**
1. Go to **Settings > General > Keyboard > Keyboards**
2. Tap **Add New Keyboard**
3. Select **VTKeyboard**
4. Tap **VTKeyboard** and enable **Allow Full Access**

### **Step 2: Use Voice Input**
1. **Switch to any app** (Notes, Messages, etc.)
2. **Tap any text field** to bring up the keyboard
3. **Switch to VTKeyboard** using the globe button
4. **Tap the microphone button** 🎤
5. **Speak clearly** - the main app will automatically record
6. **Wait for transcription** - text will appear automatically

## 🎨 **UI Features**

### **Main App (Companion)**
- **Status Card**: Real-time recording and transcription status
- **Visual Indicators**: Color-coded status with emojis
- **Session Tracking**: Unique session IDs for each recording
- **Background Status**: Clear indication that app is listening
- **Step-by-step Instructions**: Easy setup guide

### **Keyboard Extension**
- **Microphone Button**: Large, easy-to-tap recording button
- **Status Updates**: Visual feedback during recording process
- **Error Handling**: Clear error messages and recovery options

## 🔧 **Technical Details**

### **App Group Communication**
- **Shared Storage**: `UserDefaults` with App Group access
- **State Management**: Real-time status synchronization
- **Session Tracking**: Unique identifiers for each recording session

### **Audio Processing**
- **Format**: WAV audio files
- **Quality**: High-quality recording settings
- **Storage**: Temporary files with automatic cleanup

### **AI Transcription**
- **Provider**: Groq API (fast, accurate)
- **Language**: English (configurable)
- **Response Time**: Typically 1-3 seconds

## 🐛 **Troubleshooting**

### **Common Issues**

#### **"Main app not responding"**
- **Solution**: Make sure the main app is running
- **Steps**: Build and run VTKeyboard target first, keep it active

#### **"Microphone access denied"**
- **Solution**: Grant microphone permissions
- **Steps**: Go to Settings > Privacy > Microphone > VTKeyboard

#### **"App group not accessible"**
- **Solution**: Check App Groups configuration
- **Steps**: Verify both targets have the same App Group ID

#### **"Transcription failed"**
- **Solution**: Check Groq API key and internet connection
- **Steps**: Verify API key in TranscriptionClient.swift

### **Debug Logs**
Both components provide extensive logging:
- **Main App**: Look for `🔍 updateStatus:` messages
- **Keyboard Extension**: Look for `🎯` prefixed messages

## 📋 **Configuration**

### **App Group ID**
```swift
// In SharedKeys.swift
static let appGroupID = "group.com.sandeepan.vttkeyboard"
```

### **Groq API Key**
```swift
// In TranscriptionClient.swift
private let apiKey = "YOUR_GROQ_API_KEY"
```

### **Recording Settings**
```swift
// In RecorderManager.swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

## 🔒 **Security & Privacy**

- **Local Processing**: Audio files are stored locally and deleted after transcription
- **No Cloud Storage**: Audio is never uploaded to permanent storage
- **Secure Communication**: App Group communication is sandboxed
- **Permission Based**: Microphone access requires explicit user consent

