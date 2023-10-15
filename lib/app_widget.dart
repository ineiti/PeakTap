import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'map_widget/map_params.dart';
import 'map_widget/map_widget.dart';
import 'panorama_widget/panorama_widget.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key, required this.title});

  final String title;

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

enum MainMsg {
  updateGPS,
  repaint,
}

class _AppWidgetState extends State<AppWidget> {
  LatLng? _position;
  final toMap = StreamController<MapParams>.broadcast();
  final fromMap = StreamController<MapParams>();
  final toPanorama = StreamController<MapParams>.broadcast();
  final fromPanorama = StreamController<MapParams>.broadcast();
  final toMain = StreamController<MainMsg>();

  @override
  void initState() {
    super.initState();

    fromMap.stream.listen((event) {
      event.isLocationViewpoint((loc) {
        _updatePosition(context, loc);
      });
    });

    fromPanorama.stream.listen((event) {
      toMap.add(event);
    });

    toMain.stream.listen((event) {
      Future.microtask(() async {
        switch (event) {
          case MainMsg.updateGPS:
            _updatePosition(context);
            break;
          case MainMsg.repaint:
            _updatePosition(context,
                LatLng(_position!.latitude + 0.0001, _position!.longitude));
            break;
        }
      });
    });

    // TODO: this is ugly: how to call _updatePosition only after the first build?
    Future.delayed(const Duration(milliseconds: 150), () {
      _updatePosition(context);
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
              child: MapWidget(toMap.stream, fromMap.sink),
            ),
            Expanded(
              flex: 0,
              child: _HorizontalButtonRow(toMain.sink),
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

  void _updatePosition(BuildContext context, [LatLng? newPosition]) {
    final updateDialog = StreamController<void>.broadcast();
    var textStr = newPosition == null ? 'Fetching GPS' : 'Using new position';
    var textDownloadDone = "";
    var textPaint = "";
    var textDownloadProgress = "";
    var textException = "";

    Future.microtask(() async {
      if (newPosition == null) {
        var position = await _determinePosition();
        newPosition = LatLng(position.latitude, position.longitude);
        textStr += "\nLocked on GPS";
        updateDialog.sink.add(null);
      }
      final posParam = MapParams.sendLocationViewpoint(newPosition!);
      toMap.add(posParam);
      toPanorama.add(posParam);
      setState(() {
        _position = newPosition;
      });

      Completer<void> done = Completer();
      var listenerMap = toMap.stream.listen((event) {
        event.isHorizon((p0) {
          Navigator.of(context).pop();
          done.complete();
        });
      });
      var listenerPan = fromPanorama.stream.listen((event) {
        event.isDownloadStatus((msg) {
          if (msg.percentage == 100) {
            textDownloadDone += "\nDownloaded tile ${msg.name}";
            textDownloadProgress = "";
          } else {
            textDownloadProgress =
                "\nDownloading tile ${msg.name}: ${msg.percentage}%";
          }
        });
        event.isPaintingStatus((msg) {
          textPaint = "\nPainting progress: $msg%";
        });
        event.isException((p0) {
          textException = "\n$p0";
        });
        updateDialog.sink.add(null);
      });

      await done.future;
      listenerMap.cancel();
      listenerPan.cancel();
    });

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) {
          return Dialog(
            backgroundColor: Colors.white,
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              updateDialog.stream
                  .take(1)
                  .first
                  .then((value) => setState(() {}));
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(
                      height: 15,
                    ),
                    // Some text
                    Text(textStr +
                        textDownloadDone +
                        textPaint +
                        textDownloadProgress +
                        textException)
                  ],
                ),
              );
            }),
          );
        });
  }
}

class _HorizontalButtonRow extends StatefulWidget {
  final Sink<MainMsg> toMain;

  const _HorizontalButtonRow(this.toMain, {super.key});

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
    var buttons = [
      ElevatedButton(
        onPressed: () {
          widget.toMain.add(MainMsg.updateGPS);
        },
        child: const Text('Update GPS'),
      )
    ];
    if (kDebugMode) {
      buttons += [
        ElevatedButton(
          onPressed: () {
            widget.toMain.add(MainMsg.repaint);
          },
          child: const Text('Repaint'),
        )
      ];
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons,
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
