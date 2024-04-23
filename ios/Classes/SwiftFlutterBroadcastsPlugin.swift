import Flutter
import UIKit

public class SwiftFlutterBroadcastsPlugin: NSObject, FlutterPlugin {
    enum ExternalCall: String {
        case receiveBroadcast
    }
    enum SupportedCall: String {
        case startReceiver, stopReceiver, sendBroadcast
    }
    enum ReceiverArgument: String {
        case id, names
    }
    enum BroadcastArgument: String {
        case name, data
    }
    
    typealias NameDataHandler = (_ name: String, _ data: [String: Any]) -> Void
    typealias IdNamesHandler = (_ id: Int, _ names: [String]) -> Void
    
    private static var broadcastManager: BroadcastManager?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "de.kevlatus.flutter_broadcasts", binaryMessenger: registrar.messenger())
        
        broadcastManager = BroadcastManager(channel: channel)
        
        let instance = SwiftFlutterBroadcastsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let supportedCall = SupportedCall(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        switch supportedCall {
        case .startReceiver:
            onStartReceiver(call: call, result: result)
        case .stopReceiver:
            onStopReceiver(call: call, result: result)
        case .sendBroadcast:
            onSendBroadcast(call: call, result: result)
        }
    }
    
    private func withReceiverArgs(
        _ call: FlutterMethodCall,
        _ result: @escaping FlutterResult,
        handler: IdNamesHandler) {
            guard let args = call.arguments as? [String: Any],
                  let id = args[ReceiverArgument.id.rawValue] as? Int else {
                result("no receiver <\(ReceiverArgument.id.rawValue)> provided")
                return
            }
            guard let names = args[ReceiverArgument.names.rawValue] as? [String] else {
                result("no receiver <\(ReceiverArgument.names.rawValue)> provided")
                return
            }
            handler(id, names)
        }
    
    private func withBroadcastArgs(
        _ call: FlutterMethodCall,
        _ result: @escaping FlutterResult,
        handler: NameDataHandler){
            guard let args = call.arguments as? [String: Any],
                  let name = args[BroadcastArgument.name.rawValue] as? String else {
                result("No broadcast <\(BroadcastArgument.name.rawValue)> provided")
                return
            }
            let data = args[BroadcastArgument.data.rawValue] as? [String: Any] ?? [:]
            handler(name, data)
        }
    
    private func onStartReceiver(call: FlutterMethodCall, result: @escaping FlutterResult) {
        withReceiverArgs(call, result) { id, names in
            Self.broadcastManager?.startReceiver(CustomBroadcastReceiver(id: id, names: names))
            result(nil)
        }
    }
    
    private func onStopReceiver(call: FlutterMethodCall, result: @escaping FlutterResult) {
        withReceiverArgs(call, result) { id, _ in
            Self.broadcastManager?.stopReceiver(with: id)
            result(nil)
        }
    }
    
    private func onSendBroadcast(call: FlutterMethodCall, result: @escaping FlutterResult) {
        withBroadcastArgs(call, result) { name, data in
            Self.broadcastManager?.sendBroadcast(name: name, data: data)
            result(nil)
        }
    }
}

class CustomBroadcastReceiver {
    let id: Int
    let names: [String]
    let handlers: [Any]
    
    init(id: Int, names: [String], handlers: [Any] = []) {
        self.id = id
        self.names = names
        self.handlers = handlers
    }
}

class BroadcastManager {
    enum BroadcastKeys: String {
        case receiverId, name, data
    }
    
    let channel: FlutterMethodChannel
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }
    
    private var receivers: [Int: CustomBroadcastReceiver] = [:]
    
    func startReceiver(_ receiver: CustomBroadcastReceiver) {
        var handlers: [Any] = []
        for name in receiver.names {
            let handler = NotificationCenter.default.addObserver(forName: Notification.Name(name), object: nil, queue: nil) { [weak self] note in
                self?.channel.invokeMethod(SwiftFlutterBroadcastsPlugin.ExternalCall.receiveBroadcast.rawValue, arguments: note.userInfo as? [String: Any])
            }
            handlers.append(handler)
        }
        receivers[receiver.id] = CustomBroadcastReceiver(id: receiver.id, names: receiver.names, handlers: handlers)
    }
    
    func stopReceiver(with id: Int) {
        guard let receiver = receivers[id] else {
            return
        }
        for handler in receiver.handlers {
            NotificationCenter.default.removeObserver(handler)
        }
        receivers[id] = nil
    }
    
    func stopAll() {
        for id in receivers.keys {
            stopReceiver(with: id)
        }
    }
    
    func sendBroadcast(name: String, data: [String: Any]) {
        guard let receiver = receivers.values.first(where: { $0.names.contains(name) }) else {
            return
        }
        let info: [String: Any] = [
            BroadcastKeys.receiverId.rawValue: receiver.id,
            BroadcastKeys.name.rawValue: name,
            BroadcastKeys.data.rawValue: data,
        ]
        NotificationCenter.default.post(name: Notification.Name(name), object: nil, userInfo: info)
    }
}
