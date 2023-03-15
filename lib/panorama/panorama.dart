import 'dart:async' show Future;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' show atan, cos, log, max, pi, pow, sin, sqrt;

import 'package:image/image.dart' as img;

class PanoramaCH {
  late int ncols, nrows;
  late double xllcorner, xulcorner, yllcorner, cellsize, nodataValue;
  late List<List<double>> elevation;

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

  double getHeightAtCoordinateInterpolate(double x, double y) {
    x = (x - xllcorner) / cellsize;
    y = (yllcorner / cellsize + nrows) - y / cellsize;
    var x_0 = x.round();
    var y_0 = y.round();
    var p0 = getData(x_0, y_0);
    var pX = getData(x_0 + 1, y_0);
    if (x_0 > x) {
      pX = getData(x_0 - 1, y_0);
    }

    var pY = getData(x_0, y_0 + 1);
    if (y_0 > y) {
      pY = getData(x_0, y_0 - 1);
    }
    return p0 + (x - x_0).abs() * (pX - p0) + (y - y_0).abs() * (pY - p0);
  }

  double getData(int x, int y) {
    if (x < 0 || x >= ncols || y < 0 || y >= nrows) {
      return 0;
    }
    return elevation[y][x];
  }
}

class PanoramaImage {
  PanoramaCH ch;
  CoordCH location;
  img.Image tmpImage;
  List<List<CoordCH?>> reverse;

  double horStart = 0, horEnd = 360;
  double verStart = -5, verEnd = 25;

  PanoramaImage(this.ch, this.location, int height)
      : tmpImage = img.Image(width: height * 12, height: height),
        reverse = List.generate(height, (i) => List.filled(height * 12, null)) {
    _drawPanorama();
    // _drawMap();
  }

  Uint8List getImageAsU8() {
    return img.encodePng(tmpImage);
  }

  CoordGPS? toGPS(Size size, Offset pos) {
    // print("size is: $size - ${size.width} x ${size.height}");
    final mult = size.height / tmpImage.height;
    final offset = (tmpImage.width * mult - size.width) / 2;
    // print("offset is: $offset");
    final mapX = (pos.dx + offset) ~/ mult;
    final mapY = pos.dy ~/ mult;
    // print("mapX: $mapX - mapY: $mapY");
    if (mapX >= 0 && mapX < tmpImage.width) {
      var c = reverse[mapY][mapX];
      if (c == null) {
        print("Touch the sky");
      } else {
        print("CoordCH: ${c.x} - ${c.y}");
        return c.toGPS();
      }
    }
    return null;
  }

  void _drawMap() {
    var multX = ch.ncols / tmpImage.width;
    var multY = ch.nrows / tmpImage.height;
    for (var pixel in tmpImage) {
      var gray =
          ch.getData((pixel.x * multX).toInt(), (pixel.y * multY).toInt()) / 20;
      // Set the pixels red value to its x position value, creating a gradient.
      pixel
        ..r = gray
        ..g = gray
        ..b = gray;
    }
  }

  void _drawPanorama() {
    print("image is: ${tmpImage.height} at ${location.x} ${location.y}");
    for (var vert = 0; vert < tmpImage.width; vert++) {
      // Get the height of the observer
      var x = location.x;
      var y = location.y;
      var horAngle =
          horStart + (horEnd - horStart) * vert / tmpImage.width / 180 * pi;
      horAngle = (2 * pi - horAngle) + pi / 2;
      var verAngleMax = -180.0;
      var distance = 1.0;
      var dx = cos(horAngle) * ch.cellsize;
      var dy = sin(horAngle) * ch.cellsize;
      var heightReference = ch.getHeightAtCoordinateInterpolate(x, y) + 100;
      while (true) {
        x += dx;
        y += dy;
        var height = ch.getHeightAtCoordinateInterpolate(x, y);
        if (height == 0) {
          break;
        }

        var verAngle = atan((height - heightReference) / distance) * 180 / pi;
        if (verAngle > verAngleMax) {
          var mult = 1e-3;
          var gray = max((log(distance * mult) * 255 / log(100000 * mult)), 0);
          for (var j = 0; j < tmpImage.height; j++) {
            var verAnglePan =
                verEnd + (verStart - verEnd) * j / tmpImage.height;
            if (verAnglePan > verAngle) {
              continue;
            }
            if (verAnglePan < verAngleMax) {
              break;
            }
            tmpImage.setPixelRgb(vert, j, gray, gray, gray);
            reverse[j][vert] = CoordCH(x, y);
          }
          verAngleMax = verAngle;
        }

        distance += sqrt(dx * dx + dy * dy);
      }
    }
  }
}

class CoordGPS {
  double lat;
  double lng;

  CoordGPS(this.lat, this.lng) {}

  CoordCH toCH() {
    return CoordCH(_WGStoCHy(lat, lng), _WGStoCHx(lat, lng));
  }

  List<double> toList() {
    return [lat, lng];
  }

  static CoordGPS fromList(List<double> loc) {
    return CoordGPS(loc[0], loc[1]);
  }
}

class CoordCH {
  double x;
  double y;

  CoordCH(this.x, this.y) {}

  CoordGPS toGPS() {
    return CoordGPS(_CHtoWGSlat(x, y), _CHtoWGSlng(x, y));
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
