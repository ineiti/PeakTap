import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey _widgetKey = GlobalKey();
  final imgHeight = 256;
  final tapTime = 200;
  Offset offset = const Offset(0, 0);
  DisplayState shown = DisplayState.horizon;
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
      // print("Building with offset ${pImage?.off}");
      switch (shown) {
        case DisplayState.horizon:
          widget.fromPanorama.add(MapParams.sendHorizon(
              pImage!.getHorizon(size, offset.dx)));
          mapImage = CustomPaint(
              painter: OffsetImage(size, pImage!, offset));
          break;
        case DisplayState.poi:
          break;
      }
    }
    return GestureDetector(
        onTapDown: (tap) {
          tapPos = tap;
          down = DateTime.now().millisecondsSinceEpoch;
        },
        onTapUp: (tap) {
          if (DateTime.now().millisecondsSinceEpoch - down! <= tapTime) {
            switch (shown) {
              case DisplayState.horizon:
                var pos = pImage?.toLatLng(
                    size, offset, tapPos!.localPosition);
                if (pos != null) {
                  widget.fromPanorama.add(MapParams.sendLocationPOI(pos));
                }
                // setState(() {
                //   shown = DisplayState.poi;
                // });
                break;
              case DisplayState.poi:
                setState(() {
                  shown = DisplayState.horizon;
                });
                break;
            }
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
      switch (shown) {
        case DisplayState.horizon:
          setState(() {
            offset = Offset((offset.dx + off.dx) % pImage!.map.width, 0);
          });
          break;
        case DisplayState.poi:
          break;
      }
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
          });
        });
      });
      widget.fromPanorama.add(MapParams.sendSetupFinish());
    });
  }
}

class OffsetImage extends CustomPainter {
  OffsetImage(this._size, this._pImage, this._offset);

  final PanoramaImage _pImage;
  final Offset _offset;
  final Size _size;
  bool changed = false;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(_pImage.map, _pImage.getViewRect(_size, _offset),
        const Offset(0, 0) & size, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
    // var prev = changed;
    // changed = false;
    // return prev;
  }
}
