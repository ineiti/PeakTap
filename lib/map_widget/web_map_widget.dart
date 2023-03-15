import 'dart:async';
import 'dart:html';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps/google_maps.dart';

import 'map_widget.dart';

MapWidget getMapWidget(
        Stream<MapParams> to, Sink<MapParams> from, List<double> origin) =>
    WebMap(toMap: to, fromMap: from, origin: LatLng(origin[0], origin[1]));

class WebMap extends StatefulWidget implements MapWidget {
  const WebMap(
      {super.key,
      required this.toMap,
      required this.fromMap,
      required this.origin});

  final Stream<MapParams> toMap;
  final Sink<MapParams> fromMap;
  final LatLng origin;

  @override
  State<WebMap> createState() => WebMapState();
}

class WebMapState extends State<WebMap> {
  Marker? marker, poi;
  GMap? map;
  int? lastClick;

  @override
  Widget build(BuildContext context) {
    final String htmlId = "map";

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(htmlId, (int viewId) {
      final mapOptions = MapOptions()
        ..zoom = 10.0
        ..center = widget.origin;

      final elem = DivElement()
        ..id = htmlId
        ..style.width = "100%"
        ..style.height = "100%"
        ..style.border = 'none';

      map = GMap(elem, mapOptions);
      map?.onZoomChanged.listen((event) {
        if (prevClick(false) < 2000) {
          map?.center = marker?.position;
        }
      });
      map?.onClick.listen((event) {
        if (map != null) {
          if (prevClick(true) < 2000) {
            return;
          }
          LatLng center = event.latLng!;
          setLocation([center.lat.toDouble(), center.lng.toDouble()]);
          sendLocation();
        }
      });

      marker ??= Marker(MarkerOptions()
        ..position = map?.center
        ..map = map);

      sendLocation();

      return elem;
    });
    return HtmlElementView(viewType: htmlId);
  }

  int prevClick(bool update) {
    var now = DateTime.now().millisecondsSinceEpoch;
    if (!update) {
      if (lastClick != null) {
        return now - lastClick!;
      } else {
        return now;
      }
    } else {
      var prevClick = lastClick;
      lastClick = now;
      if (prevClick != null) {
        return lastClick! - prevClick;
      }
      return lastClick!;
    }
  }

  void sendLocation() {
    if (marker != null && marker?.position != null) {
      var pos = marker!.position!;
      widget.fromMap.add(MapParams.sendLocationViewpoint(
          [pos.lat.toDouble(), pos.lng.toDouble()]));
    }
  }

  void setLocation(List<double> loc) {
    setState(() {
      map?.center = LatLng(loc[0], loc[1]);
      marker?.position = LatLng(loc[0], loc[1]);
    });
  }

  void setPOI(LatLng pos) {
    setState(() {
      print("Setting position to $pos");
      if (poi == null) {
        poi = Marker(MarkerOptions()
          ..position = pos
          ..map = map);
      } else {
        poi?.position = pos;
      }
    });
  }

  void setPolygon(List<List<double>> poly) {}

  @override
  void initState() {
    super.initState();

    widget.toMap.listen((event) {
      event.isLocationViewpoint((loc) {
        setLocation(loc);
      });
      event.isLocationPOI((loc) {
        setPOI(LatLng(loc[0], loc[1]));
      });
      event.isSetupFinish(() {
        sendLocation();
      });
    });
  }
}
