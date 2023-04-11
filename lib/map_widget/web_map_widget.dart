import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  int? lastClick;
  final Set<Polygon> _polygon = HashSet<Polygon>();
  final Map<MarkerId, Marker> _markers = {};
  final _markerCenter = const MarkerId('0');
  final _markerView = const MarkerId('1');
  late GoogleMapController _controller;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.origin,
        zoom: 10,
      ),
      polygons: _polygon,
      markers: _markers.values.toSet(),
      onMapCreated: _onMapCreated,
      onTap: _onMapTap,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _onMapTap(widget.origin);
  }

  void _onMapTap(LatLng newPosition) {
    setState(() {
      _markers[_markerCenter] = Marker(
        markerId: MarkerId('center_${DateTime.now().millisecondsSinceEpoch}'),
        position: newPosition,
      );
    });
    _controller.animateCamera(CameraUpdate.newLatLng(newPosition));
    Future.delayed(const Duration(milliseconds: 150), () {
      sendLocation(newPosition);
    });
  }

  void sendLocation(LatLng pos) {
    // if (marker != null && marker?.position != null) {
    //   var pos = marker!.position!;
    widget.fromMap.add(MapParams.sendLocationViewpoint(
        [pos.latitude.toDouble(), pos.longitude.toDouble()]));
    // }
  }

  void setPOI(LatLng pos) {
    setState(() {
      _markers[_markerView] = Marker(
        markerId: MarkerId('view_${DateTime.now().millisecondsSinceEpoch}'),
        position: pos,
      );
    });
  }

  void setPolygon(List<List<double>> poly) {
    List<LatLng> points = poly.map((e) => LatLng(e[0], e[1])).toList();
    setState(() {
      //initialize polygon
      _polygon.add(Polygon(
        // given polygonId
        polygonId: const PolygonId('1'),
        // initialize the list of points to display polygon
        points: points,
        // given color to polygon
        fillColor: Colors.green.withOpacity(0.3),
        // given border color to polygon
        strokeColor: Colors.green,
        geodesic: true,
        // given width of border
        strokeWidth: 4,
      ));
    });
  }

  @override
  void initState() {
    super.initState();

    widget.toMap.listen((event) {
      event.isLocationPOI((loc) {
        setPOI(LatLng(loc[0], loc[1]));
      });
      event.isViewAngle((direction, width) {
        var m = _markers[_markerCenter]?.position;
        if (m != null) {
          var x = m.latitude, y = m.longitude;
          var s = 0.1,
              start = direction - width / 2,
              stop = direction + width / 2;
          setPolygon([
            [x, y],
            [x + s * cos(start), y + s * sin(start)],
            [x + s * cos(stop), y + s * sin(stop)],
            [x, y]
          ]);
        }
      });
      event.isHorizon((horizon) {
        var m = _markers[_markerCenter]?.position;
        if (m != null) {
          horizon.insert(0, [m.latitude, m.longitude]);
          horizon.add([m.latitude, m.longitude]);
          setPolygon(horizon);
        }
      });
    });
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
}

final rnd = Random();

class WebMapState2 extends State<WebMap> {
  // We use this value to paint new Markers close to the center of the last movement of the map.
  // Updates to this don't need to call setState, this is just a value that we care about some times.
  LatLng _center = LatLng(40.416775, -3.703790);

  // Will be updated when we tap on the map, or on the fAB.
  // Updates to this must call setState, so the GoogleMap gets re-painted.
  Map<MarkerId, Marker> _markers = {
    MarkerId('0'): Marker(
        markerId: MarkerId('madrid_initial'),
        position: LatLng(40.416775, -3.703790)),
  };

  // Will be initialized later by the [_onMapCreated] function.
  late GoogleMapController _controller;

  // This jitters a double a little bit, according to `scale`.
  // `scale` limits at which decimal point will the random function apply:
  // 0.00000001 -> tiny changes, 1.0 -> potentially large changes!
  double _jitterDouble(double val, double scale) {
    final min = val - (val * scale);
    final max = val + (val * scale);
    return rnd.nextDouble() * (max - min) + min;
  }

  // Jitters the lat/lng of a position, according to `scale`.
  LatLng _jitterPosition(LatLng position, double scale) {
    return LatLng(_jitterDouble(position.latitude, scale),
        _jitterDouble(position.longitude, scale));
  }

  // Creates a marker with a unique variation on a `MarkerId`, around a given `position`.
  Marker _timestampedMarker(MarkerId id, LatLng position) {
    return Marker(
      markerId:
          MarkerId('${id.value}_${DateTime.now().millisecondsSinceEpoch}'),
      // markerId: MarkerId('${id.value}_${DateTime.now().millisecondsSinceEpoch}'),
      position: _jitterPosition(position,
          0.002), // Jitter so not all markers fall in the same center...
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
  }

  void _onMapTap(LatLng newPosition) {
    // For each marker, move it close to the latLng of the click...
    setState(() {
      _markers.forEach((markerId, marker) {
        _markers[markerId] = Marker(
            markerId: MarkerId(
                "${markerId.value}_${DateTime.now().millisecondsSinceEpoch}"),
            position: newPosition);
        // _markers[markerId] = _timestampedMarker(markerId, newPosition);
        // When the Marker position bug is fixed, this can be replaced by:
        // _markers[markerId] = marker.copyWith(positionParam: _jitterPosition(newPosition));
      });
    });
    // // Center the camera where the user clicked after a few milliseconds...
    // Future.delayed(Duration(milliseconds: 150), () {
    //   _controller.animateCamera(CameraUpdate.newLatLng(newPosition));
    // });
  }

  // Adds a marker near the `_center` of the map.
  void _addMarker() {
    setState(() {
      // Add a new marker to the set of markers available...
      final MarkerId id = MarkerId('${_markers.length}');
      _markers[id] = _timestampedMarker(id, _center);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _center,
        zoom: 10,
      ),
      zoomControlsEnabled: false,
      minMaxZoomPreference: MinMaxZoomPreference(10, 10),
      markers: _markers.values.toSet(),
      onMapCreated: _onMapCreated,
      onTap: _onMapTap,
      onCameraMove: _onCameraMove,
    );
  }
}
