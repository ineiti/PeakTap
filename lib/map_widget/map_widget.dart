import 'dart:async';

import 'package:flutter/material.dart';

import 'map_widget_stub.dart'
if (dart.library.html) 'web_map_widget.dart'
if (dart.library.io) 'mob_map_widget.dart';

class MapParams {
  List<double>? location;
}

abstract class MapWidget extends StatefulWidget {
  factory MapWidget(Stream<MapParams> to, Sink<MapParams> from) =>
      getMapWidget(to, from);
}
