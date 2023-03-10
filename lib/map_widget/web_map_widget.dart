import 'dart:async';
import 'dart:html';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps/google_maps.dart';

import 'map_widget.dart';

MapWidget getMapWidget(Stream<MapParams> to, Sink<MapParams> from) =>
    WebMap(to_map: to, from_map: from);

class WebMap extends StatefulWidget implements MapWidget {
  const WebMap({super.key, required this.to_map, required this.from_map});

  final Stream<MapParams> to_map;
  final Sink<MapParams> from_map;

  @override
  State<WebMap> createState() => WebMapState();
}

class WebMapState extends State<WebMap> {
  Marker? marker;
  GMap? map;

  @override
  Widget build(BuildContext context) {
    final String htmlId = "map";

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(htmlId, (int viewId) {
      final mapOptions = MapOptions()
        ..zoom = 10.0
        ..center = LatLng(46.59, 6.31);

      final elem = DivElement()..id = htmlId;
      map = GMap(elem, mapOptions);

      map?.onCenterChanged.listen((event) {});
      map?.onDragstart.listen((event) {});
      map?.onDblclick.listen((event) {
        event.stop();
      });
      map?.onClick.listen((event) {
        if (map != null) {
          LatLng center = event.latLng!;
          widget.from_map.add(MapParams()
            ..location = [center.lat.toDouble(), center.lng.toDouble()]);
        }
      });

      marker ??= Marker(MarkerOptions()
        ..position = map?.center
        ..map = map);

      return elem;
    });
    return HtmlElementView(viewType: htmlId);
  }

  @override
  void initState() {
    super.initState();

    widget.to_map.listen((mp) {
      setState(() {
        if (mp.location != null) {
          map?.center =
              LatLng(mp.location?.elementAt(0), mp.location?.elementAt(1));
          marker?.position = map?.center;
        }
      });
    });
  }
}
