part of 'flutter_broadcasts.dart';

/// Allows for subscribing to [BroadcastMessage]s on the native platform.
///
/// The API is inspired by Android's [BroadcastReceiver](https://developer.android.com/reference/android/content/BroadcastReceiver),
/// since they allow for _bundling_ multiple message types into a single
/// receiver instead of subscribing to them individually.
///
/// On iOS, this uses the [NSNotificationCenter API](https://developer.apple.com/documentation/foundation/notificationcenter).
class BroadcastReceiver {
  static int _index = 0;

  final int _id;
  Stream<BroadcastMessage> _messages;

  /// A list of message names to subscribe to.
  ///
  /// See [BroadcastMessage.name] for more details.
  final List<String> names;

  /// Creates a new [BroadcastReceiver], which subscribes to the given [names].
  ///
  /// At least one name needs to be provided.
  BroadcastReceiver({@required this.names})
      : assert(names != null && names.length > 0),
        _id = ++_index;

  /// A stream of matching messages received from the native platform.
  ///
  /// If this [BroadcastReceiver] is stopped, this returns [Stream.empty].
  Stream<BroadcastMessage> get messages =>
      _messages ?? Stream<BroadcastMessage>.empty();

  /// Returns true, if this [BroadcastReceiver] is currently listening for messages.
  bool get isStarted => _messages != null;

  /// Starts listening for messages on this [BroadcastReceiver].
  ///
  /// Throws a [StateError], if it is already listening.
  Future<void> start() async {
    if (isStarted) {
      throw StateError('This BroadcastReceiver is already started.');
    }

    _messages = _BroadcastChannel.instance.startReceiver(this);
  }

  /// Stops listening for messages on this [BroadcastReceiver].
  ///
  /// Throws a [StateError], if it is not yet listening.
  Future<void> stop() async {
    if (!isStarted) {
      throw StateError('This BroadcastReceiver is not yet started.');
    }

    await _BroadcastChannel.instance.stopReceiver(this);
    _messages = null;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': _id,
        'names': names,
      };

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  int get hashCode => hash3(_id, names, _messages);

  @override
  bool operator ==(Object other) {
    return other is BroadcastReceiver &&
        other._id == _id &&
        other.names == names &&
        other._messages == _messages;
  }
}
