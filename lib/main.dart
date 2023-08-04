import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'map_widget/map_params.dart';
import 'map_widget/map_widget.dart';
import 'panorama_widget/panorama_widget.dart';

void main() {
  runApp(const PeakTap());
}

class PeakTap extends StatelessWidget {
  const PeakTap({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeakTap',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(title: 'Interactive Mountain Panoramas'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  LatLng? _position;
  final toMap = StreamController<MapParams>.broadcast();
  final fromMap = StreamController<MapParams>();
  final toPanorama = StreamController<MapParams>.broadcast();
  final fromPanorama = StreamController<MapParams>();

  @override
  void initState() {
    super.initState();

    fromMap.stream.listen((event) {
      event.isLocationViewpoint((loc) {
        toPanorama.add(event);
        setState(() {
          _position = loc;
          // _position =
          //     "${loc.latitude.toStringAsFixed(4)} / ${loc.longitude.toStringAsFixed(4)}";
        });
      });
    });

    fromPanorama.stream.listen((event) {
      toMap.add(event);
    });

    Future.microtask(() async {
      var gpsPosition = await _determinePosition();
      setState(() {
        _position = LatLng(gpsPosition.latitude, gpsPosition.longitude);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  'Current position:',
                ),
                Text(
                  _position != null
                      ? _position!.toSexagesimal()
                      : "Searching GPS",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ]),
            ),
            Expanded(
              child: MapWidget(toMap.stream, fromMap.sink, _position),
            ),
            Expanded(
              flex: 0,
              child: _HorizontalButtonRow(toMap.sink, toPanorama.sink),
            ),
            Expanded(
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: PanoramaWidget(
                  toPanorama: toPanorama.stream,
                  fromPanorama: fromPanorama.sink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalButtonRow extends StatefulWidget {
  final Sink<MapParams> toMap;
  final Sink<MapParams> toPanorama;

  const _HorizontalButtonRow(this.toMap, this.toPanorama, {super.key});

  @override
  _HorizontalButtonRowState createState() => _HorizontalButtonRowState();
}

class _HorizontalButtonRowState extends State<_HorizontalButtonRow> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              Future.microtask(() async {
                var position = await _determinePosition();
                widget.toMap.add(MapParams.sendLocationViewpoint(
                    LatLng(position.latitude, position.longitude)));
              });
            },
            child: const Text('Update GPS'),
          )
        ],
      ),
    );
  }
}

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}
