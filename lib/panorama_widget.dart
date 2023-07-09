import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mountain_panorama/elevation/elevation.dart';

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
  HeightProfileProvider? heightProfile;
  PanoramaImage? pi;
  final GlobalKey _widgetKey = GlobalKey();
  final imgHeight = 256;
  final tapTime = 200;
  TapDownDetails? tapPos;
  int? down;

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
          tapPos = tap;
          down = DateTime.now().millisecondsSinceEpoch;
        },
        onTapUp: (tap) {
          if (DateTime.now().millisecondsSinceEpoch - down! <= tapTime) {
            var pos = pi?.toLatLng(tapPos!.localPosition);
            if (pos != null) {
              widget.fromPanorama.add(MapParams.sendLocationPOI(pos));
            }
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
    if (DateTime.now().millisecondsSinceEpoch - down! > tapTime) {
      setState(() {
        pi?.updateOffset(dx);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (heightProfile == null) {
      HeightProfileProvider.withAppDir().then((hp) {
        heightProfile = hp;
        widget.toPanorama.listen((event) {
          event.isLocationViewpoint((loc) {
            PanoramaImageBuilder(heightProfile!, loc, imgHeight)
                .getImage(pi?.offset)
                .then((pImage) {
              setState(() {
                pi = pImage;
              });
            });
          });

          widget.fromPanorama.add(MapParams.sendSetupFinish());
        });
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
