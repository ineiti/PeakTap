import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_tap/elevation/elevation.dart';
import 'package:sprintf/sprintf.dart';

import '../map_widget/map_params.dart';
import 'panorama.dart';

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
  final _empty = Image.asset("assets/empty.png");
  late HeightProfileProvider _heightProfile;
  late PanoramaImageBuilder _piBuilder;
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
    Widget mapImage = _empty;
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
      _heightProfile = await HeightProfileProvider.withAppDir();
      _piBuilder = PanoramaImageBuilder(_heightProfile);
      _piBuilder.getStream().listen((event) {
        event.isDownloadStatus((msg) {
          widget.fromPanorama.add(MapParams.sendDownloadStatus(msg));
        });
        event.isPaintPercentage((perc) {
          widget.fromPanorama.add(MapParams.sendPaintingStatus(perc));
        });
      });
      widget.toPanorama.listen((event) {
        event.isLocationViewpoint((loc) {
          setState(() {
            pImage = null;
          });
          Future.delayed(const Duration(milliseconds: 150), () async {
            var pi = await _piBuilder.drawPanorama(imgHeight, loc);
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
  _OffsetImage(this.piUI, this._cross);

  final _PIUI piUI;
  bool _repaint = true;
  bool _cross;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(piUI.pImage.map, piUI.getViewRect(),
        const Offset(0, 0) & size, Paint());
    if (_cross) {
      var width = 0.2, space = 3;
      var centerX = size.width / 2, centerY = size.height / 2;
      var dX = centerX * width, dY = centerY * width;
      var p = Paint()
        ..color = const Color(0xffffaaaa)
        ..strokeWidth = 3;
      for (var mulX = -1; mulX <= 1; mulX += 2) {
        for (var mulY = -1; mulY <= 1; mulY += 2) {
          var sX = space * mulX, sY = space * mulY;
          canvas.drawLine(
              Offset(centerX + dX * mulX + sX, centerY + dY * mulY + sY),
              Offset(centerX + sX, centerY + sY),
              p);
        }
      }
      if (piUI.poiE != null) {
        var headingDegrees = piUI.poiE!.heading.toInt() % 360;
        var heading = sprintf("%03d° ", [headingDegrees]);
        headingDegrees = ((headingDegrees + 360 + 22.5) ~/ 45) % 8;
        var headingText =
            ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][headingDegrees];
        _writeText(
            canvas, Offset(centerX / 3, centerY / 3), heading + headingText);
        _writeText(canvas, Offset(centerX * 5 / 3, centerY / 3),
            "${piUI.poiE!.distance.toInt()} m",
            right: true);
        _writeText(canvas, Offset(centerX * 5 / 3, centerY * 2 / 3),
            "${piUI.poiE!.height.toInt()} m",
            right: true);
      }
    }
  }

  _writeText(Canvas c, Offset o, String s, {bool right = false}) {
    final align = right ? TextAlign.right : TextAlign.left;
    final width = right ? o.dx : 0;
    var textSpan = TextSpan(
      text: s,
      style: const TextStyle(
        color: Colors.greenAccent,
        fontSize: 24,
        fontFamily: "7segments",
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    textPainter.layout(
      minWidth: width.toDouble(),
      // minWidth: 0,
      // maxWidth: size.width,
    );
    textPainter.paint(c, right ? Offset(0, o.dy) : o);
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

class _POIElements {
  late double heading, height;
  int distance;

  _POIElements(this.heading, this.height, this.distance);
}

class _PIUI {
  final PanoramaImage pImage;
  final Size _size;
  var _zoom = 1;
  _POIElements? poiE;
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
        return CustomPaint(painter: _OffsetImage(this, false));
      case DisplayState.poi:
        return CustomPaint(painter: _OffsetImage(this, true));
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
        poiE = null;
        break;
      case DisplayState.poi:
        mapOffset += off;
        var ll = _toLatLng(_center());
        _fromPanorama.add(MapParams.sendLocationPOI(ll));
        poiE = _POIElements(360 / pImage.map.width * 2 * mapOffset.dx,
            _toHeight(_center()), _toDistance(_center()));
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
      if (pImage.offsetToLatLang[mapOffset.dy.toInt() % _mapWidth()]
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
        var c = pImage.offsetToLatLang[y][dx % _mapWidth()];
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
      if (pImage.offsetToLatLang[y][mapX] != null) {
        return (mapX, y);
      }
    }
    throw ("Didn't manage to find land at $mapX / $mapY for ${pImage.offsetToLatLang[0].length} / ${pImage.offsetToLatLang.length}");
  }

  LatLng _toLatLng(ui.Offset pos) {
    final p = _firstPanoramaPoint(pos);
    return pImage.offsetToLatLang[p.$2][p.$1]!;
  }

  double _toHeight(ui.Offset pos) {
    final p = _firstPanoramaPoint(pos);
    return pImage.offsetToHeight[p.$2][p.$1]!;
  }

  int _toDistance(ui.Offset pos) {
    final p = _firstPanoramaPoint(pos);
    return pImage.offsetToDistance[p.$2][p.$1]!;
  }

  Offset _center() {
    return _size.center(Offset.zero);
  }

  int _mapWidth() {
    return pImage.offsetToLatLang[0].length;
  }

  int _mapHeight() {
    return pImage.offsetToLatLang.length;
  }

  double _mapToViewFactor() => _size.height / _mapHeight() * _zoom;

  double _mapViewWidth() => _size.width / _mapToViewFactor();
}
