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
  private var currentFileName: String?

  override static func requiresMainQueueSetup() -> Bool { true }
  override func supportedEvents() -> [String]! { ["onSpeechResult", "onSpeechError", "onRecordingSaved"] }

  @objc func multiply(_ a: Double, b: Double, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    resolve(a * b)
  }

  private func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

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

    // Prepare file recording
    let fileName = "\(UUID().uuidString).wav"
    self.currentFileName = fileName
    let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
    self.audioFile = nil

    request.shouldReportPartialResults = true
    recognitionTask = recognizer?.recognitionTask(with: request) { result, error in

      switch (result, error) {
      case let (.some(result), _):
        self.sendEvent(withName: "onSpeechResult", body: [
          "text": result.bestTranscription.formattedString,
        ])
      case (_, .some):
        self.sendEvent(withName: "onSpeechError", body: error?.localizedDescription)
      case (.none, .none):
        fatalError("It should not be possible to have both a nil result and nil error.")
      }
//      if let result = result {
//        self.sendEvent(withName: "onSpeechResult", body: [
//          "text": result.bestTranscription.formattedString,
//        ])
//
//        if result.isFinal {
//          self.audioEngine.stop()
//          inputNode.removeTap(onBus: 0)
//          self.recognitionTask = nil
//          self.request = nil
//
//          if let name = self.currentFileName {
//            self.sendEvent(withName: "onRecordingSaved", body: [
//              "fileName": name,
//              "filePath": self.getDocumentsDirectory().appendingPathComponent(name).path
//            ])
//          }
//        }
//      } else {
//        if let error = error {
//          self.sendEvent(withName: "onSpeechError", body: error.localizedDescription)
//          self.audioEngine.stop()
//          inputNode.removeTap(onBus: 0)
//          self.recognitionTask = nil
//          self.request = nil
//          return
//        }
//      }
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

    if let name = currentFileName {
      self.sendEvent(withName: "onRecordingSaved", body: [
        "fileName": name,
        "filePath": self.getDocumentsDirectory().appendingPathComponent(name).path
      ])
    }
    self.audioFile = nil
    self.currentFileName = nil
  }

  @objc func playAudio(_ filePath: String,
                       resolve: @escaping RCTPromiseResolveBlock,
                       reject: @escaping RCTPromiseRejectBlock) {
    let url = URL(fileURLWithPath: filePath)

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true)

      let player = try AVAudioPlayer(contentsOf: url)
      player.play()

      // Wait for playback to finish
      DispatchQueue.global(qos: .background).async {
        while player.isPlaying {
          Thread.sleep(forTimeInterval: 0.1)
        }
        DispatchQueue.main.async {
          resolve("Playback completed")
        }
      }
    } catch {
      reject("E_PLAYBACK", "Failed to play audio: \(error.localizedDescription)", error)
    }
  }
}
