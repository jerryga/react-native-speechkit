# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-XX

### Added

#### Core Features

- 🎤 Real-time speech recognition with partial results
- 📼 Automatic audio recording during speech recognition
- ▶️ Audio playback functionality
- 📱 Full iOS and Android support
- 🔒 Complete TypeScript type definitions

#### iOS Implementation

- Speech recognition using Apple's Speech framework
- Audio recording in WAV format
- Audio playback using AVAudioPlayer
- Automatic permission handling
- Event emission for speech results, errors, and recording saved

#### Android Implementation

- Speech recognition using Android's SpeechRecognizer API
- Audio recording in 3GP format using MediaRecorder
- Audio playback using MediaPlayer
- Runtime permission support
- Proper lifecycle management and resource cleanup

#### API

- `startRecording()` - Start speech recognition and audio recording
- `stopRecording()` - Stop recording and save audio file
- `playAudio(filePath)` - Play recorded audio files
- `addSpeechResultListener()` - Subscribe to speech results
- `addSpeechErrorListener()` - Subscribe to errors
- `addRecordingSavedListener()` - Subscribe to recording saved events

#### Documentation

- Comprehensive README with installation and usage instructions
- Detailed USAGE.md with advanced examples
- TypeScript type definitions
- Platform-specific notes and troubleshooting guide

### Platform Support

- iOS 10.0 and above
- Android API 21 (Android 5.0) and above

---

## Future Releases

### Planned Features

- [ ] Language selection support
- [ ] Custom vocabulary support
- [ ] Offline mode improvements
- [ ] Background recording support
- [ ] Audio format conversion
- [ ] Recording compression options
- [ ] Multiple language support
- [ ] Custom audio sample rate
- [ ] Pause/resume recording
- [ ] Voice activity detection

---

[1.0.0]: https://github.com/jerryga/react-native-speechkit/releases/tag/v1.0.0
