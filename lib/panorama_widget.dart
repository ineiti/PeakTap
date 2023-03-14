import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'map_widget/map_widget.dart';
import 'panorama/panorama.dart';

class Panorama extends StatefulWidget {
  Panorama({super.key, required this.toPanorama, required this.fromPanorama});

  final Stream<MapParams> toPanorama;
  final Sink<MapParams> fromPanorama;

  @override
  State<Panorama> createState() => PanoramaState();
}

class PanoramaState extends State<Panorama> {
  var png = Image.asset("empty.png");
  PanoramaCH? ch;
  PanoramaImage? pi;
  final GlobalKey _widgetKey = GlobalKey();
  Size imgSize = const Size(1024, 512);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          // print("tapped");
        },
        onTapDown: (tap) {
          print("tapped: ${tap.globalPosition} - ${tap.localPosition}");
          if (pi == null) {
            return;
          }
          final RenderBox renderBox =
          _widgetKey.currentContext?.findRenderObject() as RenderBox;
          var gps = pi!.toGPS(renderBox.size, tap.localPosition);
          if (gps != null) {
            widget.fromPanorama.add(MapParams.sendLocationPOI(gps.toList()));
          }
        },
        child: Listener(
          child: png,
          key: _widgetKey,
          onPointerMove: (update) {
            // print("move update: ${update.delta}");
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              // print("Scrolling: ${signal.scrollDelta}");
            }
          },
        ));
  }

  @override
  void initState() {
    super.initState();
    if (ch == null) {
      PanoramaCH.readASC().then((lines) {
        ch = PanoramaCH(lines);

        widget.toPanorama.listen((event) {
          event.isLocationViewpoint((loc) {
            setState(() {
              var locCH = CoordGPS.fromList(loc).toCH();
              pi = PanoramaImage(
                  ch!, locCH, imgSize.width.toInt(), imgSize.height.toInt());
              png = Image.memory(pi!.getImageAsU8(),
                  fit: BoxFit.fitHeight, repeat: ImageRepeat.repeatY);
            });
          });
        });

        widget.fromPanorama.add(MapParams.sendSetupFinish());
      });
    } else {
      print("ch already initialised");
    }
  }
}
