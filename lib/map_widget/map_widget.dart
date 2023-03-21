import 'dart:async';

import 'package:flutter/material.dart';

import 'map_widget_stub.dart'
    if (dart.library.html) 'web_map_widget.dart'
    if (dart.library.io) 'mob_map_widget.dart';

enum LocationUsage {
  none,
  viewPoint,
  pointOfInterest,
  viewAngle,
}

class MapParams {
  List<double>? location;
  LocationUsage usage = LocationUsage.none;
  bool? setupFinish;
  List<double>? viewAngle;
  List<List<double>>? horizon;

  void isLocation(LocationUsage u, void Function(List<double> loc) useIt) {
    if (location != null && usage == u) {
      useIt(location!);
    }
  }

  void isLocationViewpoint(void Function(List<double> loc) useIt) {
    isLocation(LocationUsage.viewPoint, useIt);
  }

  void isLocationPOI(void Function(List<double> loc) useIt) {
    isLocation(LocationUsage.pointOfInterest, useIt);
  }

  void isSetupFinish(void Function() useIt) {
    if (setupFinish != null) {
      useIt();
    }
  }

  void isViewAngle(void Function(double direction, double width) useIt) {
    if (viewAngle?.length == 2) {
      useIt(viewAngle![0], viewAngle![1]);
    }
  }

  void isHorizon(void Function(List<List<double>>) useIt){
    if (horizon != null){
      useIt(horizon!);
    }
  }

  static MapParams sendLocation(List<double> loc, LocationUsage u) {
    return MapParams()
      ..location = loc
      ..usage = u;
  }

  static MapParams sendLocationViewpoint(List<double> loc) {
    return sendLocation(loc, LocationUsage.viewPoint);
  }

  static MapParams sendLocationPOI(List<double> loc) {
    return sendLocation(loc, LocationUsage.pointOfInterest);
  }

  static MapParams sendSetupFinish() {
    return MapParams()..setupFinish = true;
  }

  static MapParams sendViewAngle(double direction, double width){
    return MapParams()..viewAngle = [direction, width];
  }

  static MapParams sendHorizon(List<List<double>> h){
    return MapParams()..horizon = h;
  }
}

abstract class MapWidget extends StatefulWidget {
  factory MapWidget(
          Stream<MapParams> to, Sink<MapParams> from, List<double> origin) =>
      getMapWidget(to, from, origin);
}
