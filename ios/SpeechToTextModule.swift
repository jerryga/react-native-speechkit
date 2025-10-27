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
  private var stopTimer: DispatchWorkItem?

  override static func requiresMainQueueSetup() -> Bool { true }
  private func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }
  override func supportedEvents() -> [String]! { ["onSpeechRecognitionResult", "onSpeechRecognitionError", "onSpeechRecognitionFinished"] }

  @objc func startSpeechRecognition(
    _ fileURLString: NSString?,
    autoStopAfter: NSNumber?,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let providedFileURL: URL? = {
      guard let s = fileURLString as String?, !s.isEmpty else { return nil }
      if let url = URL(string: s), url.scheme != nil {
        return url
      } else {
        return URL(fileURLWithPath: s)
      }
    }()
    let autoStopSeconds: TimeInterval = autoStopAfter?.doubleValue ?? 0

    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        reject("E_PERMISSION", "Speech recognition permission denied", nil)
        return
      }
      DispatchQueue.main.async {
        let startWork = {
          do {
            try self.startSession(fileURLOverride: providedFileURL)
            resolve("Recording started")
            if autoStopSeconds > 0 {
              // Cancel any existing timer before scheduling a new one
              self.stopTimer?.cancel()
              let work = DispatchWorkItem { [weak self] in
                self?.stopSpeechRecognition()
              }
              self.stopTimer = work
              DispatchQueue.main.asyncAfter(deadline: .now() + autoStopSeconds, execute: work)
            }
          } catch {
            reject("E_START", "Failed to start", error)
          }
        }
        startWork()
      }
    }
  }

  private func startSession(fileURLOverride: URL?) throws {
    // Configure audio session
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    request = SFSpeechAudioBufferRecognitionRequest()
    let inputNode = audioEngine.inputNode
    guard let request = request else { return }

    let resolvedFileURL: URL = {
      if let override = fileURLOverride { return override }
      let fileName = "\(UUID().uuidString).wav"
      return getDocumentsDirectory().appendingPathComponent(fileName)
    }()

    self.audioFile = nil

    request.shouldReportPartialResults = true
    recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
      switch (result, error) {
      case let (.some(result), _):
        self.sendEvent(withName: "onSpeechRecognitionResult", body: [
          "text": result.bestTranscription.formattedString,
          "isFinal": result.isFinal,
        ])
        self.finalTranscription = result.bestTranscription.formattedString
        if result.isFinal {
          self.finalTranscription = result.bestTranscription.formattedString
        }
      case (_, .some):
        self.sendEvent(withName: "onSpeechRecognitionError", body: error?.localizedDescription)
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
            forWriting: resolvedFileURL,
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

  @objc func stopSpeechRecognition() {
    stopTimer?.cancel()
    stopTimer = nil

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

    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print("Error deactivating audio session: \(error)")
    }
    let audioLocalPath = audioFile?.url.path ?? ""
    audioFile = nil

    sendEvent(withName: "onSpeechRecognitionFinished", body: [
      "finalResult": finalTranscription,
      "audioLocalPath": audioLocalPath
    ])

    finalTranscription = ""

    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print("Error deactivating audio session: \(error)")
    }
  }
}

