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

    // Check permission
    val hasPermission = ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
        PermissionChecker.PERMISSION_GRANTED
    if (!hasPermission) {
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
      speechRecognizer?.stopListening()
      speechRecognizer?.destroy()
      speechRecognizer = null

      stopMediaRecorderSafely()

      val result = Arguments.createMap().apply {
        putString("finalResult", finalTranscription)
        putString("audioLocalPath", audioFile?.absolutePath ?: "")
      }
      sendEvent("onSpeechRecognitionFinished", result)

      finalTranscription = ""
      audioFile = null
    }
  }

  private fun sendEvent(eventName: String, params: Any?) {
    reactContext
      .getJSModule(RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  // ----------------------------------------------------------
  // RecognitionListener Callbacks
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
    // send the string message directly
     val map = Arguments.createMap().apply {
      putString("error", msg)
    }
    sendEvent("onSpeechRecognitionError", map)
  }

  override fun onResults(results: Bundle?) {
    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
    val text = matches?.firstOrNull() ?: ""
    finalTranscription = text
    val map = Arguments.createMap().apply {
      putString("text", text)
      putBoolean("isFinal", true)
    }
    sendEvent("onSpeechRecognitionResult", map)
  }

  override fun onPartialResults(partialResults: Bundle?) {
    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
    val text = matches?.firstOrNull() ?: ""
    if (text.isNotEmpty()) finalTranscription = text
    val map = Arguments.createMap().apply {
      putString("text", text)
      putBoolean("isFinal", false)
    }
    sendEvent("onSpeechRecognitionResult", map)
  }

  override fun onEvent(eventType: Int, params: Bundle?) {}

  // ----------------------------------------------------------
  // Lifecycle cleanup
  // ----------------------------------------------------------
  override fun onCatalystInstanceDestroy() {
    handler.post {
      try {
        speechRecognizer?.destroy()
      } catch (_: Exception) {}
      stopMediaRecorderSafely()
      super.onCatalystInstanceDestroy()
    }
  }
}
