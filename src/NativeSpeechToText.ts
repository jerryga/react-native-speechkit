import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  startSpeechRecognition(): Promise<string>;
  stopSpeechRecognition(): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('SpeechToText');
