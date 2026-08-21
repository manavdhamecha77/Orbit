package com.example.offline_ai

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
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
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var engine: InferenceEngine? = null
    private var sink: EventChannel.EventSink? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private val pickModelRequestCode = 4107
    private val generating = AtomicBoolean(false)
    private var generationJob: Job? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_ai/llm").setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> loadModel(result)
                "pickModel" -> pickModel(result)
                "generate" -> generate(call.argument<String>("prompt") ?: "", result)
                "stopGeneration" -> stopGeneration(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_ai/llm_stream").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
            override fun onCancel(arguments: Any?) { 
                sink = null 
                // Also stop generation on stream cancellation (e.g. user navigation or stream closing)
                generationJob?.cancel()
                generating.set(false)
            }
        })
    }

    private fun loadModel(result: MethodChannel.Result) = scope.launch {
        try {
            val modelsDir = File(filesDir, "models")
            val txtFile = File(modelsDir, "selected-model.txt")
            val selected = File(modelsDir, "selected-model.gguf")
            val legacy = File(modelsDir, "qwen2.5-1.5b-instruct-q4_k_m.gguf")

            if (txtFile.exists() && selected.exists() && selected.length() > 0) {
                val modelName = txtFile.readText().trim()
                loadPrivateModel(selected, modelName, result)
            } else if (legacy.exists() && legacy.length() > 0) {
                loadPrivateModel(legacy, legacy.name, result)
            } else {
                result.error("NO_MODEL", "No model loaded", null)
            }
        } catch (t: Throwable) { 
            result.error("MODEL_LOAD_FAILED", t.message ?: t.toString(), null) 
        }
    }

    private fun pickModel(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "Another model selection is already open", null)
            return
        }
        pendingPickResult = result
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/octet-stream", "application/*", "*/*"))
        }, pickModelRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickModelRequestCode) return
        val result = pendingPickResult
        pendingPickResult = null
        if (result == null) return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.error("MODEL_SELECTION_CANCELLED", "No model was selected", null)
            return
        }
        scope.launch {
            try {
                val modelName = withContext(Dispatchers.IO) { queryDisplayName(uri) ?: "selected-model.gguf" }
                val model = withContext(Dispatchers.IO) { copyUriToPrivateStorage(uri, modelName) }
                loadPrivateModel(model, modelName, result)
            } catch (t: Throwable) {
                result.error("MODEL_LOAD_FAILED", t.message ?: t.toString(), null)
            }
        }
    }

    private suspend fun loadPrivateModel(model: File, modelName: String, result: MethodChannel.Result) {
        val loadedEngine = withContext(Dispatchers.IO) {
            AiChat.getInferenceEngine(applicationContext).also { created ->
                created.state.first { it is InferenceEngine.State.Initialized }
            }
        }
        engine = loadedEngine
        withContext(Dispatchers.IO) { loadedEngine.loadModel(model.absolutePath) }
        result.success(modelName)
    }

    private fun generate(prompt: String, result: MethodChannel.Result) {
        val loadedEngine = engine
        if (loadedEngine == null) { result.error("NOT_READY", "Model is not loaded", null); return }
        if (!generating.compareAndSet(false, true)) { result.error("BUSY", "Generation already in progress", null); return }
        generationJob = scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    loadedEngine.sendUserPrompt(prompt).collect { token ->
                        withContext(Dispatchers.Main) { sink?.success(token) }
                    }
                }
                sink?.success("__DONE__")
                result.success("done")
            } catch (t: CancellationException) {
                // job was stopped/cancelled
                sink?.success("__DONE__")
                result.success("cancelled")
            } catch (t: Throwable) {
                sink?.error("GENERATION_FAILED", t.message, null)
                result.error("GENERATION_FAILED", t.message ?: t.toString(), null)
            } finally { 
                generating.set(false) 
                generationJob = null
            }
        }
    }

    private fun stopGeneration(result: MethodChannel.Result) {
        generationJob?.cancel()
        generating.set(false)
        result.success(true)
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1 && cursor.moveToFirst()) {
                        return cursor.getString(nameIndex)
                    }
                }
            } catch (e: Exception) {
                // ignore
            }
        }
        return uri.path?.let { File(it).name }
    }

    private fun copyUriToPrivateStorage(uri: Uri, modelName: String): File {
        val modelsDir = File(filesDir, "models")
        val destination = File(modelsDir, "selected-model.gguf")
        destination.parentFile!!.mkdirs()
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Could not open the selected model" }
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        }
        require(destination.length() > 0) { "Copied model is empty" }
        
        // Save the model display name
        try {
            File(modelsDir, "selected-model.txt").writeText(modelName)
        } catch (e: Exception) {
            // ignore
        }
        
        return destination
    }

    override fun onDestroy() {
        runCatching { engine?.destroy() }
        scope.cancel()
        super.onDestroy()
    }
}
