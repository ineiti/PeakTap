import 'dart:async' show Future;
import 'dart:ui' as ui;
import 'dart:math' show atan, cos, log, max, min, sin;
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:mountain_panorama/elevation/elevation.dart';

class PanoramaImage {
  final List<List<LatLng?>> _reverse;
  ui.Image map;

  PanoramaImage(this.map, this._reverse);

  List<LatLng> getHorizon(Size size, double offset) {
    List<LatLng> horizon = [];
    var imgOffset = offset ~/ _imgViewFactor(size);
    var end = ((imgOffset + _imgViewWidth(size)) % width()).toInt();
    for (var dx = imgOffset % width(); dx != end; dx = (dx + 1) % width()) {
      // print("dx: $dx - $offset - ${width()}");
      for (var y = 0; y < _height(); y++) {
        // print("y: $y");
        if (dx >= _reverse[y].length) {
          print("Dx overflow: $dx - ${width()} - ${_reverse[y].length}");
        }
        var c = _reverse[y][dx.toInt()];
        if (c != null) {
          horizon.add(c);
          break;
        }
      }
    }
    return horizon;
  }

  LatLng? toLatLng(Size size, Offset offset, ui.Offset pos) {
    final mapX = ((offset.dx + pos.dx)) ~/ _imgViewFactor(size) % width();
    final mapY = pos.dy ~/ _imgViewFactor(size);
    return _reverse[mapY][mapX];
  }

  ui.Rect getViewRect(Size size, Offset offset) {
    var r = ui.Rect.fromCenter(
        center: ui.Offset(_imgCenterView(size, offset), _height() / 2),
        width: _imgViewWidth(size),
        height: _height().toDouble());
    return r;
  }

  int width() {
    return _reverse[0].length;
  }

  int _height() {
    return _reverse.length;
  }

  double _imgViewFactor(Size size) => size.height / _height();

  double _imgViewWidth(Size size) => size.width / _imgViewFactor(size);

  double _imgCenterView(Size size, Offset offset) =>
      _imgViewWidth(size) / 2 + offset.dx / _imgViewFactor(size);
}

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
