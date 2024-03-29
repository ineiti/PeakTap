import 'dart:async' show Future, StreamController;
import 'dart:ui' as ui;
import 'dart:math' show atan, cos, log, max, min, sin;

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:peak_tap/elevation/elevation.dart';
import 'package:vector_math/vector_math.dart';

class PanoramaImageBuilder {
  HeightProfileProvider hp;
  final _stream = StreamController<PIBMessage>.broadcast();

  final double horStart = 0, horEnd = 360;
  final double verStart = -5, verEnd = 25;
  final int maxDistance = 200000;

  PanoramaImageBuilder(this.hp) {
    hp.downloadLogStream().listen((event) {
      _stream.add(PIBMessage.sendDownloadStatus(event));
    });
  }

  Stream<PIBMessage> getStream() {
    return _stream.stream;
  }

  // All measurement values are in meter.
  Future<PanoramaImage> drawPanorama(int height, LatLng location) async {
    var tmpImage = img.Image(width: height * 12 * 2, height: height);
    List<List<LatLng?>> offsetToLatLang =
        List.generate(height, (i) => List.filled(height * 12, null));
    List<List<int?>> offsetToHeight =
        List.generate(height, (i) => List.filled(height * 12, null));
    List<List<int?>> offsetToDistance =
        List.generate(height, (i) => List.filled(height * 12, null));

    // print(
    //     "image is: ${tmpImage.height} at ${location.latitude}/${location.longitude}");
    var panoramaWidth = tmpImage.width / 2;
    int stepSize = 50;
    double earthRadius = 6371e3;
    int percentage = -1;
    var distScale = 1e-3;
    var grayMult = 255 / log(maxDistance * distScale);
    // for (var vert = 0; vert < 1; vert++) {
    print("Size is: $panoramaWidth x ${maxDistance / stepSize}");
    for (var vert = 0; vert < panoramaWidth; vert++) {
      // print("Vertical is: $vert");
      var lat = location.latitude;
      var lng = location.longitude;
      var horAngle =
          (horStart + (horEnd - horStart) * vert / panoramaWidth) / 180 * pi;
      horAngle = ((2 * pi - horAngle) + pi / 2) % (2 * pi);
      var verAngleMax = -180.0;
      // The dLat doesn't need to be adjusted by the latitude.
      var dLat = atan(sin(horAngle) * stepSize / earthRadius) * 180 / pi;
      // The dLng is calculated only for the reference position.
      // We suppose the error is negligible, even if this value is not updated
      // for every step in the `while` loop.
      var dLng =
          atan(cos(horAngle) / cos(lat / 180 * pi) * stepSize / earthRadius) *
              180 /
              pi;
      // print("Angle: dLat / dLng = $horAngle: $dLat / $dLng");
      var heightReference = await hp.getHeightAsync(LatLng(lat, lng)) + 10;
      var illumination = Vector3(1, -1, -2);
      illumination.applyAxisAngle(Vector3(0, 0, -1), horAngle);
      // print("heightReference is $heightReference");
      for (var distance = 0; distance < maxDistance; distance += stepSize) {
        lat += dLat;
        lng += dLng;
        // Sorry flat-earthers, but without that correction it's just not
        // accurate...
        var alpha = atan(distance / earthRadius);
        var horizon = (1 - cos(alpha)) * earthRadius;
        var ll = LatLng(lat, lng);
        int heightAbs;
        Vector3 normal;
        try {
          (heightAbs, normal) = hp.getHeightNormal(ll);
        } catch (e) {
          await hp.getTile(LatLng(lat, lng));
          (heightAbs, normal) = hp.getHeightNormal(ll);
        }
        var height = heightAbs - horizon.toInt();
        var verAngle = atan((height - heightReference) / distance) * 180 / pi;
        // print("$lat/$lng - $distance = $height - angle: $verAngle");

        // var gray = min(max((log(distance * distScale) * grayMult), 0), 255);
        int r, g, b;
        if (normal == Vector3(0, 0, -1)) {
          (r, g, b) = (100, 100, 155);
        } else {
          var gray = 120 * (1 + cos(normal.angleTo(illumination)));
          if (heightAbs > 2000) {
            gray = min(255, gray * (min(heightAbs, 3000) / 2500 + 0.2));
          }
          (r, g, b) = (gray.toInt(), gray.toInt(), gray.toInt());
          if (heightAbs < 500) {
            r = r * 10 ~/ 12;
            b = b * 10 ~/ 12;
          } else if (heightAbs < 1000) {
            r = r * 10 ~/ 11;
            b = b * 10 ~/ 11;
          }
        }

        if (verAngle > verAngleMax) {
          for (var j = 0; j < tmpImage.height; j++) {
            var verAnglePan =
                verEnd + (verStart - verEnd) * j / tmpImage.height;
            if (verAnglePan > verAngle) {
              continue;
            }
            if (verAnglePan < verAngleMax) {
              break;
            }
            // print("Set pixel $vert/$j to $gray");
            tmpImage.setPixelRgb(vert, j, r, g, b);
            tmpImage.setPixelRgb(vert + panoramaWidth.toInt(), j, r, g, b);
            offsetToLatLang[j][vert] = ll;
            offsetToHeight[j][vert] = heightAbs;
            offsetToDistance[j][vert] = distance;
          }
          verAngleMax = verAngle;
        }
      }
      for (var j = 0;
          j < (verAngleMax - verEnd) * tmpImage.height / (verStart - verEnd);
          j++) {
        final rg = 96 * j / tmpImage.height + 96;
        tmpImage.setPixelRgb(vert, j.toInt(), rg, rg, 255);
        tmpImage.setPixelRgb(
            vert + panoramaWidth.toInt(), j.toInt(), rg, rg, 255);
      }
      int newPercentage = vert * 100 ~/ panoramaWidth;
      // Give the scheduler the possibility to do something else.
      // If this is only done in the condition below, the painting process
      // takes around 20% less time. But then the UI gets ugly.
      await Future.delayed(const Duration(microseconds: 1));
      if (newPercentage > percentage) {
        percentage = newPercentage;
        _stream.add(PIBMessage.sendPaintPercentage(percentage));
      }
    }
    // print("Done drawing");
    ui.Codec codec = await ui.instantiateImageCodec(img.encodePng(tmpImage));
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return PanoramaImage(
        frameInfo.image, offsetToLatLang, offsetToDistance, offsetToHeight);
  }
}

class PIBMessage {
  HPMessage? _msg;
  int? _paintPerc;

  static PIBMessage sendDownloadStatus(HPMessage msg) {
    return PIBMessage().._msg = msg;
  }

  static PIBMessage sendPaintPercentage(int perc) {
    return PIBMessage().._paintPerc = perc;
  }

  void isDownloadStatus(void Function(HPMessage msg) useIt) {
    if (_msg != null) {
      useIt(_msg!);
    }
  }

  void isPaintPercentage(void Function(int perc) useIt) {
    if (_paintPerc != null) {
      useIt(_paintPerc!);
    }
  }
}

class PanoramaImage {
  ui.Image map;
  List<List<LatLng?>> offsetToLatLang;
  List<List<int?>> offsetToDistance;
  List<List<int?>> offsetToHeight;

  PanoramaImage(this.map, this.offsetToLatLang, this.offsetToDistance,
      this.offsetToHeight);
}
