package org.droidtop.vxace_translator_ui

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.jruby.embed.LocalContextScope
import org.jruby.embed.LocalVariableBehavior
import org.jruby.embed.PathType
import org.jruby.embed.ScriptingContainer
import java.io.File
import java.io.OutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "org.droidtop.vxace_translator/patcher"
    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel.setMethodCallHandler { call, result ->
            if (call.method != "patch") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val arguments = call.arguments as? Map<*, *>
            if (arguments == null) {
                result.error("invalid_request", "Missing patch request", null)
                return@setMethodCallHandler
            }
            worker.execute { runPatcher(arguments, result) }
        }
    }

    private fun runPatcher(request: Map<*, *>, result: MethodChannel.Result) {
        try {
            val runtime = extractRubyRuntime()
            val argv = mutableListOf(
                "-c", requiredString(request, "gamePath"),
                "-i", requiredString(request, "translationPath"),
            )
            if (request["forceDecrypt"] == true) argv += "--force-decrypt"
            @Suppress("UNCHECKED_CAST")
            (request["mods"] as? List<String>).orEmpty().forEach { mod ->
                argv += listOf("--mod", mod)
            }

            val ruby = ScriptingContainer(LocalContextScope.SINGLETHREAD, LocalVariableBehavior.PERSISTENT)
            val progress = ProgressOutputStream { line ->
                runOnUiThread { channel.invokeMethod("progress", line) }
            }
            ruby.output = progress
            ruby.error = progress
            ruby.currentDirectory = runtime.absolutePath
            ruby.setArgv(argv.toTypedArray())
            ruby.runScriptlet(PathType.ABSOLUTE, File(runtime, "VXAceTranslator.rb").absolutePath)
            ruby.terminate()
            runOnUiThread { result.success(null) }
        } catch (error: Throwable) {
            runOnUiThread { result.error("patch_failed", error.message, error.stackTraceToString()) }
        }
    }

    private fun requiredString(request: Map<*, *>, key: String): String =
        request[key] as? String ?: throw IllegalArgumentException("Missing $key")

    private fun extractRubyRuntime(): File {
        val destination = File(filesDir, "ruby/vxace")
        copyAssetTree("vxace", destination)
        return destination
    }

    private fun copyAssetTree(assetPath: String, destination: File) {
        val children = assets.list(assetPath).orEmpty()
        if (children.isNotEmpty()) {
            destination.mkdirs()
            children.forEach { child -> copyAssetTree("$assetPath/$child", File(destination, child)) }
            return
        }
        destination.parentFile?.mkdirs()
        assets.open(assetPath).use { input -> destination.outputStream().use(input::copyTo) }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }
}

private class ProgressOutputStream(private val emit: (String) -> Unit) : OutputStream() {
    private val buffer = StringBuilder()

    override fun write(value: Int) {
        val char = value.toChar()
        if (char == '\n') flush() else if (char != '\r') buffer.append(char)
    }

    override fun flush() {
        if (buffer.isNotEmpty()) {
            emit(buffer.toString())
            buffer.clear()
        }
    }
}
