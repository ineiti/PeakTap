import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mountain_panorama/panorama/panorama.dart';
import 'map_widget/map_widget.dart';
import 'panorama_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MountainPanorama',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Showing Mountain Panoramas'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _position = "Unknown";
  var to_map = StreamController<MapParams>.broadcast();
  var from_map = StreamController<MapParams>();
  var to_panorama = StreamController<MapParams>.broadcast();
  var from_panorama = StreamController<MapParams>();

  @override
  void initState() {
    super.initState();

    from_map.stream.listen((event) {
      List<double> loc = event.location!;
      double lat = loc[0], lon = loc[1];
      to_map.add(event);
      to_panorama.add(event);
      setState(() {
        _position = "${lat.toStringAsFixed(4)} / ${lon.toStringAsFixed(4)}";
      });
    });

    to_map.add(MapParams()..location = [46.59, 6.31]);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Center(
              child: Column(children: <Widget>[
                const Text(
                  'You are currently here:',
                ),
                Text(
                  '$_position',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ]),
            ),
            Expanded(
              // height: 500,
              // width: 500,
              child: MapWidget(to_map.stream, from_map.sink),
            ),
            Expanded(
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: Panorama(
                  to_panorama: to_panorama.stream,
                  from_panorama: from_panorama.sink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
