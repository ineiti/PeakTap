import 'dart:async' show Future;
import 'dart:ui' as ui;
import 'dart:math' show atan, cos, log, max, min, sin;

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:peak_tap/elevation/elevation.dart';

class PanoramaImageBuilder {
  HeightProfileProvider hp;

  double horStart = 0, horEnd = 360;
  double verStart = -5, verEnd = 25;

  PanoramaImageBuilder(this.hp);

  // All measurement values are in meter.
  Future<PanoramaImage> drawPanorama(int height, LatLng location) async {
    var tmpImage = img.Image(width: height * 12 * 2, height: height);
    List<List<LatLng?>> offsetToLatLang =
        List.generate(height, (i) => List.filled(height * 12, null));
    List<List<double?>> offsetToHeight =
        List.generate(height, (i) => List.filled(height * 12, null));
    List<List<int?>> offsetToDistance =
        List.generate(height, (i) => List.filled(height * 12, null));

    // print(
    //     "image is: ${tmpImage.height} at ${location.latitude}/${location.longitude}");
    var panoramaWidth = tmpImage.width / 2;
    int stepSize = 50;
    double earthRadius = 6371e3;
    // for (var vert = 0; vert < 1; vert++) {
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
      var heightReference = await hp.getHeight(LatLng(lat, lng)) + 10;
      // print("heightReference is $heightReference");
      for (var distance = 0; distance < 200000; distance += stepSize) {
        lat += dLat;
        lng += dLng;
        // Sorry flat-earthers, but without that correction it's just not
        // accurate...
        var alpha = atan(distance / earthRadius);
        var horizon = (1 - cos(alpha)) * earthRadius;
        var height = await hp.getHeight(LatLng(lat, lng)) - horizon;
        var verAngle = atan((height - heightReference) / distance) * 180 / pi;
        // print("$lat/$lng - $distance = $height - angle: $verAngle");
        if (verAngle > verAngleMax) {
          var mult = 1e-3;
          var gray = min(
              max((log(distance * mult) * 255 / log(200000 * mult)), 0), 255);
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
            tmpImage.setPixelRgb(vert, j, gray, gray, gray);
            tmpImage.setPixelRgb(
                vert + panoramaWidth.toInt(), j, gray, gray, gray);
            offsetToLatLang[j][vert] = LatLng(lat, lng);
            offsetToHeight[j][vert] = height.toDouble() + horizon;
            offsetToDistance[j][vert] = distance;
          }
          verAngleMax = verAngle;
        }
      }
      // Give the scheduler the possibility to do something else.
      await Future.delayed(const Duration(microseconds: 1));
    }
    // print("Done drawing");
    ui.Codec codec = await ui.instantiateImageCodec(img.encodePng(tmpImage));
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return PanoramaImage(
        frameInfo.image, offsetToLatLang, offsetToDistance, offsetToHeight);
  }
}

class PanoramaImage {
  ui.Image map;
  List<List<LatLng?>> offsetToLatLang;
  List<List<int?>> offsetToDistance;
  List<List<double?>> offsetToHeight;

  PanoramaImage(this.map, this.offsetToLatLang, this.offsetToDistance,
      this.offsetToHeight);
}
