import Foundation
import Speech
import AVFoundation
import React

@objc(SpeechToText)
class SpeechToText: RCTEventEmitter {
  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var audioFile: AVAudioFile?
  private var finalTranscription: String = ""

  override static func requiresMainQueueSetup() -> Bool { true }
  private func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }
  override func supportedEvents() -> [String]! { ["onSpeechResult", "onSpeechError", "onSpeechFinished"] }

  @objc func startRecording(_ resolve: @escaping RCTPromiseResolveBlock,
                            reject: @escaping RCTPromiseRejectBlock) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        reject("E_PERMISSION", "Speech recognition permission denied", nil)
        return
      }
      DispatchQueue.main.async {
        do {
          try self.startSession()
          resolve("Recording started")
        } catch {
          reject("E_START", "Failed to start", error)
        }
      }
    }
  }

  private func startSession() throws {
    // Configure audio session
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    request = SFSpeechAudioBufferRecognitionRequest()
    let inputNode = audioEngine.inputNode
    guard let request = request else { return }

    let fileName = "\(UUID().uuidString).wav"
    let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
    self.audioFile = nil

    request.shouldReportPartialResults = true
    recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
      switch (result, error) {
      case let (.some(result), _):
        self.sendEvent(withName: "onSpeechResult", body: [
          "text": result.bestTranscription.formattedString,
        ])
        self.finalTranscription = result.bestTranscription.formattedString
        if result.isFinal {
          self.finalTranscription = result.bestTranscription.formattedString
        }
      case (_, .some):
        self.sendEvent(withName: "onSpeechError", body: error?.localizedDescription)
      case (.none, .none):
        fatalError("It should not be possible to have both a nil result and nil error.")
      }
    }

    let format = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, _) in
      self.request?.append(buffer)
      do {
        if self.audioFile == nil {
          let settings = format.settings
          self.audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
          )
        }
        try self.audioFile?.write(from: buffer)
      } catch {
        print("Audio file write error: \(error)")
      }
    }

    audioEngine.prepare()
    try audioEngine.start()
  }

  @objc func stopRecording() {
    if audioEngine.isRunning {
        audioEngine.stop()
    }

    let inputNode = audioEngine.inputNode
    if inputNode.numberOfInputs > 0 {
        inputNode.removeTap(onBus: 0)
    }

    request?.endAudio()
    recognitionTask?.finish()
    recognitionTask = nil
    request = nil

    // Deactivate audio session
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print("Error deactivating audio session: \(error)")
    }
    // Get the audio file path before closing
    let audioLocalPath = audioFile?.url.path ?? ""
    audioFile = nil

    // Send event with final result and audio path
    sendEvent(withName: "onSpeechFinished", body: [
      "finalResult": finalTranscription,
      "audioLocalPath": audioLocalPath
    ])

    // Reset final transcription
    finalTranscription = ""

    // Deactivate audio session
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print("Error deactivating audio session: \(error)")
    }
  }
}
