import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mountain_panorama/elevation/elevation.dart';
import 'package:tuple/tuple.dart';

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
      final tests = [
        const Tuple2(476, LatLng(46.0, 6.0)), // Random point
        const Tuple2(370, LatLng(46.496589, 6.519988)), // Lake Geneva
        const Tuple2(370, LatLng(46.451990, 6.665779)), // Lake Geneva
        const Tuple2(4756, LatLng(45.832620, 6.865174)), // Mont Blanc
        const Tuple2(-32768, LatLng(42.887981, 7.491991)), // Mediterranean sea
        const Tuple2(-415, LatLng(31.454393, 35.494922)), // Dead sea
        const Tuple2(-394, LatLng(31.133904, 35.432717)), // Dead sea 2
        const Tuple2(8794, LatLng(27.988110, 86.924970)), // Mount Everest
        const Tuple2(8326, LatLng(35.879971, 76.515084)) // K2
      ];

      for (var test in tests){
        print("Testing $test");
        expect(await provider.getHeight(test.item2), test.item1);
      }

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
  });
}
