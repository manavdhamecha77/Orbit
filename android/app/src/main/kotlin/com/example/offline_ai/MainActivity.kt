package com.example.offline_ai

import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.arm.aichat.AiChat
import com.arm.aichat.InferenceEngine
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var engine: InferenceEngine? = null
    private var sink: EventChannel.EventSink? = null
    private val generating = AtomicBoolean(false)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_ai/llm").setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> loadModel(result)
                "generate" -> generate(call.argument<String>("prompt") ?: "", result)
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_ai/llm_stream").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
            override fun onCancel(arguments: Any?) { sink = null }
        })
    }

    private fun loadModel(result: MethodChannel.Result) = scope.launch {
        try {
            val model = withContext(Dispatchers.IO) { copyModelToPrivateStorage() }
            val loadedEngine = withContext(Dispatchers.IO) {
                AiChat.getInferenceEngine(applicationContext).also { created ->
                    created.state.first { it is InferenceEngine.State.Initialized }
                }
            }
            engine = loadedEngine
            withContext(Dispatchers.IO) { loadedEngine.loadModel(model.absolutePath) }
            result.success("ready")
        } catch (t: Throwable) { result.error("MODEL_LOAD_FAILED", t.message ?: t.toString(), null) }
    }

    private fun generate(prompt: String, result: MethodChannel.Result) {
        val loadedEngine = engine
        if (loadedEngine == null) { result.error("NOT_READY", "Model is not loaded", null); return }
        if (!generating.compareAndSet(false, true)) { result.error("BUSY", "Generation already in progress", null); return }
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    loadedEngine.sendUserPrompt(prompt).collect { token ->
                        withContext(Dispatchers.Main) { sink?.success(token) }
                    }
                }
                sink?.success("__DONE__")
                result.success("done")
            } catch (t: Throwable) {
                sink?.error("GENERATION_FAILED", t.message, null)
                result.error("GENERATION_FAILED", t.message ?: t.toString(), null)
            } finally { generating.set(false) }
        }
    }

    private fun copyModelToPrivateStorage(): File {
        val destination = File(File(filesDir, "models"), "qwen2.5-1.5b-instruct-q4_k_m.gguf")
        if (destination.isFile && destination.length() > 0) return destination
        val source = File(Environment.getExternalStorageDirectory(), "Download/offline_ai/qwen2.5-1.5b-instruct-q4_k_m.gguf")
        require(source.isFile && source.canRead()) { "Model not readable at ${source.absolutePath}" }
        destination.parentFile!!.mkdirs()
        FileInputStream(source).use { input -> FileOutputStream(destination).use { output -> input.copyTo(output) } }
        require(destination.length() > 0) { "Copied model is empty" }
        return destination
    }

    override fun onDestroy() {
        runCatching { engine?.destroy() }
        scope.cancel()
        super.onDestroy()
    }
}
