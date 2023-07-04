import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';

import 'tiffimage.dart';

// TODO: make cache of tiles so the TIFF files doesn't need to be read
// every time a point is asked...

class HeightProfileProvider {
  static const String _tilesBoxName = 'srtm_tiles';
  late Box _tilesBox;
  final String initPath;

  HeightProfileProvider({required this.initPath});

  Future<void> initialize() async {
    Hive.init(initPath);
    _tilesBox = await Hive.openBox(_tilesBoxName);
  }

  Future<int> getHeight(LatLng pos) async {
    final tileData = await _getTile(pos);
    final img = TiffImage(tileData);
    return img.readPixel(pos);
  }

  Future<Uint8List> _getTile(LatLng pos) async {
    final tileKey = _getTileKey(pos);

    // print("tile key is: $tileKey");
    if (_tilesBox.containsKey(tileKey)) {
      return _tilesBox.get(tileKey);
    }

    return await _downloadTile(tileKey);
  }

  String _getTileKey(LatLng pos) {
    final lat = (12 - (pos.latitude / 5).floor()).toString().padLeft(2, "0");
    final lon = ((pos.longitude / 5).floor() + 37).toString().padLeft(2, "0");
    return 'srtm_${lon}_$lat';
  }

  Future<Uint8List> _downloadTile(String dataKey) async {
    // Magic calculation when looking at https://srtm.csi.cgiar.org/download
    // And it seems that the srtm website mixed up latitude and longitude, which
    // seems very strange for that project.
    final url =
        'https://srtm.csi.cgiar.org/wp-content/uploads/files/srtm_5x5/TIFF/$dataKey.zip';
    // print("Downloading $url");
    var client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    // print("Downloaded, status is: ${response.statusCode}");

    if (response.statusCode == 200) {
      final zipBytes = await consolidateHttpClientResponseBytes(response);
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // print("Searching files");
      for (final file in archive) {
        // print("Found file ${file.name}");
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
