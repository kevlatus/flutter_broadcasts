import 'package:flutter/material.dart';
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
      "de.kevlatus.flutter_broadcasts_example.demo_action",
    ],
  );

  @override
  void initState() {
    super.initState();
    receiver.start();
    receiver.messages.listen(print);
  }

  @override
  void dispose() {
    receiver.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Broadcasts Demo'),
        ),
        body: Column(
          children: [
            TextButton(
              child: Text('Send Broadcast'),
              onPressed: () {
                sendBroadcast(
                  BroadcastMessage(
                    name: "de.kevlatus.flutter_broadcasts_example.demo_action",
                  ),
                );
              },
            ),
            StreamBuilder<BroadcastMessage>(
              initialData: null,
              stream: receiver.messages,
              builder: (context, snapshot) {
                print(snapshot.data);
                switch (snapshot.connectionState) {
                  case ConnectionState.active:
                    return Text(snapshot.data?.name ?? '');

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
    );
  }
}
