import 'dart:async' show Future;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' show atan, cos, log, max, pi, pow, sin;

import 'dart:io';
import 'package:image/image.dart' as img;

import '../map_widget/map_widget.dart';

class PanoramaCH {
  late int ncols, nrows;
  late double xllcorner, xulcorner, yllcorner, cellsize, nodataValue;
  late List<List<double>> elevation;
  double hor_start = 0, hor_end = 360;
  double ver_start = -5, ver_end = 20;

  static Future<List<String>> readASC() async {
    return (await rootBundle.loadString('assets/swisstopo.asc')).split("\n");
  }

  PanoramaCH(List<String> lines) {
    ncols = int.parse(lines[0].split(' ')[1]);
    nrows = int.parse(lines[1].split(' ')[1]);
    xllcorner = double.parse(lines[2].split(' ')[1]);
    yllcorner = double.parse(lines[3].split(' ')[1]);
    cellsize = double.parse(lines[4].split(' ')[1]);
    nodataValue = double.parse(lines[5].split(' ')[1]);

    // Read the elevation values into a two-dimensional array.
    List<double> values = List<double>.filled(0, 0, growable: true);
    for (int line = 6; line < lines.length; line++) {
      values.addAll(lines[line].split(' ').map(double.parse).toList());
    }
    elevation = List<List<double>>.generate(nrows, (i) {
      return values.sublist(i * ncols, (i + 1) * ncols);
    });
  }

  List<double> getXYDouble(List<double> location) {
    double fx = _WGStoCHy(location[0], location[1]);
    double fy = _WGStoCHx(location[0], location[1]);
    double x = (fx - xllcorner) / cellsize;
    double y = (yllcorner / cellsize + nrows) - fy / cellsize;
    return [x, y];
  }

  List<int> getXYInt(List<double> location) {
    var dxy = getXYDouble(location);
    return [dxy[0].toInt(), dxy[1].toInt()];
  }

  Uint8List getImage(List<double> location) {
    // Create a 256x256 8-bit (default) rgb (default) image.
    final image = img.Image(width: 1024, height: 256);
    // Iterate over its pixels
    // printMap(image, location);
    printPanorama(image, location);
    // Encode the resulting image to the PNG image format.
    return img.encodePng(image);
  }

  void printMap(img.Image map, List<double> location) {
    var dxy = getXYInt(location);
    var dx = dxy[0] - map.width ~/ 2;
    var dy = dxy[1] - map.height ~/ 2;
    for (var pixel in map) {
      var gray = getData(pixel.x + dx, pixel.y + dy) / 20;
      // Set the pixels red value to its x position value, creating a gradient.
      pixel
        ..r = gray
        ..g = gray
        ..b = gray;
    }
  }

  void printPanorama(img.Image pan, List<double> location) {
    // # Fill the panorama array with the distances encoded as shades of gray
    for (var x = 0; x < pan.width; x++) {
      paintVerticalLine3D(pan, location, x);
    }
  }

  void paintVerticalLine3D(img.Image pan, List<double> location, int vert) {
    // Get the height of the observer
    var x = _WGStoCHy(location[0], location[1]);
    var y = _WGStoCHx(location[0], location[1]);
    var horAngle = hor_start + (hor_end - hor_start) * vert / pan.width / 180 * pi;
    horAngle = (2 * pi - horAngle) + pi / 2;
    var verAngleMax = -180.0;
    var distance = 1.0;
    var dx = cos(horAngle) * cellsize;
    var dy = sin(horAngle) * cellsize;
    var heightReference = getHeightAtCoordinateInterpolate(x, y) + 100;
    while (true) {
      x += dx;
      y += dy;
      var height = getHeightAtCoordinateInterpolate(x, y);
      if (height == 0) {
        break;
      }

      var verAngle = atan((height - heightReference) / distance) * 180 / pi;
      if (verAngle > verAngleMax) {
        // print("Higher: $verAngle > $verAngleMax");
        // print("higher angle at $x / $y / $distance = $verAngle, $verAngleMax");
        var mult = 1e-3;
        var gray = max((log(distance * mult) * 255 / log(100000 * mult)), 0);
        for (var j = 0; j < pan.height; j++) {
          var verAnglePan = ver_end + (ver_start - ver_end) * j / pan.height;
          if (verAnglePan > verAngle) {
            continue;
          }
          if (verAnglePan < verAngleMax) {
            break;
          }
          // print("Paint: $j - $gray - $distance - $verAnglePan");
          // print("set pixel $vert/$j with distance $distance to $gray");
          pan.setPixelRgb(vert, j, gray, gray, gray);
        }
        verAngleMax = verAngle;
      }

      distance += cellsize;
    }
  }

  double getHeightAtCoordinateInterpolate(double x, double y) {
    x = (x - xllcorner) / cellsize;
    y = (yllcorner / cellsize + nrows) - y / cellsize;
    var x_0 = x.toInt();
    var y_0 = y.toInt();
    var P0 = getData(x_0, y_0);
    var Px = getData(x_0 + 1, y_0);
    if (x_0 > x) {
      Px = getData(x_0 - 1, y_0);
    }

    var Py = getData(x_0, y_0 + 1);
    if (y_0 > y) {
      Py = getData(x_0, y_0 - 1);
    }
    return P0 + (x - x_0).toInt() * (Px - P0) + (y - y_0).toInt() * (Py - P0);
  }

  double getData(int x, int y) {
    if (x < 0 || x >= ncols || y < 0 || y >= nrows) {
      return 0;
    }
    return elevation[y][x];
  }

  Future<ui.Image> convertImageToFlutterUi(img.Image image) async {
    if (image.format != img.Format.uint8 || image.numChannels != 4) {
      final cmd = img.Command()
        ..image(image)
        ..convert(format: img.Format.uint8, numChannels: 4);
      final rgba8 = await cmd.getImageThread();
      if (rgba8 != null) {
        image = rgba8;
      }
    }

    ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(image.toUint8List());

    ui.ImageDescriptor id = ui.ImageDescriptor.raw(buffer,
        height: image.height,
        width: image.width,
        pixelFormat: ui.PixelFormat.rgba8888);

    ui.Codec codec = await id.instantiateCodec(
        targetHeight: image.height, targetWidth: image.width);

    ui.FrameInfo fi = await codec.getNextFrame();
    ui.Image uiImage = fi.image;

    return uiImage;
  }
}

class CoordGPS {
  double lat;
  double lng;

  CoordGPS(this.lat, this.lng) {}

  CoordCH toCH() {
    return CoordCH(_WGStoCHx(lat, lng), _WGStoCHy(lat, lng));
  }
}

class CoordCH {
  double x;
  double y;

  CoordCH(this.x, this.y) {}

  CoordGPS toGPS() {
    return CoordGPS(_CHtoWGSlat(y, x), _CHtoWGSlng(y, x));
  }
}

// GPS Converter class which is able to perform conversions between the
// CH1903 and WGS84 system.
// Convert CH y/x/h to WGS height
double _CHtoWGSheight(double y, double x, double h) {
  // Auxiliary values(% Bern)
  double yAux = (y - 600000) / 1000000;
  double xAux = (x - 200000) / 1000000;
  h = (h + 49.55) - (12.60 * yAux) - (22.64 * xAux);
  return h;
}

// Convert CH y/x to WGS lat
double _CHtoWGSlat(double y, double x) {
// Auxiliary values (% Bern)
  double yAux = (y - 600000) / 1000000;
  double xAux = (x - 200000) / 1000000;
  double lat = (16.9023892 + (3.238272 * xAux)) +
      -(0.270978 * pow(yAux, 2)) +
      -(0.002528 * pow(xAux, 2)) +
      -(0.0447 * pow(yAux, 2) * xAux) +
      -(0.0140 * pow(xAux, 3));
// Unit 10000" to 1" and convert seconds to degrees (dec)
  lat = (lat * 100) / 36;
  return lat;
}

// Convert CH y/x to WGS long
double _CHtoWGSlng(double y, double x) {
// Auxiliary values (% Bern)
  double yAux = (y - 600000) / 1000000;
  double xAux = (x - 200000) / 1000000;
  double lng = (2.6779094 +
          (4.728982 * yAux) +
          (0.791484 * yAux * xAux) +
          (0.1306 * yAux * pow(xAux, 2))) +
      -(0.0436 * pow(yAux, 3));
  // Unit 10000" to 1" and convert seconds to degrees (dec)
  lng = (lng * 100) / 36;
  return lng;
}

// Convert decimal angle (° dec) to sexagesimal angle (dd.mmss,ss)
double _DecToSexAngle(double dec) {
  int degree = dec.floor();
  int minute = ((dec - degree) * 60).floor();
  double second = (((dec - degree) * 60) - minute) * 60;
  return degree + (minute / 100.0) + (second / 10000);
}

// Convert sexagesimal angle (dd.mmss,ss) to seconds
double _SexAngleToSeconds(double dms) {
  int degree = 0;
  int minute = 0;
  double second = 0;
  degree = dms.floor();
  minute = ((dms - degree) * 100).floor();
  second = (((dms - degree) * 100) - minute) * 100;
  return second + (minute * 60) + (degree * 3600);
}

// Convert sexagesimal angle (dd.mmss) to decimal angle (degrees)
double _SexToDecAngle(double dms) {
  int degree = 0;
  int minute = 0;
  double second = 0;
  degree = dms.floor();
  minute = ((dms - degree) * 100).floor();
  second = (((dms - degree) * 100) - minute) * 100;
  return degree + (minute / 60) + (second / 3600);
}

// Convert WGS lat/long (° dec) and height to CH h
double _WGStoCHh(double latIn, double lngIn, double hIn) {
  double lat = _DecToSexAngle(latIn);
  double lng = _DecToSexAngle(lngIn);
  lat = _SexAngleToSeconds(lat);
  lng = _SexAngleToSeconds(lng);
  // Auxiliary values (% Bern)
  double latAux = (lat - 169028.66) / 10000;
  double lngAux = (lng - 26782.5) / 10000;
  double h = (hIn - 49.55) + (2.73 * lngAux) + (6.94 * latAux);
  return h;
}

// Convert WGS lat/long (° dec) to CH x
double _WGStoCHx(double latIn, double lngIn) {
  double lat = _DecToSexAngle(latIn);
  double lng = _DecToSexAngle(lngIn);
  lat = _SexAngleToSeconds(lat);
  lng = _SexAngleToSeconds(lng);
  // Auxiliary values (% Bern)
  double latAux = (lat - 169028.66) / 10000;
  double lngAux = (lng - 26782.5) / 10000;
  double x = ((200147.07 +
              (308807.95 * latAux) +
              (3745.25 * pow(lngAux, 2)) +
              (76.63 * pow(latAux, 2))) +
          -(194.56 * pow(lngAux, 2) * latAux)) +
      (119.79 * pow(latAux, 3));
  return x;
}

// Convert WGS lat/long (° dec) to CH y
double _WGStoCHy(double latIn, double lngIn) {
  double lat = _DecToSexAngle(latIn);
  double lng = _DecToSexAngle(lngIn);
  lat = _SexAngleToSeconds(lat);
  lng = _SexAngleToSeconds(lng);
  // Auxiliary values (% Bern)
  double latAux = (lat - 169028.66) / 10000;
  double lngAux = (lng - 26782.5) / 10000;
  double y = (600072.37 + (211455.93 * lngAux)) +
      -(10938.51 * lngAux * latAux) +
      -(0.36 * lngAux * pow(latAux, 2)) +
      -(44.54 * pow(lngAux, 3));
  return y;
}
