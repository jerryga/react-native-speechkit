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

export interface SpeechFinishedListener {
  (data: { finalResult: string; audioLocalPath: string }): void;
}

const speechEventEmitter = new NativeEventEmitter(NativeModules.SpeechToText);

export function startRecording(): Promise<string> {
  return SpeechToText.startRecording();
}

export function stopRecording(): void {
  SpeechToText.stopRecording();
}

export function addSpeechResultListener(listener: SpeechResultListener) {
  return speechEventEmitter.addListener('onSpeechResult', (text) =>
    listener(text as string)
  );
}

export function addSpeechErrorListener(listener: SpeechErrorListener) {
  return speechEventEmitter.addListener('onSpeechError', (error) =>
    listener(error as string)
  );
}

export function addSpeechFinishedListener(listener: SpeechFinishedListener) {
  return speechEventEmitter.addListener('onSpeechFinished', (data) =>
    listener(data as { finalResult: string; audioLocalPath: string })
  );
}
