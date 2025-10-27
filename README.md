# react-native-speech-to-text

🎤 **A powerful React Native library for real-time speech recognition, audio recording, and playback on iOS and Android.**

[![npm version](https://img.shields.io/npm/v/react-native-speech-to-text.svg)](https://www.npmjs.com/package/react-native-speech-to-text)
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

## 📦 Installation

```sh
npm install react-native-speech-to-text
# or
yarn add react-native-speech-to-text
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

## � Usage

```js
import {
  startRecording,
  stopRecording,
  addSpeechResultListener,
  addSpeechErrorListener,
} from 'react-native-speech-to-text';

// Start recording
await startRecording();

// Listen for results
const resultSub = addSpeechResultListener((text) => {
  console.log('Transcribed:', text);
});

// Listen for errors
const errorSub = addSpeechErrorListener((err) => {
  console.error('Error:', err);
});

// Stop recording
stopRecording();

// Remove listeners when done
resultSub.remove();
errorSub.remove();
```

---

## 🧩 API Reference

### `startRecording(): Promise<string>`

Start speech recognition and audio recording.

### `stopRecording(): void`

Stop the current recognition session.

### `addSpeechResultListener(listener: (text: string) => void)`

Subscribe to speech recognition results. Returns a subscription with `.remove()`.

### `addSpeechErrorListener(listener: (error: string) => void)`

Subscribe to errors. Returns a subscription with `.remove()`.

---

## � Example

```js
import { useState, useEffect } from 'react';
import { View, Button, Text } from 'react-native';
import {
  startRecording,
  stopRecording,
  addSpeechResultListener,
  addSpeechErrorListener,
} from 'react-native-speech-to-text';

export default function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [text, setText] = useState('');

  useEffect(() => {
    const resultSub = addSpeechResultListener(setText);
    const errorSub = addSpeechErrorListener(() => setIsRecording(false));
    return () => {
      resultSub.remove();
      errorSub.remove();
    };
  }, []);

  return (
    <View>
      <Text>{text || 'No text yet'}</Text>
      <Button
        title={isRecording ? 'Stop' : 'Start'}
        onPress={
          isRecording
            ? () => {
                stopRecording();
                setIsRecording(false);
              }
            : async () => {
                await startRecording();
                setIsRecording(true);
              }
        }
      />
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
