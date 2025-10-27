# Speech to Text Usage Guide

## Overview

This React Native module provides speech recognition capabilities for both iOS and Android platforms.

## Installation

```bash
npm install react-native-speech-to-text
# or
yarn add react-native-speech-to-text
```

### iOS Setup

1. Install pods:

```bash
cd ios && pod install
```

2. The required permissions are already added to your Info.plist:
   - `NSMicrophoneUsageDescription`
   - `NSSpeechRecognitionUsageDescription`

### Android Setup

The required permission `RECORD_AUDIO` is already added to AndroidManifest.xml.

You may need to request runtime permissions for Android 6.0+:

```typescript
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

## API Reference

### Functions

#### `startRecording(): Promise<string>`

Starts speech recognition. Returns a promise that resolves when recording starts.

```typescript
import { startRecording } from 'react-native-speech-to-text';

try {
  await startRecording();
  console.log('Recording started');
} catch (error) {
  console.error('Failed to start recording:', error);
}
```

#### `stopRecording(): void`

Stops the current speech recognition session.

```typescript
import { stopRecording } from 'react-native-speech-to-text';

stopRecording();
```

#### `addSpeechResultListener(listener: (text: string) => void)`

Adds a listener for speech recognition results. The listener will be called with transcribed text as it becomes available.

Returns a subscription object with a `remove()` method.

```typescript
import { addSpeechResultListener } from 'react-native-speech-to-text';

const subscription = addSpeechResultListener((text) => {
  console.log('Transcribed text:', text);
});

// Don't forget to remove the listener when done
subscription.remove();
```

#### `addSpeechErrorListener(listener: (error: string) => void)`

Adds a listener for speech recognition errors.

Returns a subscription object with a `remove()` method.

```typescript
import { addSpeechErrorListener } from 'react-native-speech-to-text';

const subscription = addSpeechErrorListener((error) => {
  console.error('Speech recognition error:', error);
});

// Don't forget to remove the listener when done
subscription.remove();
```

## Complete Example

```typescript
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
    const resultSub = addSpeechResultListener((transcribedText) => {
      setText(transcribedText);
    });

    const errorSub = addSpeechErrorListener((error) => {
      console.error('Error:', error);
      setIsRecording(false);
    });

    return () => {
      resultSub.remove();
      errorSub.remove();
    };
  }, []);

  const handleStart = async () => {
    try {
      await startRecording();
      setIsRecording(true);
    } catch (error) {
      console.error('Failed to start:', error);
    }
  };

  const handleStop = () => {
    stopRecording();
    setIsRecording(false);
  };

  return (
    <View>
      <Text>{text || 'No text yet'}</Text>
      <Button
        title={isRecording ? 'Stop' : 'Start'}
        onPress={isRecording ? handleStop : handleStart}
      />
    </View>
  );
}
```

## Platform Notes

### iOS

- Requires iOS 10.0 or later
- Uses Apple's Speech framework
- Supports continuous recognition with partial results
- Requires user permission for both microphone and speech recognition

### Android

- Requires Android API level 21 or later
- Uses Android's SpeechRecognizer
- Supports partial results
- Requires RECORD_AUDIO permission
