package com.speechtotext

import android.content.Intent
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.io.File
import java.io.IOException
import java.util.*

class SpeechToTextModule(private val reactContext: ReactApplicationContext)
  : ReactContextBaseJavaModule(reactContext) {

  private var speechRecognizer: SpeechRecognizer? = null
  private var mediaRecorder: MediaRecorder? = null
  private var mediaPlayer: MediaPlayer? = null
  private var currentFileName: String? = null
  private var currentFilePath: String? = null
  private var isRecording = false

  override fun getName() = "SpeechToText"

  @ReactMethod
  fun multiply(a: Double, b: Double, promise: Promise) {
    promise.resolve(a * b)
  }

  @ReactMethod
  fun startRecording(promise: Promise) {
    if (!SpeechRecognizer.isRecognitionAvailable(reactContext)) {
      promise.reject("E_NO_SPEECH", "Speech recognition not available")
      return
    }

    try {
      // Generate unique filename
      currentFileName = "${UUID.randomUUID()}.wav"
      currentFilePath = File(reactContext.filesDir, currentFileName!!).absolutePath

      // Start audio recording
      startAudioRecording()

      // Start speech recognition
      startSpeechRecognition()

      isRecording = true
      promise.resolve("Recording started")
    } catch (e: Exception) {
      promise.reject("E_START", "Failed to start recording: ${e.message}", e)
    }
  }

  private fun startAudioRecording() {
    mediaRecorder = MediaRecorder().apply {
      setAudioSource(MediaRecorder.AudioSource.MIC)
      setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
      setOutputFile(currentFilePath)
      setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)

      try {
        prepare()
        start()
      } catch (e: IOException) {
        throw RuntimeException("Failed to start audio recording", e)
      }
    }
  }

  private fun startSpeechRecognition() {
    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(reactContext)
    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
      putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
      putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
      putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
      putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
    }

    speechRecognizer?.setRecognitionListener(object : RecognitionListener {
      override fun onResults(results: Bundle?) {
        results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let { text ->
          val resultData = WritableNativeMap().apply {
            putString("text", text)
          }
          sendEvent("onSpeechResult", resultData)

          // Stop recording and emit saved event
          stopRecordingInternal(true)
        }
      }

      override fun onPartialResults(results: Bundle?) {
        results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let { text ->
          val resultData = WritableNativeMap().apply {
            putString("text", text)
          }
          sendEvent("onSpeechResult", resultData)
        }
      }

      override fun onError(error: Int) { 
        val errorMessage = when(error) {
          SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
          SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech input timeout"
          SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
          SpeechRecognizer.ERROR_NETWORK -> "Network error"
          SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
          SpeechRecognizer.ERROR_SERVER -> "Server error"
          SpeechRecognizer.ERROR_CLIENT -> "Client error"
          SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
          SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RecognitionService busy"
          else -> "Unknown error: $error"
        }

        // Only send non-critical errors
        if (error != SpeechRecognizer.ERROR_NO_MATCH && error != SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
          sendEvent("onSpeechError", errorMessage)
        }
      }

      override fun onReadyForSpeech(params: Bundle?) {}
      override fun onBeginningOfSpeech() {}
      override fun onRmsChanged(rmsdB: Float) {}
      override fun onBufferReceived(buffer: ByteArray?) {}
      override fun onEndOfSpeech() {}
      override fun onEvent(eventType: Int, params: Bundle?) {}
    })

    speechRecognizer?.startListening(intent)
  }

  @ReactMethod
  fun stopRecording() {
    stopRecordingInternal(true)
  }

  private fun stopRecordingInternal(emitSavedEvent: Boolean) {
    if (!isRecording) return

    try {
      // Stop speech recognition
      speechRecognizer?.stopListening()
      speechRecognizer?.destroy()
      speechRecognizer = null

      // Stop audio recording
      mediaRecorder?.apply {
        try {
          stop()
          reset()
          release()
        } catch (e: Exception) {
          // Handle potential issues with stopping recorder
        }
      }
      mediaRecorder = null

      isRecording = false

      // Emit recording saved event
      if (emitSavedEvent && currentFileName != null && currentFilePath != null) {
        val savedData = WritableNativeMap().apply {
          putString("fileName", currentFileName!!)
          putString("filePath", currentFilePath!!)
        }
        sendEvent("onRecordingSaved", savedData)
      }
    } catch (e: Exception) {
      // Log error but don't crash
      e.printStackTrace()
    } finally {
      currentFileName = null
      currentFilePath = null
    }
  }

  @ReactMethod
  fun playAudio(filePath: String, promise: Promise) {
    try {
      // Release any existing player
      mediaPlayer?.release()

      mediaPlayer = MediaPlayer().apply {
        setDataSource(filePath)
        setOnCompletionListener {
          release()
          mediaPlayer = null
          promise.resolve("Playback completed")
        }
        setOnErrorListener { _, what, extra ->
          release()
          mediaPlayer = null
          promise.reject("E_PLAYBACK", "Playback error: what=$what, extra=$extra")
          true
        }
        prepareAsync()
        setOnPreparedListener { start() }
      }
    } catch (e: Exception) {
      promise.reject("E_PLAYBACK", "Failed to play audio: ${e.message}", e)
    }
  }

  private fun sendEvent(eventName: String, data: Any) {
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, data)
  }

  override fun onCatalystInstanceDestroy() {
    super.onCatalystInstanceDestroy()
    stopRecordingInternal(false)
    mediaPlayer?.release()
    mediaPlayer = null
  }
}
