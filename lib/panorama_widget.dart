import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

import 'map_widget/map_widget.dart';
import 'panorama/panorama.dart';

class Panorama extends StatefulWidget {
  Panorama({super.key, required this.to_panorama, required this.from_panorama});

  final Stream<MapParams> to_panorama;
  final Sink<MapParams> from_panorama;

  @override
  State<Panorama> createState() => PanoramaState();
}

class PanoramaState extends State<Panorama> {
  var pd = Image.memory(Uint8List(0));
  PanoramaCH? ch;
  MapParams? last_event;

  @override
  Widget build(BuildContext context) {
    if (ch != null && last_event?.location != null) {
      pd = Image.memory(ch!.getImage(last_event!.location!));
    }
    return pd;
  }

  @override
  void initState() {
    super.initState();
    last_event = MapParams()..location = [46.5943, 6.3101];
    if (ch == null) {
      PanoramaCH.readASC().then((lines) {
        ch = PanoramaCH(lines);
        setState(() {
          List<double> loc = [47, 8];
          pd = Image.memory(ch!.getImage(loc));
        });
        widget.to_panorama.listen((event) {
          setState(() {
            last_event = event;
          });
        });
      });
    } else {
      print("ch already initialised");
    }
  }
}
