import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
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
  var pd = Image.asset("empty.png");
  PanoramaCH? ch;

  @override
  Widget build(BuildContext context) {
    return pd;
  }

  @override
  void initState() {
    super.initState();
    if (ch == null) {
      PanoramaCH.readASC().then((lines) {
        ch = PanoramaCH(lines);

        widget.toPanorama.listen((event) {
          event.isLocation((loc) {
            setState(() {
              pd = Image.memory(ch!.getImage(loc));
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
