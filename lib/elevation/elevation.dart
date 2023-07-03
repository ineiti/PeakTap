import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

import 'tiffimage.dart';

class HeightProfileProvider {
  static const String _tilesBoxName = 'srtm_tiles';
  late Box _tilesBox;
  final String initPath;

  HeightProfileProvider({required this.initPath});

  Future<void> initialize() async {
    Hive.init(initPath);
    _tilesBox = await Hive.openBox(_tilesBoxName);
  }

  Future<int> getHeight(double latitude, double longitude) async {
    final tileData = await _getTile(latitude, longitude);
    final img = TiffImage(tileData);
    final coords = _geoToPixelCoords(latitude, longitude);
    print("Coords are: $coords");
    var pixel = img.readPixel(coords[0], coords[1]);
    print("Pixel is: $pixel");
    pixel = img.readPixel(coords[0], coords[1] + 10);
    print("Pixel is: $pixel");
    return _pixelToElevation(pixel);
    // return 0;
  }

  List<int> _geoToPixelCoords(double latitude, double longitude) {
    final latIndex = (latitude / 5).floor();
    final lonIndex = (longitude / 5).floor();
    final pixelX = ((longitude - lonIndex * 5) * 1200).round();
    final pixelY = ((5 - (latitude - latIndex * 5)) * 1200).round();
    return [pixelX, pixelY];
  }

  int _pixelToElevation(Pixel pixel) {
    return -10000 +
        ((pixel.r * 256 * 256 + pixel.g * 256 + pixel.b) * 0.1).round();
  }

  int _doubleToElevation(List<int> pixel) {
    return -10000 +
        ((pixel[0] * 256 * 256 + pixel[1] * 256 + pixel[2]) * 0.1).round();
  }

  Future<Uint8List> _getTile(double latitude, double longitude) async {
    final tileKey = _getTileKey(latitude, longitude);

    print("tile key is: $tileKey");
    if (_tilesBox.containsKey(tileKey)) {
      return _tilesBox.get(tileKey);
    }

    return await _downloadTile(tileKey);
  }

  String _getTileKey(double latitude, double longitude) {
    final lat = (12 - (latitude / 5).floor()).toString().padLeft(2, "0");
    final lon = ((longitude / 5).floor() + 37).toString().padLeft(2, "0");
    return 'srtm_${lon}_$lat';
  }

  Future<Uint8List> _downloadTile(String dataKey) async {
    // Magic calculation when looking at https://srtm.csi.cgiar.org/download
    // And it seems that the srtm website mixed up latitude and longitude, which
    // seems very strange for that project.
    final url =
        'https://srtm.csi.cgiar.org/wp-content/uploads/files/srtm_5x5/TIFF/$dataKey.zip';
    print("Downloading $url");
    var client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    print("Downloaded, status is: ${response.statusCode}");

    if (response.statusCode == 200) {
      final zipBytes = await consolidateHttpClientResponseBytes(response);
      final archive = ZipDecoder().decodeBytes(zipBytes);

      print("Searching files");
      for (final file in archive) {
        print("Found file ${file.name}");
        if (file.isFile && file.name.endsWith('.tif')) {
          await _tilesBox.put(dataKey, file.content);
          return file.content;
        }
      }

      throw Exception('SRTM tile file not found in the downloaded archive');
    } else {
      throw Exception('Failed to download SRTM tile: ${response.toString()}');
    }
  }
}
