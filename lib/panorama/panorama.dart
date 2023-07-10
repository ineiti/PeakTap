import 'dart:async' show Future;
import 'dart:ui' as ui;
import 'dart:math' show atan, cos, log, max, min, sin;

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:mountain_panorama/elevation/elevation.dart';

class PanoramaImageBuilder {
  HeightProfileProvider hp;

  double horStart = 0, horEnd = 360;
  double verStart = -5, verEnd = 25;

  PanoramaImageBuilder(this.hp);

  Future<PanoramaImage> drawPanorama(int height, LatLng location) async {
    var tmpImage = img.Image(width: height * 12 * 2, height: height);
    List<List<LatLng?>> reverse =
        List.generate(height, (i) => List.filled(height * 12, null));

    // print(
    //     "image is: ${tmpImage.height} at ${location.latitude}/${location.longitude}");
    var panoramaWidth = tmpImage.width / 2;
    double cellsize = 50;
    double earthRadius = 6371e3;
    for (var vert = 0; vert < panoramaWidth; vert++) {
      // print("Vertical is: $vert");
      // Get the height of the observer
      var lat = location.latitude;
      var lng = location.longitude;
      var horAngle =
          (horStart + (horEnd - horStart) * vert / panoramaWidth) / 180 * pi;
      horAngle = ((2 * pi - horAngle) + pi / 2) % (2 * pi);
      var verAngleMax = -180.0;
      var distance = 0.0;
      // The dLat doesn't need to be adjusted by the latitude.
      var dLat = atan(sin(horAngle) * cellsize / earthRadius) * 180 / pi;
      // The dLng is calculated only for the reference position.
      // We suppose the error in not calculating it for every latitude
      // during the 'while' is negligible.
      var dLng =
          atan(cos(horAngle) * cos(lat / 180 * pi) * cellsize / earthRadius) *
              180 /
              pi;
      // print("Angle: dLat / dLng = $horAngle: $dLat / $dLng");
      var heightReference = await hp.getHeight(LatLng(lat, lng)) + 100;
      for (var h = 0; h < 100000 / cellsize; h++) {
        distance += cellsize;

        lat += dLat;
        lng += dLng;
        var height = await hp.getHeight(LatLng(lat, lng));
        // print("$lat/$lng - $distance = $height");

        var verAngle = atan((height - heightReference) / distance) * 180 / pi;
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
            reverse[j][vert] = LatLng(lat, lng);
          }
          verAngleMax = verAngle;
        }
      }
    }
    // print("Done drawing");
    ui.Codec codec = await ui.instantiateImageCodec(img.encodePng(tmpImage));
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return PanoramaImage(frameInfo.image, reverse);
  }
}

class PanoramaImage {
  ui.Image map;
  List<List<LatLng?>> reverse;
  PanoramaImage(this.map, this.reverse);
}