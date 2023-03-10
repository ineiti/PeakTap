import 'dart:async';

import 'package:flutter/material.dart';

import 'map_widget_stub.dart'
if (dart.library.html) 'web_map_widget.dart'
if (dart.library.io) 'mob_map_widget.dart';

class MapParams {
  List<double>? location;
  bool? setupFinish;

  void isLocation(void Function(List<double> loc) useIt){
    if (location != null){
      useIt(location!);
    }
  }

  void isSetupFinish(void Function() useIt){
    if (setupFinish != null){
      useIt();
    }
  }

  static MapParams sendLocation(List<double> loc){
    return MapParams()..location = loc;
  }

  static MapParams sendSetupFinish(){
    return MapParams()..setupFinish = true;
  }
}

abstract class MapWidget extends StatefulWidget {
  factory MapWidget(Stream<MapParams> to, Sink<MapParams> from, List<double> origin) =>
      getMapWidget(to, from, origin);
}
