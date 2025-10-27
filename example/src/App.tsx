import { useState, useEffect } from 'react';
import {
  Text,
  View,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';

import {
  startSpeechRecognition,
  stopSpeechRecognition,
  addSpeechFinishedListener,
  addSpeechErrorListener,
  addSpeechResultListener,
} from 'react-native-speechkit';
import { PermissionsAndroid, Platform } from 'react-native';
// Request RECORD_AUDIO permission at runtime (Android)
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

export default function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [transcribedText, setTranscribedText] = useState('');
  const [history, setHistory] = useState<string[]>([]);

  useEffect(() => {
    const resultSubscription = addSpeechResultListener(({ text }) => {
      setTranscribedText(text);
    });

    const finishedSubscription = addSpeechFinishedListener(
      ({ finalResult }) => {
        setIsRecording(false);
        if (finalResult) {
          setHistory((prev) => [finalResult, ...prev]);
        }
      }
    );

    const errorSubscription = addSpeechErrorListener(({ error }) => {
      Alert.alert('Speech Error', error);
      setIsRecording(false);
    });

    return () => {
      finishedSubscription.remove();
      resultSubscription.remove();
      errorSubscription.remove();
    };
  }, []);

  const handleStartRecording = async () => {
    try {
      const hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        Alert.alert('Permission Denied', 'Microphone permission is required.');
        return;
      }
      await startSpeechRecognition();
      setIsRecording(true);
      setTranscribedText('');
    } catch (error) {
      Alert.alert('Error', `Failed to start recording: ${error}`);
    }
  };

  const handleStopRecording = () => {
    stopSpeechRecognition();
    setIsRecording(false);
    if (transcribedText) {
      setHistory((prev) => [transcribedText, ...prev]);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Speech to Text</Text>

      <View style={styles.statusContainer}>
        <View
          style={[
            styles.statusIndicator,
            isRecording && styles.statusIndicatorActive,
          ]}
        />
        <Text style={styles.statusText}>
          {isRecording ? 'Recording...' : 'Ready'}
        </Text>
      </View>

      <View style={styles.transcriptionContainer}>
        <Text style={styles.label}>Current Transcription:</Text>
        <ScrollView style={styles.textBox}>
          <Text style={styles.transcriptionText}>
            {transcribedText || 'Start recording to see text...'}
          </Text>
        </ScrollView>
      </View>

      <TouchableOpacity
        style={[
          styles.button,
          isRecording ? styles.buttonStop : styles.buttonStart,
        ]}
        onPress={isRecording ? handleStopRecording : handleStartRecording}
      >
        <Text style={styles.buttonText}>
          {isRecording ? 'Stop Recording' : 'Start Recording'}
        </Text>
      </TouchableOpacity>

      {history.length > 0 && (
        <View style={styles.historyContainer}>
          <Text style={styles.label}>History:</Text>
          <ScrollView style={styles.historyList}>
            {history.map((text, index) => (
              <View key={index} style={styles.historyItem}>
                <Text style={styles.historyText}>{text}</Text>
              </View>
            ))}
          </ScrollView>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginTop: 40,
    marginBottom: 20,
    color: '#333',
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  statusIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#ccc',
    marginRight: 8,
  },
  statusIndicatorActive: {
    backgroundColor: '#ff4444',
  },
  statusText: {
    fontSize: 16,
    color: '#666',
  },
  transcriptionContainer: {
    flex: 1,
    marginBottom: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 10,
    color: '#333',
  },
  textBox: {
    flex: 1,
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 15,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  transcriptionText: {
    fontSize: 18,
    color: '#333',
    lineHeight: 26,
  },
  button: {
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 20,
  },
  buttonStart: {
    backgroundColor: '#4CAF50',
  },
  buttonStop: {
    backgroundColor: '#f44336',
  },
  buttonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: '600',
  },
  historyContainer: {
    flex: 1,
    maxHeight: 200,
  },
  historyList: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 10,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  historyItem: {
    padding: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  historyText: {
    fontSize: 14,
    color: '#666',
  },
});
