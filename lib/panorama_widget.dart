import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mountain_panorama/elevation/elevation.dart';

import 'map_widget/map_params.dart';
import 'panorama/panorama.dart';

class PanoramaWidget extends StatefulWidget {
  const PanoramaWidget(
      {super.key, required this.toPanorama, required this.fromPanorama});

  final Stream<MapParams> toPanorama;
  final Sink<MapParams> fromPanorama;

  @override
  State<PanoramaWidget> createState() => PanoramaWidgetState();
}

// The PanoramaWidget either shows the panorama and sends the Horizon to the
// map, or shows a zoomed-in version of the panorama and sends POIs to the map.
enum DisplayState { horizon, poi }

class PanoramaWidgetState extends State<PanoramaWidget> {
  var empty = Image.asset("assets/empty.png");
  HeightProfileProvider? heightProfile;
  PanoramaImageBuilder? piBuilder;
  PanoramaImage? pImage;
  _PIUI? _piUI;
  Offset _oldOffset = Offset.zero;
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
    var showBinoculars = false;
    if (pImage != null) {
      _piUI ??= _PIUI(widget.fromPanorama, pImage!, size, _oldOffset);
      showBinoculars = _piUI!.isPOI();
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
          child: ClipPath(
            clipper: Binoculars(showBinoculars),
            child: mapImage,
          ),
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
        event.isLocationViewpoint((loc) {
          setState(() {
            pImage = null;
          });
          // TODO - create a better `drawPanorama` which returns
          // it's state while drawing and downloading parts of the
          // panorama.
          Future.delayed(const Duration(milliseconds: 150), () async {
            var pi = await piBuilder?.drawPanorama(imgHeight, loc);
            setState(() {
              pImage = pi;
              if (_piUI != null) {
                _oldOffset = _piUI!.mapOffset;
              }
              _piUI = null;
            });
          });
        });
      });
      widget.fromPanorama.add(MapParams.sendSetupFinish());
    });
  }
}

class Binoculars extends CustomClipper<ui.Path> {
  final bool _binoculars;
  final double _overlap = 0.4;
  final double _mult = 0.9;

  Binoculars(this._binoculars);

  @override
  ui.Path getClip(Size size) {
    ui.Path path = ui.Path();
    if (_binoculars) {
      var width = size.width / (2 - _overlap);
      var middle = size.height / 2;
      path.addOval(Rect.fromCenter(
          center: Offset(width / 2, middle),
          width: width * _mult,
          height: size.height * _mult));
      path.addOval(Rect.fromCenter(
          center: Offset(size.width - width / 2, middle),
          width: width * _mult,
          height: size.height * _mult));
    } else {
      path.addRect(Offset.zero & size);
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) => true;
}

class _OffsetImage extends CustomPainter {
  _OffsetImage(this.piUI);

  final _PIUI piUI;
  bool _repaint = true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(piUI.pImage.map, piUI.getViewRect(),
        const Offset(0, 0) & size, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (_repaint) {
      _repaint = false;
      return true;
    }
    return false;
  }
}

class _PIUI {
  final PanoramaImage pImage;
  final Size _size;
  var _zoom = 1;
  DisplayState _shown = DisplayState.horizon;
  Offset mapOffset;
  final Sink<MapParams> _fromPanorama;

  _PIUI(this._fromPanorama, this.pImage, this._size, this.mapOffset) {
    if (mapOffset.dy == 0) {
      mapOffset += Offset(_mapWidth().toDouble(), _mapHeight() / 2);
    }
    _fromPanorama.add(MapParams.sendHorizon(_getHorizon()));
    _fromPanorama.add(MapParams.sendFitHorizon());
  }

  CustomPaint getImage() {
    // print("getImage with shown $shown");
    switch (_shown) {
      case DisplayState.horizon:
        return CustomPaint(painter: _OffsetImage(this));
      case DisplayState.poi:
        return CustomPaint(painter: _OffsetImage(this));
    }
  }

  ui.Rect getViewRect() {
    var r = ui.Rect.fromCenter(
        center: mapOffset,
        width: _mapViewWidth(),
        height: _mapHeight().toDouble() / _zoom);
    return r;
  }

  tap(Offset tapOff) {
    switch (_shown) {
      case DisplayState.horizon:
        _shown = DisplayState.poi;
        final pos = _firstPanoramaPoint(tapOff);
        final posOff =
            Offset(tapOff.dx, pos.$2.toDouble() * _mapToViewFactor());
        updateOffset(posOff - _center());
        _zoom = 3;
        break;
      case DisplayState.poi:
        _zoom = 1;
        _shown = DisplayState.horizon;
        mapOffset = Offset(mapOffset.dx, _mapHeight() / 2);
        _fromPanorama.add(MapParams.sendHorizon(_getHorizon()));
        _fromPanorama.add(MapParams.sendFitHorizon());
        break;
    }
  }

  updateOffset(Offset off) {
    // print("Updating $off for $_shown");
    off /= _mapToViewFactor();
    _fromPanorama.add(MapParams.sendHorizon(_getHorizon()));
    switch (_shown) {
      case DisplayState.horizon:
        _fromPanorama.add(MapParams.sendFitHorizon());
        mapOffset = Offset(mapOffset.dx + off.dx, _mapHeight() / 2);
        break;
      case DisplayState.poi:
        mapOffset += off;
        _fromPanorama.add(MapParams.sendLocationPOI(_toLatLng(_center())));
        break;
    }
    final mapMinimum = _mapViewWidth() / 2;
    mapOffset = Offset(((mapOffset.dx - mapMinimum) % _mapWidth()) + mapMinimum,
        mapOffset.dy % _mapHeight());

    // Check if the current panorama is lower than the midpoint and
    // adjust the panorama to stay in the middle.
    if (_shown == DisplayState.poi) {
      if (mapOffset.dy > _mapHeight()) {
        mapOffset -= Offset(0, mapOffset.dy - _mapHeight());
      }
      if (pImage.reverse[mapOffset.dy.toInt() % _mapWidth()]
              [mapOffset.dx.toInt() % _mapWidth()] ==
          null) {
        var first =
            _firstPanoramaPoint(Offset(_size.width / 2, _size.height / 2));
        mapOffset += Offset(0, first.$2 - mapOffset.dy);
      }
    }
  }

  bool isPOI() {
    return _shown == DisplayState.poi;
  }

  List<LatLng> _getHorizon() {
    List<LatLng> horizon = [];
    var imgOffset = (mapOffset.dx - _mapViewWidth() / 2).toInt();
    for (var dx = imgOffset; dx < imgOffset + _mapViewWidth(); dx++) {
      // print("dx: $dx - $offset - ${width()}");
      for (var y = 0; y < _mapHeight(); y++) {
        // print("y: $y");
        var c = pImage.reverse[y][dx % _mapWidth()];
        if (c != null) {
          horizon.add(c);
          break;
        }
      }
    }
    return horizon;
  }

  (int, int) _firstPanoramaPoint(Offset pos) {
    final posInMap = mapOffset + (pos - _center()) / _mapToViewFactor();
    final mapX = posInMap.dx.toInt() % _mapWidth();
    var mapY = posInMap.dy.toInt();
    if (mapY >= _mapHeight()) {
      mapY = _mapHeight() - 1;
    } else if (mapY < 0) {
      mapY = 0;
    }
    for (var y = mapY; y < _mapHeight(); y++) {
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
    return _size.center(Offset.zero);
  }

  int _mapWidth() {
    return pImage.reverse[0].length;
  }

  int _mapHeight() {
    return pImage.reverse.length;
  }

  double _mapToViewFactor() => _size.height / _mapHeight() * _zoom;

  double _mapViewWidth() => _size.width / _mapToViewFactor();
}
