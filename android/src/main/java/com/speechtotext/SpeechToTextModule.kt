package com.speechtotext

import android.Manifest
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import java.io.File
import java.util.*

class SpeechToTextModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), RecognitionListener {

  private var mediaPlayer: android.media.MediaPlayer? = null
  private var speechRecognizer: SpeechRecognizer? = null
  private var recognizerIntent: android.content.Intent? = null
  private var mediaRecorder: MediaRecorder? = null
  private var audioFile: File? = null
  private var finalTranscription: String = ""
  private val handler = Handler(Looper.getMainLooper())
  private var autoStopRunnable: Runnable? = null

  override fun getName(): String = "SpeechToText"

  // ----------------------------------------------------------
  // JS-Visible Methods
  // ----------------------------------------------------------
  @ReactMethod
  fun startSpeechRecognition(fileURLString: String?, autoStopAfter: Int?, promise: Promise) {
    val ctx = reactApplicationContext

    // Check permissions
    val hasRecordPermission =
      ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
        PermissionChecker.PERMISSION_GRANTED
    val hasStoragePermission =
      ContextCompat.checkSelfPermission(ctx, Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
        PermissionChecker.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_EXTERNAL_STORAGE) ==
        PermissionChecker.PERMISSION_GRANTED

    if (!hasRecordPermission) {
      promise.reject("E_PERMISSION", "RECORD_AUDIO permission denied")
      return
    }

    // Prepare audio file
    audioFile = if (!fileURLString.isNullOrBlank()) {
      File(fileURLString)
    } else {
      File(ctx.filesDir, "${UUID.randomUUID()}.m4a")
    }

    try {
      startMediaRecorder(audioFile!!)
    } catch (e: Exception) {
      promise.reject("E_START_RECORDER", "Failed to start audio recording: ${e.message}", e)
      return
    }

    try {
      startSpeechRecognizer()
    } catch (e: Exception) {
      stopMediaRecorderSafely()
      promise.reject("E_START_SR", "Failed to start speech recognizer: ${e.message}", e)
      return
    }

    promise.resolve("Recording started")

    // Schedule auto stop
    if ((autoStopAfter ?: 0) > 0) {
      autoStopRunnable?.let { handler.removeCallbacks(it) }
      autoStopRunnable = Runnable { stopSpeechRecognitionInternal() }
      handler.postDelayed(autoStopRunnable!!, (autoStopAfter!! * 1000).toLong())
    }
  }

  @ReactMethod
  fun stopSpeechRecognition() {
    autoStopRunnable?.let { handler.removeCallbacks(it) }
    autoStopRunnable = null
    stopSpeechRecognitionInternal()
  }

  // ----------------------------------------------------------
  // Internal helpers
  // ----------------------------------------------------------
  private fun startSpeechRecognizer() {
    val ctx = reactApplicationContext
    handler.post {
      if (!SpeechRecognizer.isRecognitionAvailable(ctx)) {
        throw RuntimeException("Speech recognition not available on this device.")
      }

      speechRecognizer = SpeechRecognizer.createSpeechRecognizer(ctx)
      speechRecognizer?.setRecognitionListener(this)

      recognizerIntent = android.content.Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
      }

      speechRecognizer?.startListening(recognizerIntent)
    }
  }

  private fun startMediaRecorder(file: File) {
    mediaRecorder = MediaRecorder().apply {
      setAudioSource(MediaRecorder.AudioSource.MIC)
      setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
      setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
      setOutputFile(file.absolutePath)
      prepare()
      start()
    }
  }

  private fun stopMediaRecorderSafely() {
    try {
      mediaRecorder?.stop()
    } catch (e: Exception) {
      Log.w("SpeechToText", "mediaRecorder.stop() failed: ${e.message}")
    } finally {
      try {
        mediaRecorder?.release()
      } catch (_: Exception) {}
      mediaRecorder = null
    }
  }

  private fun stopSpeechRecognitionInternal() {
    handler.post {
      try {
        speechRecognizer?.stopListening()
      } catch (_: Exception) {}
      try {
        speechRecognizer?.destroy()
      } catch (_: Exception) {}
      speechRecognizer = null

      stopMediaRecorderSafely()

      val result = Arguments.createMap().apply {
        putString("finalResult", finalTranscription)
        putString("audioLocalPath", audioFile?.absolutePath ?: "")
      }
      reactContext.runOnUiQueueThread {
        sendEvent("onSpeechRecognitionFinished", result)
      }

      // Delay reset slightly to avoid race with async result callbacks
      handler.postDelayed({
        finalTranscription = ""
        audioFile = null
      }, 500)
    }
  }

  private fun sendEvent(eventName: String, params: Any?) {
    reactContext
      .getJSModule(RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  // ----------------------------------------------------------
  // RecognitionListener Callbacks (thread-safe)
  // ----------------------------------------------------------
  override fun onReadyForSpeech(params: Bundle?) {}
  override fun onBeginningOfSpeech() {}
  override fun onRmsChanged(rmsdB: Float) {}
  override fun onBufferReceived(buffer: ByteArray?) {}
  override fun onEndOfSpeech() {}

  override fun onError(error: Int) {
    val msg = when (error) {
      SpeechRecognizer.ERROR_AUDIO -> "ERROR_AUDIO"
      SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
      SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
      SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
      SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
      SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
      SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
      SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
      SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
      else -> "ERROR_UNKNOWN"
    }

    val map = Arguments.createMap().apply {
      putString("error", msg)
    }

    reactContext.runOnUiQueueThread {
      sendEvent("onSpeechRecognitionError", map)
    }
  }

  override fun onResults(results: Bundle?) {
    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
    val text = matches?.firstOrNull() ?: ""
    finalTranscription = text
    val map = Arguments.createMap().apply {
      putString("text", text)
      putBoolean("isFinal", true)
    }
    reactContext.runOnUiQueueThread {
      sendEvent("onSpeechRecognitionResult", map)
    }
  }

  override fun onPartialResults(partialResults: Bundle?) {
    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
    val text = matches?.firstOrNull() ?: ""
    if (text.isNotEmpty()) finalTranscription = text
    val map = Arguments.createMap().apply {
      putString("text", text)
      putBoolean("isFinal", false)
    }
    reactContext.runOnUiQueueThread {
      sendEvent("onSpeechRecognitionResult", map)
    }
  }

  // ----------------------------------------------------------
  // Play/Stop Audio Support
  // ----------------------------------------------------------
  @ReactMethod
  fun playAudio(filePath: String, promise: Promise) {
    try {
      mediaPlayer?.release()
      mediaPlayer = android.media.MediaPlayer().apply {
        setDataSource(filePath)

        setOnPreparedListener {
          it.start()
          reactContext.runOnUiQueueThread {
            promise.resolve("Audio playback started")
          }
        }

        setOnErrorListener { mp, what, extra ->
          reactContext.runOnUiQueueThread {
            promise.reject("E_PLAY", "Failed to play audio: what=$what, extra=$extra")
          }
          mp.release()
          mediaPlayer = null
          true
        }

        prepareAsync()
      }
    } catch (e: Exception) {
      mediaPlayer?.release()
      mediaPlayer = null
      promise.reject("E_PLAY", "Failed to play audio: ${e.message}", e)
    }
  }

  @ReactMethod
  fun stopAudio(promise: Promise) {
    try {
      mediaPlayer?.let {
        if (it.isPlaying) {
          it.stop()
        }
        it.release()
        mediaPlayer = null
        promise.resolve("Audio playback stopped")
      } ?: promise.reject("E_STOP", "No audio is playing")
    } catch (e: Exception) {
      promise.reject("E_STOP", "Failed to stop audio: ${e.message}", e)
    }
  }

  override fun onEvent(eventType: Int, params: Bundle?) {}

  // ----------------------------------------------------------
  // Lifecycle cleanup (fixed order)
  // ----------------------------------------------------------
  override fun onCatalystInstanceDestroy() {
    super.onCatalystInstanceDestroy()
    handler.post {
      try {
        speechRecognizer?.destroy()
      } catch (_: Exception) {}
      stopMediaRecorderSafely()
    }
  }
}
