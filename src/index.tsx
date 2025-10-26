import { NativeEventEmitter, NativeModules } from 'react-native';
import SpeechToText from './NativeSpeechToText';

export function multiply(a: number, b: number): number {
  return SpeechToText.multiply(a, b);
}

export interface SpeechResultListener {
  (text: string): void;
}

export interface SpeechErrorListener {
  (error: string): void;
}

export interface RecordingSavedListener {
  (data: { fileName: string; filePath: string }): void;
}

const speechEventEmitter = new NativeEventEmitter(NativeModules.SpeechToText);

export function startRecording(): Promise<string> {
  return SpeechToText.startRecording();
}

export function stopRecording(): void {
  SpeechToText.stopRecording();
}

export function addSpeechResultListener(listener: SpeechResultListener) {
  return speechEventEmitter.addListener('onSpeechResult', (data) => {
    let text: string = '';

    if (typeof data === 'string') {
      text = data;
    } else if (typeof data === 'object' && data !== null) {
      // Handle object with text property
      if ('text' in data && typeof data.text === 'string') {
        text = data.text;
      } else {
        // Fallback: stringify the object or use empty string
        text = JSON.stringify(data);
      }
    } else {
      // Fallback for any other data type
      text = String(data || '');
    }

    listener(text);
  });
}

export function addSpeechErrorListener(listener: SpeechErrorListener) {
  return speechEventEmitter.addListener('onSpeechError', (error) =>
    listener(error as string)
  );
}

export function addRecordingSavedListener(listener: RecordingSavedListener) {
  return speechEventEmitter.addListener('onRecordingSaved', (data) => {
    if (
      typeof data === 'object' &&
      data !== null &&
      'fileName' in data &&
      'filePath' in data
    ) {
      listener(data as { fileName: string; filePath: string });
    }
  });
}

export function playAudio(filePath: string): Promise<void> {
  return SpeechToText.playAudio(filePath);
}
