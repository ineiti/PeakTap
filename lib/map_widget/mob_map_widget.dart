import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_widget.dart';

MapWidget getMapWidget(Stream<MapParams> to, Sink<MapParams> from) => MobileMap();

class MobileMap extends StatefulWidget implements MapWidget {
  MobileMap({Key? key}) : super(key: key);

  @override
  State<MobileMap> createState() => MobileMapState();
}

class MobileMapState extends State<MobileMap> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kFalentexHouse =
  CameraPosition(target: LatLng(44.497858579692135, 11.336362079086408));

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      mapType: MapType.hybrid,
      initialCameraPosition: _kFalentexHouse,
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
      },
      myLocationEnabled: true,
    );
  }
}