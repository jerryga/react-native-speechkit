import AVFoundation
import Foundation
import React
import Speech

@objc(SpeechToText)
class SpeechToText: RCTEventEmitter {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine? = nil
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

        if #available(iOS 15.0, *) {
            Task {
                do {
                    try await self.requestSpeechPermissionAsync()
                    try self.startSession(fileURLOverride: providedFileURL)
                    resolve("Recording started")

                    if autoStopSeconds > 0 {
                        self.scheduleAutoStop(after: autoStopSeconds)
                    }
                } catch {
                    reject("E_START", "Failed to start recognition: \(error.localizedDescription)", error)
                }
            }
        } else {
            // Fallback for iOS < 15
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        reject("E_PERMISSION", "Speech recognition permission denied", nil)
                        return
                    }

                    do {
                        try self.startSession(fileURLOverride: providedFileURL)
                        resolve("Recording started")

                        if autoStopSeconds > 0 {
                            self.scheduleAutoStop(after: autoStopSeconds)
                        }
                    } catch {
                        reject("E_START", "Failed to start recognition: \(error.localizedDescription)", error)
                    }
                }
            }
        }
    }

    @available(iOS 15.0, *)
    private func requestSpeechPermissionAsync() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume()
                case .denied:
                    continuation.resume(throwing: NSError(domain: "Speech", code: 1,
                                                          userInfo: [NSLocalizedDescriptionKey: "Speech permission denied"]))
                case .restricted:
                    continuation.resume(throwing: NSError(domain: "Speech", code: 2,
                                                          userInfo: [NSLocalizedDescriptionKey: "Speech recognition restricted"]))
                case .notDetermined:
                    continuation.resume(throwing: NSError(domain: "Speech", code: 3,
                                                          userInfo: [NSLocalizedDescriptionKey: "Speech permission not determined"]))
                @unknown default:
                    continuation.resume(throwing: NSError(domain: "Speech", code: 999,
                                                          userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status"]))
                }
            }
        }
    }

    private func scheduleAutoStop(after seconds: Double) {
        stopTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.stopSpeechRecognition()
        }
        stopTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func startSession(fileURLOverride: URL?) throws {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setPreferredSampleRate(44100)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()

        self.audioEngine = AVAudioEngine()
        guard let audioEngine = self.audioEngine else {
          return
        }

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

        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { (buffer, _) in
            self.request?.append(buffer)
            do {
                if self.audioFile == nil {
                    // Initialize the file using the first buffer's actual format
                    self.audioFile = try AVAudioFile(
                        forWriting: resolvedFileURL,
                        settings: buffer.format.settings,
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
        if let audioEngine = self.audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            // Remove any existing tap safely
            let inputNode = audioEngine.inputNode
            if inputNode.numberOfInputs > 0 {
                inputNode.removeTap(onBus: 0)
            }
        }

        // End audio request and cancel recognition task
        request?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        request = nil
        audioEngine = nil
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
        audioEngine?.stop()
        audioEngine = nil

        recognitionTask?.finish()
        audioPlayer?.stop()
    }
}
