import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  BroadcastReceiver receiver = BroadcastReceiver(
    names: <String>[
      "com.spotify.music.playbackstatechanged",
    ],
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Broadcasts Demo'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                child: Text('Toggle Spotify Receiver'),
                onPressed: () {
                  if (receiver.isStarted) {
                    receiver.stop();
                  } else {
                    receiver.start();
                  }
                  setState(() {});
                },
              ),
              StreamBuilder<BroadcastMessage>(
                initialData: null,
                stream: receiver.messages,
                builder: (context, snapshot) {
                  print(snapshot.data);
                  switch (snapshot.connectionState) {
                    case ConnectionState.active:
                      return Text(
                          'Now playing: ${snapshot.data.data['track']}');

                    case ConnectionState.none:
                    case ConnectionState.done:
                    case ConnectionState.waiting:
                    default:
                      return SizedBox();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
