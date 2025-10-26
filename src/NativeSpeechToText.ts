import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  multiply(a: number, b: number): number;
  startRecording(): Promise<string>;
  stopRecording(): void;
  playAudio(filePath: string): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('SpeechToText');
