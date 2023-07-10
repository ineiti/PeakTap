import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mountain_panorama/elevation/elevation.dart';

import 'map_widget/map_params.dart';
import 'panorama/panorama.dart';

class Panorama extends StatefulWidget {
  const Panorama(
      {super.key, required this.toPanorama, required this.fromPanorama});

  final Stream<MapParams> toPanorama;
  final Sink<MapParams> fromPanorama;

  @override
  State<Panorama> createState() => PanoramaState();
}

// The PanoramaWidget either shows the panorama and sends the Horizon to the
// map, or shows a zoomed-in version of the panorama and sends POIs to the map.
enum DisplayState { horizon, poi }

class PanoramaState extends State<Panorama> {
  var empty = Image.asset("assets/empty.png");
  HeightProfileProvider? heightProfile;
  PanoramaImageBuilder? piBuilder;
  PanoramaImage? pImage;
  _PIUI? _piUI;
  final GlobalKey _widgetKey = GlobalKey();
  final imgHeight = 256;
  final tapTime = 200;
  TapDownDetails? tapPos;
  int? down;

  @override
  Widget build(BuildContext context) {
    Size size = const Size(0, 0);
    if (_widgetKey.currentContext != null) {
      size = (_widgetKey.currentContext!.findRenderObject() as RenderBox).size;
    }
    Widget mapImage = empty;
    if (pImage != null) {
      _piUI ??= _PIUI(widget.fromPanorama, pImage!, size);
      mapImage = _piUI!.getImage();
    }
    return GestureDetector(
        onTapDown: (tap) {
          tapPos = tap;
          down = DateTime.now().millisecondsSinceEpoch;
        },
        onTapUp: (tap) {
          if (DateTime.now().millisecondsSinceEpoch - down! <= tapTime) {
            setState(() {
              _piUI?.tap(tapPos!.localPosition);
            });
          }
        },
        child: Listener(
          key: _widgetKey,
          onPointerMove: (update) {
            _updateOffset(-update.delta);
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _updateOffset(signal.scrollDelta);
            }
          },
          child: mapImage,
        ));
  }

  void _updateOffset(Offset off) {
    if (DateTime.now().millisecondsSinceEpoch - down! > tapTime) {
      setState(() {
        _piUI?.updateOffset(off);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      heightProfile = await HeightProfileProvider.withAppDir();
      piBuilder = PanoramaImageBuilder(heightProfile!);
      widget.toPanorama.listen((event) {
        event.isLocationViewpoint((loc) async {
          var pi = await piBuilder?.drawPanorama(imgHeight, loc);
          setState(() {
            pImage = pi;
            _piUI = null;
          });
        });
      });
      widget.fromPanorama.add(MapParams.sendSetupFinish());
    });
  }
}

class _OffsetImage extends CustomPainter {
  _OffsetImage(this.piUI);

  final _PIUI piUI;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(piUI.pImage.map, piUI.getViewRect(),
        const Offset(0, 0) & size, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class _PIUI {
  final PanoramaImage pImage;
  final Size size;
  int widthPlusScreen;
  DisplayState shown = DisplayState.horizon;
  Offset offset = const Offset(0, 0);
  final Sink<MapParams> fromPanorama;

  _PIUI(this.fromPanorama, this.pImage, this.size)
      : widthPlusScreen = pImage.reverse[0].length +
            size.width * pImage.reverse.length ~/ size.height;

  CustomPaint getImage() {
    // print("Building with offset ${pImage?.off}");
    switch (shown) {
      case DisplayState.horizon:
        fromPanorama.add(MapParams.sendHorizon(_getHorizon()));
        return CustomPaint(painter: _OffsetImage(this));
      case DisplayState.poi:
        return CustomPaint(painter: _OffsetImage(this));
    }
  }

  ui.Rect getViewRect() {
    double zoom = 1;
    // if (shown == DisplayState.poi) {
    //   zoom = 2;
    // }
    var r = ui.Rect.fromCenter(
        center: ui.Offset(_imgCenterView(), _height() / 2),
        width: _imgViewWidth() / zoom,
        height: _height().toDouble() / zoom);
    return r;
  }

  tap(Offset tapOff) {
    switch (shown) {
      case DisplayState.horizon:
        shown = DisplayState.poi;
        final pos = _firstPanoramaPoint(tapOff);
        final posOff = Offset(tapOff.dx, pos.$2.toDouble() * _imgViewFactor());
        updateOffset(posOff - _center());
        break;
      case DisplayState.poi:
        shown = DisplayState.horizon;
        offset = Offset(offset.dx, 0);
        break;
    }
  }

  updateOffset(Offset off) {
    print("Updating offset $off for $shown");
    switch (shown) {
      case DisplayState.horizon:
        _updateHorizonOffset(off.dx);
        break;
      case DisplayState.poi:
        offset += off;
        fromPanorama.add(MapParams.sendLocationPOI(_toLatLng(_center())));
        break;
    }
  }

  _updateHorizonOffset(double dx) {
    offset = Offset((offset.dx + dx) % widthPlusScreen, offset.dy);
    // print("New offset: $offset - image width: $widthPlusScreen");
  }

  List<LatLng> _getHorizon() {
    List<LatLng> horizon = [];
    var imgOffset = offset.dx ~/ _imgViewFactor();
    var end = ((imgOffset + _imgViewWidth()) % _width()).toInt();
    for (var dx = imgOffset % _width(); dx != end; dx = (dx + 1) % _width()) {
      // print("dx: $dx - $offset - ${width()}");
      for (var y = 0; y < _height(); y++) {
        // print("y: $y");
        if (dx >= pImage.reverse[y].length) {
          print("Dx overflow: $dx - ${_width()} - ${pImage.reverse[y].length}");
        }
        var c = pImage.reverse[y][dx.toInt()];
        if (c != null) {
          horizon.add(c);
          break;
        }
      }
    }
    return horizon;
  }

  (int, int) _firstPanoramaPoint(Offset pos) {
    final mapX = ((offset.dx + pos.dx)) ~/ _imgViewFactor() % _width();
    final mapY = pos.dy ~/ _imgViewFactor();
    for (var y = mapY; y < _height(); y++) {
      if (pImage.reverse[y][mapX] != null) {
        return (mapX, y);
      }
    }
    print(
        "Searched at $mapX / $mapY for ${pImage.reverse[0].length} / ${pImage.reverse.length}");
    throw ("Didn't manage to find land");
  }

  LatLng _toLatLng(ui.Offset pos) {
    final p = _firstPanoramaPoint(pos);
    return pImage.reverse[p.$2][p.$1]!;
  }

  Offset _center() {
    return size.center(Offset.zero);
  }

  int _width() {
    return pImage.reverse[0].length;
  }

  int _height() {
    return pImage.reverse.length;
  }

  double _imgViewFactor() => size.height / _height();

  double _imgViewWidth() => size.width / _imgViewFactor();

  double _imgCenterView() => _imgViewWidth() / 2 + offset.dx / _imgViewFactor();
}
