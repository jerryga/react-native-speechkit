# Speech to Text Usage Guide

## Overview

This React Native module provides speech recognition capabilities for both iOS and Android platforms.

## Installation

```bash
npm install react-native-speechkit
# or
yarn add react-native-speechkit
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


#### `startSpeechRecognition(fileURLString?: string | null, autoStopAfter?: number | null): Promise<string>`

Starts speech recognition and audio recording. Optionally specify a file path and auto-stop duration (ms).

```typescript
import { startSpeechRecognition } from 'react-native-speechkit';

try {
  await startSpeechRecognition();
  console.log('Recognition started');
} catch (error) {
  console.error('Failed to start recognition:', error);
}
```


#### `stopSpeechRecognition(): void`

Stops the current speech recognition session.

```typescript
import { stopSpeechRecognition } from 'react-native-speechkit';

stopSpeechRecognition();
```


#### `addSpeechResultListener(listener: (data: { text: string; isFinal: boolean }) => void)`

Adds a listener for speech recognition results (partial and final). The listener receives an object with `text` and `isFinal` properties.

Returns a subscription object with a `remove()` method.

```typescript
import { addSpeechResultListener } from 'react-native-speechkit';

const subscription = addSpeechResultListener(({ text, isFinal }) => {
  console.log('Transcribed text:', text, 'Final:', isFinal);
});

// Don't forget to remove the listener when done
subscription.remove();
```


#### `addSpeechErrorListener(listener: (data: { error: string }) => void)`

Adds a listener for speech recognition errors. The listener receives an object with an `error` property.

Returns a subscription object with a `remove()` method.

```typescript
import { addSpeechErrorListener } from 'react-native-speechkit';

const subscription = addSpeechErrorListener(({ error }) => {
  console.error('Speech recognition error:', error);
});

// Don't forget to remove the listener when done
subscription.remove();
```

#### `addSpeechFinishedListener(listener: (data: { finalResult: string; audioLocalPath: string }) => void)`

Adds a listener for the finished event, which provides the final recognized text and the local audio file path. Returns a subscription with `.remove()`.

```typescript
import { addSpeechFinishedListener } from 'react-native-speechkit';

const subscription = addSpeechFinishedListener(({ finalResult, audioLocalPath }) => {
  console.log('Final result:', finalResult, 'Audio file:', audioLocalPath);
});

// Don't forget to remove the listener when done
subscription.remove();
```


## Complete Example

```typescript
import { useState, useEffect } from 'react';
import { View, Button, Text } from 'react-native';
import {
  startSpeechRecognition,
  stopSpeechRecognition,
  addSpeechResultListener,
  addSpeechErrorListener,
  addSpeechFinishedListener,
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
    const finishedSub = addSpeechFinishedListener(({ finalResult, audioLocalPath }) => {
      setText(finalResult);
      setAudioPath(audioLocalPath);
      setIsRecording(false);
    });
    return () => {
      resultSub.remove();
      errorSub.remove();
      finishedSub.remove();
    };
  }, []);

  const handleStart = async () => {
    try {
      await startSpeechRecognition();
      setIsRecording(true);
    } catch (error) {
      console.error('Failed to start:', error);
    }
  };

  const handleStop = () => {
    stopSpeechRecognition();
    setIsRecording(false);
  };

  return (
    <View>
      <Text>{text || 'No text yet'}</Text>
      <Text>{audioPath ? `Audio: ${audioPath}` : ''}</Text>
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
