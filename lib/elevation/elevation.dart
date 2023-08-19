import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import 'tiffimage.dart';

class HeightProfileProvider {
  final String initPath;
  final List<List<TiffImage?>> _tiles =
      List.generate(99, (_) => List.generate(99, (_) => null));
  final Map<String, bool> _downloading = {};
  final _downloadLog = StreamController<HPMessage>.broadcast();

  static Future<HeightProfileProvider> withAppDir() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    var appDocPath = appDocDir.path;

    return HeightProfileProvider(initPath: appDocPath);
  }

  HeightProfileProvider({required this.initPath});

  Stream<HPMessage> downloadLogStream() {
    return _downloadLog.stream;
  }

  Future<int> getHeightAsync(LatLng pos) async {
    try {
      return getHeight(pos);
    } catch (e) {
      await getTile(pos);
      return getHeight(pos);
    }
  }

  int getHeight(LatLng pos) {
    final (lat, lon) = _getTileIndex(pos);

    if (_tiles[lat][lon] == null) {
      throw ("Tile not in cache");
    }

    var height = _tiles[lat][lon]!.readPixel(pos);
    if (height == -32768) {
      // The SRTM maps encode -32768 as the sea height.
      return 0;
    }
    return height;
  }

  Future<void> getTile(LatLng pos) async {
    final (lat, lon) = _getTileIndex(pos);
    final tileKey =
        'srtm_${lon.toString().padLeft(2, "0")}_${lat.toString().padLeft(2, "0")}';

    Uint8List? tileData;
    var tileFile = File("$initPath/$tileKey.tiff");
    if (tileFile.existsSync()) {
      tileData = tileFile.readAsBytesSync();
    } else {
      if (_downloading.containsKey(tileKey)) {
        while (_downloading[tileKey]!) {
          // print("Waiting for download to finish");
          sleep(const Duration(seconds: 1));
        }
        // print("Download finished");
        return;
      } else {
        _downloading[tileKey] = true;
        tileData = await _downloadTile(tileKey);
        // DEBUG: don't save for the moment
        tileFile.writeAsBytesSync(tileData);
        _downloading[tileKey] = false;
      }
      _downloading[tileKey] = false;
    }
    _tiles[lat][lon] = TiffImage(tileData);
  }

  (int, int) _getTileIndex(LatLng pos) {
    // Magic calculation when looking at https://srtm.csi.cgiar.org/download
    // And it seems that the srtm website mixed up latitude and longitude, which
    // seems very strange for that project.
    final lat = (12 - (pos.latitude / 5).floor());
    final lon = ((pos.longitude / 5).floor() + 37);
    return (lat, lon);
  }

  Future<Uint8List> _downloadTile(String dataKey) async {
    _downloadLog.add(HPMessage(dataKey, 0));
    // await Future.delayed(const Duration(microseconds: 1));

    final url = 'https://srtm.csi.cgiar.org'
        '/wp-content/uploads/files/srtm_5x5/TIFF/$dataKey.zip';

    final response = await Dio()
        .get<List<int>>(url, options: Options(responseType: ResponseType.bytes),
            onReceiveProgress: (received, total) {
      int percentage = ((received / total) * 100).floor();
      _downloadLog.add(HPMessage(dataKey, percentage));
    });
    if (response.statusCode == 200) {
      // print("Unzipping");
      final archive = ZipDecoder().decodeBytes(response.data!);

      // print("Searching files");
      for (final file in archive) {
        // print("Found file ${file.name}");
        if (file.isFile && file.name.endsWith('.tif')) {
          return file.content;
        }
      }

      throw Exception('SRTM tile file not found in the downloaded archive');
    } else if (response.statusCode == 404) {
      // Missing tiles mean that it's open ocean or part of the earth that
      // hasn't been scanned, like the North- and the South-pole.
      return Uint8List(0);
    } else {
      throw ("Unknown error while downloading tile: ${response.statusMessage}");
    }
  }
}

class HPMessage {
  final String name;
  final int percentage;

  const HPMessage(this.name, this.percentage);
}
