import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  startSpeechRecognition(
    fileURLString: string | null,
    autoStopAfter: number | null
  ): Promise<string>;
  stopSpeechRecognition(): void;
  playAudio(filePath: string): Promise<string>;
  stopAudio(): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('SpeechToText');
