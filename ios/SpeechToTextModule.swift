import AVFoundation
import Foundation
import React
import Speech

@objc(SpeechToText)
class SpeechToText: RCTEventEmitter {
  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var audioFile: AVAudioFile?
  private var finalTranscription: String = ""
  private var stopTimer: DispatchWorkItem?

  private var audioPlayer: AVAudioPlayer?

  override static func requiresMainQueueSetup() -> Bool { true }
  private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }
  
  override func supportedEvents() -> [String]! {
    ["onSpeechRecognitionResult", "onSpeechRecognitionError", "onSpeechRecognitionFinished", "playAudio", "stopAudio"]
  }

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
        do {
          try self.startSession(fileURLOverride: providedFileURL)
          resolve("Recording started")

          if autoStopSeconds > 0 {
            self.stopTimer?.cancel()
            let work = DispatchWorkItem { [weak self] in
              self?.stopSpeechRecognition()
            }
            self.stopTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + autoStopSeconds, execute: work)
          }
        } catch {
          reject("E_START", "Failed to start recognition: \(error.localizedDescription)", error)
        }
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
      case (.some(let result), _):
        self.sendEvent(
          withName: "onSpeechRecognitionResult",
          body: [
            "text": result.bestTranscription.formattedString,
            "isFinal": result.isFinal,
          ])
        self.finalTranscription = result.bestTranscription.formattedString
        if result.isFinal {
          self.finalTranscription = result.bestTranscription.formattedString
        }
      case (_, .some):
        self.sendEvent(withName: "onSpeechRecognitionError", body: ["error": error?.localizedDescription])
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
    // Cancel any pending auto-stop timer
    stopTimer?.cancel()
    stopTimer = nil

    // Stop and reset audio engine
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    // Remove tap if installed
    let inputNode = audioEngine.inputNode
    inputNode.removeTap(onBus: 0)
    audioEngine.reset()

    // End audio request and cancel recognition task
    request?.endAudio()
    recognitionTask?.finish()
    recognitionTask = nil
    request = nil

    DispatchQueue.main.async {
       do {
         let session = AVAudioSession.sharedInstance()
         try session.setCategory(.playback, mode: .default)
         try session.setActive(true)
       } catch {
         print("Error switching to playback session: \(error)")
       }
     }

    let audioLocalPath = audioFile?.url.path ?? ""
    audioFile = nil

    // Emit final result
    sendEvent(
      withName: "onSpeechRecognitionFinished",
      body: [
        "finalResult": finalTranscription,
        "audioLocalPath": audioLocalPath,
      ])

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.finalTranscription = ""
    }
  }

  @objc func playAudio(
    _ filePath: NSString,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    let url = URL(fileURLWithPath: filePath as String)

    DispatchQueue.main.async {
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        if let player = self.audioPlayer, player.isPlaying {
          player.stop()
        }

        self.audioPlayer = try AVAudioPlayer(contentsOf: url)
        self.audioPlayer?.prepareToPlay()
        self.audioPlayer?.play()

        resolve("Audio playback started")
      } catch {
        reject("E_PLAY", "Failed to play audio: \(error.localizedDescription)", error)
      }
    }
  }


  @objc func stopAudio(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if let player = audioPlayer, player.isPlaying {
      player.stop()
      audioPlayer = nil
      resolve("Audio playback stopped")
    }
  }
  
  deinit {
    audioEngine.stop()
    recognitionTask?.finish()
    audioPlayer?.stop()
  }
}
