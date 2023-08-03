import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_params.dart';

class MapWidget extends StatefulWidget {
  const MapWidget(this.toMap, this.fromMap, this._initialPosition, {super.key});

  final Stream<MapParams> toMap;
  final Sink<MapParams> fromMap;
  final LatLng? _initialPosition;

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  Marker? marker, poi;
  int? lastClick;
  final _polygon = <LatLng>[];

  LatLng? _markerCenter;
  LatLng? _markerPOI;

  final mapController = MapController();

  @override
  Widget build(BuildContext context) {
    _markerCenter ??= widget._initialPosition;
    if (_markerCenter == null) {
      return const Align(
          alignment: Alignment.center,
          child: Text(
            'Waiting for GPS',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ));
    } else {
      var markers = [
        Marker(
            point: _markerCenter!,
            builder: (context) =>
                const Image(image: AssetImage('assets/pin.png'))),
      ];
      if (_markerPOI != null) {
        markers.add(Marker(
          point: _markerPOI!,
          builder: (context) =>
              const Image(image: AssetImage('assets/binoculars.png')),
        ));
      }
      return FlutterMap(
        mapController: mapController,
        options: MapOptions(
          center: _markerCenter!,
          zoom: 10,
          onTap: _onMapTap,
          onMapReady: () {
            _setViewPoint(_markerCenter!);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'ch.ineiti.mountain_panorama',
          ),
          PolygonLayer(
            polygons: [
              Polygon(
                points: _polygon,
                color: Colors.green.withOpacity(0.3),
                isFilled: true,
                borderColor: Colors.green,
                borderStrokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: markers,
          ),
        ],
      );
    }
  }

  void _onMapTap(TapPosition? _pos, LatLng newPosition) {
    _setViewPoint(newPosition);
  }

  void _setViewPoint(LatLng newPosition) {
    setState(() {
      _markerCenter = newPosition;
      _markerPOI = null;
      _polygon.clear();
    });
    mapController.move(newPosition, mapController.zoom);
    Future.delayed(const Duration(milliseconds: 150), () {
      widget.fromMap.add(MapParams.sendLocationViewpoint(newPosition));
    });
  }

  void _setPOI(LatLng pos) {
    setState(() {
      _markerPOI = pos;
      mapController.move(pos, 15);
    });
  }

  void _setPolygon(List<LatLng> poly) {
    setState(() {
      //initialize polygon
      _polygon.clear();
      _polygon.addAll(poly);
    });
  }

  void _fitHorizon() {
    setState(() {
      var bounds = LatLngBounds.fromPoints(_polygon);
      // print("Bounds are: ${bounds.northWest} / ${bounds.southEast}");
      var cz = mapController.centerZoomFitBounds(bounds);
      mapController.move(cz.center, cz.zoom);
      _markerPOI = null;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.toMap.listen((event) {
      event.isLocationViewpoint((loc) {
        _setViewPoint(loc);
      });
      event.isLocationPOI((loc) {
        _setPOI(loc);
      });
      event.isHorizon((horizon) {
        if (_markerCenter != null) {
          final m = _markerCenter!;
          horizon.insert(0, m);
          horizon.add(m);
          _setPolygon(horizon);
        }
      });
      event.isFitHorizon(() {
        _fitHorizon();
      });
    });
  }
}
