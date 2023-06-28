import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_widget/map_params.dart';
import 'panorama/panorama.dart';

class Panorama extends StatefulWidget {
  Panorama({super.key, required this.toPanorama, required this.fromPanorama});

  final Stream<MapParams> toPanorama;
  final Sink<MapParams> fromPanorama;

  @override
  State<Panorama> createState() => PanoramaState();
}

class PanoramaState extends State<Panorama> {
  var empty = Image.asset("assets/empty.png");
  PanoramaCH? ch;
  PanoramaImage? pi;
  final GlobalKey _widgetKey = GlobalKey();
  final imgHeight = 256;

  @override
  Widget build(BuildContext context) {
    Widget mapImage = empty;
    if (pi != null) {
      final RenderBox renderBox =
          _widgetKey.currentContext?.findRenderObject() as RenderBox;
      pi?.setSize(renderBox.size);
      widget.fromPanorama.add(MapParams.sendHorizon(pi!.getHorizon()));
      mapImage = CustomPaint(painter: OffsetImage(pImage: pi!));
    }
    return GestureDetector(
        onTapDown: (tap) {
          var gps = pi?.toGPS(tap.localPosition);
          if (gps != null) {
            widget.fromPanorama.add(MapParams.sendLocationPOI(gps.toList()));
          }
        },
        child: Listener(
          key: _widgetKey,
          onPointerMove: (update) {
            _updateOffset(-update.delta.dx);
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _updateOffset(signal.scrollDelta.dx);
            }
          },
          child: mapImage,
        ));
  }

  void _updateOffset(double dx) {
    setState(() {
      pi?.updateOffset(dx);
    });
  }

  @override
  void initState() {
    super.initState();
    if (ch == null) {
      PanoramaCH.readASC().then((lines) {
        ch = PanoramaCH(lines);

        widget.toPanorama.listen((event) {
          event.isLocationViewpoint((loc) {
            var locCH = CoordGPS.fromList(loc).toCH();
            PanoramaImageBuilder(ch!, locCH, imgHeight)
                .getImage(pi?.offset)
                .then((pImage) {
              setState(() {
                pi = pImage;
              });
            });
          });
        });

        widget.fromPanorama.add(MapParams.sendSetupFinish());
      });
    }
  }
}

class OffsetImage extends CustomPainter {
  OffsetImage({
    required this.pImage,
  }) : offset = pImage.offset;

  PanoramaImage pImage;
  double offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
        pImage.map, pImage.getViewRect(), const Offset(0, 0) & size, Paint());
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return pImage.changed();
  }
}
