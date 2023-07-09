import 'dart:async' show Future;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' show atan, cos, log, max, min, sin;

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:mountain_panorama/elevation/elevation.dart';

class PanoramaImage {
  final List<List<LatLng?>> _reverse;
  ui.Image map;
  double offset;
  ui.Size _size;
  bool _changed = true;

  PanoramaImage(double? off,
      {required this.map, required List<List<LatLng?>> reverse})
      : _reverse = reverse,
        _size = ui.Size(map.width.toDouble(), map.height.toDouble()),
        offset = off ?? -1;

  int height() {
    return _reverse.length;
  }

  int width() {
    return _reverse[0].length;
  }

  bool changed() {
    var c = _changed;
    _changed = false;
    return c;
  }

  double viewDirection() => _imgCenterView() * 2 * pi / width();

  double viewAngle() => _imgViewWidth() * 2 * pi / width();

  List<LatLng> getHorizon() {
    List<LatLng> horizon = [];
    var imgOffset = offset ~/ _imgViewFactor();
    var end = ((imgOffset + _imgViewWidth()) % width()).toInt();
    for (var dx = imgOffset % width(); dx != end; dx = (dx + 1) % width()) {
      // print("dx: $dx - $offset - ${width()}");
      for (var y = 0; y < height(); y++) {
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

  void updateOffset(double dx) {
    _changed = true;
    offset += dx;
    offset %= width() * _imgViewFactor();
  }

  void setSize(ui.Size s) {
    if (_size != s) {
      _changed = true;
    } else {}
    _size = s;
    if (offset == -1) {
      offset = width() * _imgViewFactor() / 2;
    }
  }

  LatLng? toLatLng(ui.Offset pos) {
    final mapX = ((offset + pos.dx)) ~/ _imgViewFactor() % width();
    final mapY = pos.dy ~/ _imgViewFactor();
    return _reverse[mapY][mapX];
  }

  double _imgViewFactor() => _size.height / height();

  double _imgViewWidth() => _size.width / _imgViewFactor();

  double _imgCenterView() => _imgViewWidth() / 2 + offset / _imgViewFactor();

  ui.Rect getViewRect() {
    var r = ui.Rect.fromCenter(
        center: ui.Offset(_imgCenterView(), height() / 2),
        width: _imgViewWidth(),
        height: height().toDouble());
    return r;
  }
}

class PanoramaImageBuilder {
  HeightProfileProvider hp;
  LatLng location;
  img.Image tmpImage;
  List<List<LatLng?>> reverse;

  double horStart = 0, horEnd = 360;
  double verStart = -5, verEnd = 25;

  PanoramaImageBuilder(this.hp, this.location, int height)
      : tmpImage = img.Image(width: height * 12 * 2, height: height),
        reverse = List.generate(height, (i) => List.filled(height * 12, null)) {
  }

  Uint8List getImageAsU8() {
    return img.encodePng(tmpImage);
  }

  Future<PanoramaImage> getImage(double? offset) async {
    await _drawPanorama();
    // _drawMap();
    // print("Returning image");
    ui.Codec codec = await ui.instantiateImageCodec(img.encodePng(tmpImage));
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return PanoramaImage(map: frameInfo.image, reverse: reverse, offset);
  }

  Future<void> _drawPanorama() async {
    // print(
    //     "image is: ${tmpImage.height} at ${location.latitude}/${location.longitude}");
    var panoramaWidth = tmpImage.width / 2;
    double cellsize = 50;
    double earthRadius = 6371e3;
    // for (var vert = 0; vert < 1; vert++) {
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
  }
}
