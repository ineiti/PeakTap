import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import 'tiffimage.dart';

class HeightProfileProvider {
  final String initPath;
  final Map<String, TiffImage> _tiles = {};

  static Future<HeightProfileProvider>  withAppDir() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    var appDocPath = appDocDir.path;

    return HeightProfileProvider(initPath: appDocPath);
  }

  HeightProfileProvider({required this.initPath});

  Future<int> getHeight(LatLng pos) async {
    final tileImg = await _getTile(pos);
    return tileImg.readPixel(pos);
  }

  Future<TiffImage> _getTile(LatLng pos) async {
    final tileKey = _getTileKey(pos);

    if (_tiles.containsKey(tileKey)) {
      return _tiles[tileKey]!;
    }

    print("tile key is: $tileKey");

    Uint8List? tileData;
    var tileFile = File("$initPath/$tileKey.tiff");
    if (tileFile.existsSync()) {
      tileData = tileFile.readAsBytesSync();
    } else {
      tileData = await _downloadTile(tileKey);
      tileFile.writeAsBytesSync(tileData);
    }
    _tiles.putIfAbsent(tileKey, () => TiffImage(tileData!));

    return _getTile(pos);
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
    final url = Uri.https('srtm.csi.cgiar.org',
        '/wp-content/uploads/files/srtm_5x5/TIFF/$dataKey.zip');
    print("Downloading $url");
    var client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    final request = await client.getUrl(url);
    // request.headers.add("access-control-allow-origin", "*");
    // request.headers.add("Content-Type", "application/json");
    // request.headers.add("Accept", "*/*");
    // print("Header is: ${request.headers}");
    final response = await request.close();
    print("Downloaded $url, status is: ${response.statusCode}");

    if (response.statusCode == 200) {
      print("Unzipping");
      final zipBytes = await consolidateHttpClientResponseBytes(response);
      final archive = ZipDecoder().decodeBytes(zipBytes);

      print("Searching files");
      for (final file in archive) {
        print("Found file ${file.name}");
        if (file.isFile && file.name.endsWith('.tif')) {
          return file.content;
        }
      }

      throw Exception('SRTM tile file not found in the downloaded archive');
    } else {
      throw Exception('Failed to download SRTM tile: ${response.toString()}');
    }
  }
}
