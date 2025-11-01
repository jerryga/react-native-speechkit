# react-native-speechkit

🎤 **A powerful React Native library for real-time speech recognition, audio recording, and playback on iOS and Android.**

[![npm version](https://img.shields.io/npm/v/react-native-speechkit.svg)](https://www.npmjs.com/package/react-native-speechkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ Features

- 🎙️ **Real-time Speech Recognition** (partial results)
- 📼 **Automatic Audio Recording** during recognition
- ▶️ **Audio Playback** of recorded files
- 📱 **Cross-Platform**: iOS & Android
- 🔒 **TypeScript**: Full type definitions
- ⚡ **Event-Driven**: Listen for results, errors, and recording events

---

## 🎬 Demo

<video src="./assets/example.MP4" controls style="max-width: 100%;"></video>

---

## 📦 Installation

```sh
npm install react-native-speechkit
# or
yarn add react-native-speechkit
```

### iOS Setup

1. Install CocoaPods:
   ```sh
   cd ios && pod install
   ```
2. Required permissions are already added to your `Info.plist`:
   - `NSMicrophoneUsageDescription`
   - `NSSpeechRecognitionUsageDescription`

### Android Setup

- The `RECORD_AUDIO` permission is already in `AndroidManifest.xml`.
- For Android 6.0+ you may need to request runtime permissions:

```js
import { PermissionsAndroid, Platform } from 'react-native';

async function requestMicrophonePermission() {
  if (Platform.OS === 'android') {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      {
        title: 'Microphone Permission',
        message:
          'This app needs access to your microphone for speech recognition.',
        buttonNeutral: 'Ask Me Later',
        buttonNegative: 'Cancel',
        buttonPositive: 'OK',
      }
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  }
  return true;
}
```

---

## 🚀 Usage

```js
import {
  startSpeechRecognition,
  stopSpeechRecognition,
  addSpeechResultListener,
  addSpeechErrorListener,
  addSpeechFinishedListener,
  playAudio,
} from 'react-native-speechkit';

// Start speech recognition (optionally pass fileURLString and autoStopAfter in ms)
await startSpeechRecognition();

// Listen for results (partial and final)
const resultSub = addSpeechResultListener(({ text, isFinal }) => {
  console.log('Transcribed:', text, 'Final:', isFinal);
});

// Listen for errors
const errorSub = addSpeechErrorListener(({ error }) => {
  console.error('Error:', error);
});

// Listen for finished event (final result and audio path)
const finishedSub = addSpeechFinishedListener(({ finalResult, audioLocalPath }) => {
  console.log('Final result:', finalResult, 'Audio file:', audioLocalPath);
  // Play the recorded audio
  if (audioLocalPath) {
    playAudio(audioLocalPath);
  }
});
### `playAudio(filePath: string): Promise<string>`

Play an audio file at the given path (local file or URL). Returns a promise that resolves when playback starts.

// Stop recognition
stopSpeechRecognition();

// Remove listeners when done
resultSub.remove();
errorSub.remove();
finishedSub.remove();
```

---

## 🧩 API Reference

### `startSpeechRecognition(fileURLString?: string | null, autoStopAfter?: number | null): Promise<string>`

Start speech recognition and audio recording. Optionally specify a file path and auto-stop duration (ms).

### `stopSpeechRecognition(): void`

Stop the current recognition session.

### `addSpeechResultListener(listener: (data: { text: string; isFinal: boolean }) => void)`

Subscribe to speech recognition results (partial and final). Returns a subscription with `.remove()`.

### `addSpeechErrorListener(listener: (data: { error: string }) => void)`

Subscribe to errors. Returns a subscription with `.remove()`.

### `addSpeechFinishedListener(listener: (data: { finalResult: string; audioLocalPath: string }) => void)`

Subscribe to the finished event, which provides the final recognized text and the local audio file path. Returns a subscription with `.remove()`.

---

## 📝 Example

```js
import { useState, useEffect } from 'react';
import { View, Button, Text } from 'react-native';
import {
  startSpeechRecognition,
  stopSpeechRecognition,
  addSpeechResultListener,
  addSpeechErrorListener,
  addSpeechFinishedListener,
  playAudio,
} from 'react-native-speechkit';

export default function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [text, setText] = useState('');
  const [audioPath, setAudioPath] = useState('');

  useEffect(() => {
    const resultSub = addSpeechResultListener(({ text, isFinal }) => {
      setText(text + (isFinal ? ' (final)' : ''));
    });
    const errorSub = addSpeechErrorListener(() => setIsRecording(false));
    const finishedSub = addSpeechFinishedListener(
      ({ finalResult, audioLocalPath }) => {
        setText(finalResult);
        setAudioPath(audioLocalPath);
        setIsRecording(false);
      }
    );
    return () => {
      resultSub.remove();
      errorSub.remove();
      finishedSub.remove();
    };
  }, []);

  return (
    <View>
      <Text>{text || 'No text yet'}</Text>
      <Text>{audioPath ? `Audio: ${audioPath}` : ''}</Text>
      <Button
        title={isRecording ? 'Stop' : 'Start'}
        onPress={
          isRecording
            ? () => {
                stopSpeechRecognition();
                setIsRecording(false);
              }
            : async () => {
                await startSpeechRecognition();
                setIsRecording(true);
              }
        }
      />
      {audioPath ? (
        <Button title="Play Audio" onPress={() => playAudio(audioPath)} />
      ) : null}
    </View>
  );
}
```

---

## 📱 Platform Notes

### iOS

- Requires iOS 10.0+
- Uses Apple's Speech framework
- Supports partial results
- Requires user permission for microphone & speech recognition

### Android

- Requires Android API 21+
- Uses Android's SpeechRecognizer
- Supports partial results
- Requires RECORD_AUDIO permission

---

## �️ Contributing

Contributions are welcome! Please read the [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 📄 License

MIT © [ChasonJia](https://github.com/jerryga)
