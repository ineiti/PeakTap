import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_panorama/elevation/elevation.dart';
import 'package:http/http.dart' as http;

void main() {
  group('HeightProfileProvider', () {
    late HeightProfileProvider provider;

    setUpAll(() async {
      // final path = await Directory.systemTemp.createTemp();
      const path = "./test_tmp";
      provider = HeightProfileProvider(initPath: path);
      await provider.initialize();
    });

    test('getHeight returns correct elevation', () async {
      // Replace the following coordinates with the ones you want to test
      // const latitude = 40.7128;
      // const longitude = -74.0060;
      const latitude = 46.0;
      const longitude = 6.0;

      // Replace this with the expected elevation for the above coordinates
      const expectedElevation = 10;

      final elevation = await provider.getHeight(latitude, longitude);
      expect(elevation, expectedElevation);
    });

  //   test('_downloadTile downloads and unzips the tile', () async {
  //     // Replace the following coordinates with the ones you want to test
  //     const latitude = 40.7128;
  //     const longitude = -74.0060;
  //
  //     // Replace this with the URL of the zipped SRTM tile for the above coordinates
  //     const url = 'https://srtm.csi.cgiar.org/wp-content/uploads/files/srtm_5x5/TIFF/srtm_40_70.tif.zip';
  //
  //     final response = File('test_resources/srtm_40_70.tif.zip').readAsBytesSync();
  //
  //     final filePath = await provider._downloadTile(latitude, longitude);
  //     final fileExists = File(filePath).existsSync();
  //
  //     expect(fileExists, true);
  //   });
  });
}
