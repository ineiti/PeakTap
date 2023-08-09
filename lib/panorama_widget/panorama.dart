import 'dart:async' show Future, StreamController;
import 'dart:ui' as ui;
import 'dart:math' show atan, cos, log, max, min, sin;

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:peak_tap/elevation/elevation.dart';

class PanoramaImageBuilder {
  HeightProfileProvider hp;
  final _stream = StreamController<PIBMessage>.broadcast();

  final double horStart = 0, horEnd = 360;
  final double verStart = -5, verEnd = 85;
  final int maxDistance = 200000;

  PanoramaImageBuilder(this.hp){
    hp.downloadLogStream().listen((event) {
      _stream.add(PIBMessage.sendDownloadStatus(event));
    });
  }

  Stream<PIBMessage> getStream(){
    return _stream.stream;
  }

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
    int percentage = -1;
    var distScale = 1e-3;
    var grayMult = 255 / log(maxDistance * distScale);
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
      var heightReference = await hp.getHeightAsync(LatLng(lat, lng)) + 10;
      // print("heightReference is $heightReference");
      for (var distance = 0; distance < maxDistance; distance += stepSize) {
        lat += dLat;
        lng += dLng;
        // Sorry flat-earthers, but without that correction it's just not
        // accurate...
        var alpha = atan(distance / earthRadius);
        var horizon = (1 - cos(alpha)) * earthRadius;
        var ll = LatLng(lat, lng);
        var height = await hp.getHeightAsync(ll);
        // var height = 0.0;
        // try {
        //   height = hp.getHeight(ll) - horizon;
        // } catch (e){
        //   await hp.getTile(LatLng(lat, lng));
        //   height = hp.getHeight(ll) - horizon;
        // }
        var verAngle = atan((height - heightReference) / distance) * 180 / pi;
        // print("$lat/$lng - $distance = $height - angle: $verAngle");
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
            var gray = min(
                max((log(distance * distScale) * grayMult), 0), 255);
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
      int newPercentage = vert * 100 ~/ panoramaWidth;
      if (newPercentage > percentage){
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

  static PIBMessage sendPaintPercentage(int perc){
    return PIBMessage().._paintPerc = perc;
  }

  void isDownloadStatus(void Function(HPMessage msg) useIt){
    if (_msg != null){
      useIt(_msg!);
    }
  }

  void isPaintPercentage(void Function(int perc) useIt){
    if (_paintPerc != null){
      useIt(_paintPerc!);
    }
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
