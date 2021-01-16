package de.kevlatus.flutter_broadcasts

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CustomBroadcastReceiver(
        val id: Int,
        private val names: List<String>,
        private val listener: (Any) -> Unit
) : BroadcastReceiver() {
    companion object {
        const val TAG: String = "CustomBroadcastReceiver"
    }

    private val intentFilter: IntentFilter by lazy {
        val intentFilter = IntentFilter()
        names.forEach { intentFilter.addAction(it) }
        intentFilter
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d(TAG, "received intent " + intent?.action)
        intent?.let {
            val bundle = it.extras
            listener(mapOf(
                    "receiverId" to id,
                    "name" to it.action!!,
                    "data" to (bundle?.keySet()?.map { key -> Pair(key, bundle.get(key)) })?.toMap()
            ))
        }
    }

    fun start(context: Context) {
        context.registerReceiver(this, intentFilter)
    }

    fun stop(context: Context) {
        context.unregisterReceiver(this)
    }
}

class BroadcastManager(private val applicationContext: Context) {
    companion object {
        const val TAG: String = "BroadcastManager"
    }

    private var receivers: Map<Int, CustomBroadcastReceiver> = mapOf()

    fun startReceiver(receiver: CustomBroadcastReceiver) {
        Log.d(TAG, "starting receiver " + receiver.id.toString())
        // TODO: handle case when receiver exists
        receiver.start(applicationContext)
        receivers = receivers + Pair(receiver.id, receiver)
    }

    fun stopReceiver(id: Int) {
        Log.d(TAG, "stopping receiver $id")
        // TODO: handle non-existing case
        receivers[id]?.stop(applicationContext)
        receivers = receivers.filter { it.key != id }
    }

    fun stopAll() {
        receivers.forEach { it.value.stop(applicationContext) }
    }
}

class MethodCallHandlerImpl(private val broadcastManager: BroadcastManager) : MethodCallHandler {
    companion object {
        const val TAG: String = "MethodCallHandlerImpl"
    }

    private var channel: MethodChannel? = null

    private fun withReceiverArgs(
            call: MethodCall,
            result: Result,
            func: (id: Int, names: List<String>) -> Unit
    ) {
        val id = call.argument<Int>("id")
                ?: return result.error("1", "no receiver id provided", null)

        val names = call.argument<List<String>>("names")
                ?: return result.error("1", "no names provided", null)

        func(id, names)
    }

    private fun onStartReceiver(call: MethodCall, result: Result) {
        withReceiverArgs(call, result) { id, names ->
            broadcastManager.startReceiver(CustomBroadcastReceiver(id, names) { broadcast ->
                channel?.invokeMethod("receiveBroadcast", broadcast)
            })
            result.success(null)
        }
    }

    private fun onStopReceiver(call: MethodCall, result: Result) {
        withReceiverArgs(call, result) { id, _ ->
            broadcastManager.stopReceiver(id)
            result.success(null)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "received method call " + call.method)
        when (call.method) {
            "startReceiver" -> {
                onStartReceiver(call, result)
            }
            "stopReceiver" -> {
                onStopReceiver(call, result)
            }
        }
    }

    fun startListening(messenger: BinaryMessenger) {
        if (channel != null) {
            Log.wtf(TAG, "Setting a method call handler before the last was disposed.")
            stopListening()
        }

        channel = MethodChannel(messenger, "de.kevlatus.flutter_broadcasts")
        channel!!.setMethodCallHandler(this)
    }

    fun stopListening() {
        if (channel == null) {
            Log.d(TAG, "Tried to stop listening when no MethodChannel had been initialized.");
            return;
        }

        channel!!.setMethodCallHandler(null);
        channel = null;
    }
}

class FlutterBroadcastsPlugin : FlutterPlugin {
    companion object {
        const val TAG: String = "FlutterBroadcastsPlugin"
    }

    private var methodCallHandler: MethodCallHandlerImpl? = null
    private var broadcastManager: BroadcastManager? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        broadcastManager = BroadcastManager(flutterPluginBinding.applicationContext)
        methodCallHandler = MethodCallHandlerImpl(broadcastManager!!)
        methodCallHandler!!.startListening(flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        if (methodCallHandler == null) {
            Log.wtf(TAG, "Already detached from engine.")
            return
        }
        methodCallHandler!!.stopListening()
        methodCallHandler = null
        broadcastManager?.stopAll()
        broadcastManager = null
    }
}

