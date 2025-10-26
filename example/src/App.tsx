import { useState, useEffect, useRef } from 'react';
import {
  Text,
  View,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import {
  startRecording,
  stopRecording,
  addSpeechResultListener,
  addSpeechErrorListener,
  addRecordingSavedListener,
  playAudio,
} from 'react-native-speech-to-text';

interface HistoryItem {
  text: string;
  filePath?: string;
  timestamp: Date;
}

export default function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [transcribedText, setTranscribedText] = useState('');
  const [history, setHistory] = useState<HistoryItem[]>([]);

  const [isPlaying, setIsPlaying] = useState(false);

  // Use ref to store the recording path immediately when event is received
  const recordingPathRef = useRef<string | null>(null);

  useEffect(() => {
    const resultSubscription = addSpeechResultListener((text) => {
      setTranscribedText(text);
    });

    const errorSubscription = addSpeechErrorListener((error) => {
      Alert.alert('Speech Error', error);
      setIsRecording(false);
    });

    const recordingSavedSubscription = addRecordingSavedListener((data) => {
      console.log('Recording saved event received:', data);
      recordingPathRef.current = data.filePath;
    });

    return () => {
      resultSubscription.remove();
      errorSubscription.remove();
      recordingSavedSubscription.remove();
    };
  }, []);

  const handleStartRecording = async () => {
    try {
      recordingPathRef.current = null;
      await startRecording();
      setIsRecording(true);
      setTranscribedText('');
    } catch (error) {
      Alert.alert('Error', `Failed to start recording: ${error}`);
    }
  };

  const handleStopRecording = () => {
    stopRecording();
    setIsRecording(false);

    console.log('Stopping recording. Ref path:', recordingPathRef.current);
    console.log('Transcribed text:', transcribedText);

    if (transcribedText) {
      // Wait a moment for the recording saved event to potentially arrive
      setTimeout(() => {
        const finalPath = recordingPathRef.current;
        console.log('Adding to history. Final path:', finalPath);
        setHistory((prev) => [
          {
            text: transcribedText,
            filePath: finalPath || undefined,
            timestamp: new Date(),
          },
          ...prev,
        ]);
        recordingPathRef.current = null;
      }, 500);
    } else {
      recordingPathRef.current = null;
    }
  };

  const handlePlayRecording = async (filePath: string) => {
    if (isPlaying) return;

    console.log('Attempting to play audio from:', filePath);

    try {
      setIsPlaying(true);
      await playAudio(filePath);
      console.log('Audio playback completed');
    } catch (error) {
      console.error('Audio playback failed:', error);
      Alert.alert('Playback Error', `Failed to play recording: ${error}`);
    } finally {
      setIsPlaying(false);
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
            {history.map((item, index) => (
              <TouchableOpacity
                key={index}
                style={[
                  styles.historyItem,
                  item.filePath && styles.historyItemClickable,
                  isPlaying && styles.historyItemPlaying,
                ]}
                onPress={() =>
                  item.filePath && handlePlayRecording(item.filePath)
                }
                disabled={!item.filePath || isPlaying}
              >
                <View style={styles.historyItemContent}>
                  <Text style={styles.historyText}>{item.text}</Text>
                  <View style={styles.playIndicator}>
                    {item.filePath ? (
                      <Text style={styles.playIndicatorText}>
                        {isPlaying ? '⏸️' : '▶️'}
                      </Text>
                    ) : (
                      <Text style={styles.noAudioIndicator}>🚫</Text>
                    )}
                  </View>
                </View>
                <View style={styles.debugInfo}>
                  <Text style={styles.timestampText}>
                    {item.timestamp.toLocaleTimeString()}
                  </Text>
                  <Text style={styles.debugText}>
                    Audio: {item.filePath ? 'Yes' : 'No'}
                  </Text>
                </View>
              </TouchableOpacity>
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
  historyItemClickable: {
    backgroundColor: '#f8f9fa',
  },
  historyItemPlaying: {
    backgroundColor: '#e3f2fd',
  },
  historyItemContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  historyText: {
    fontSize: 14,
    color: '#666',
    flex: 1,
  },
  playIndicator: {
    marginLeft: 10,
  },
  playIndicatorText: {
    fontSize: 16,
  },
  noAudioIndicator: {
    fontSize: 16,
    opacity: 0.3,
  },
  debugInfo: {
    marginTop: 4,
  },
  timestampText: {
    fontSize: 12,
    color: '#999',
  },
  debugText: {
    fontSize: 10,
    color: '#999',
    fontStyle: 'italic',
  },
});
