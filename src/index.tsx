import { NativeEventEmitter, NativeModules } from 'react-native';
import SpeechToText from './NativeSpeechToText';

export { SpeechToText };

export interface SpeechResultListener {
  (data: { text: string; isFinal: boolean }): void;
}

export interface SpeechErrorListener {
  (data: { error: string }): void;
}

export interface SpeechFinishedListener {
  (data: { finalResult: string; audioLocalPath: string }): void;
}

const speechEventEmitter = new NativeEventEmitter(NativeModules.SpeechToText);

export function startSpeechRecognition(
  fileURLString?: string | null,
  autoStopAfter?: number | null
): Promise<string> {
  return SpeechToText.startSpeechRecognition(
    fileURLString ?? null,
    autoStopAfter ?? null
  );
}

export function stopSpeechRecognition(): void {
  SpeechToText.stopSpeechRecognition();
}

export function addSpeechResultListener(listener: SpeechResultListener) {
  return speechEventEmitter.addListener('onSpeechRecognitionResult', (data) =>
    listener(data as { text: string; isFinal: boolean })
  );
}

export function addSpeechErrorListener(listener: SpeechErrorListener) {
  return speechEventEmitter.addListener('onSpeechRecognitionError', (data) =>
    listener(data as { error: string })
  );
}

export function addSpeechFinishedListener(listener: SpeechFinishedListener) {
  return speechEventEmitter.addListener('onSpeechRecognitionFinished', (data) =>
    listener(data as { finalResult: string; audioLocalPath: string })
  );
}
