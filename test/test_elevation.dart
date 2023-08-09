import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_tap/elevation/elevation.dart';
import 'package:peak_tap/panorama_widget/panorama.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

void main() {
  group('HeightProfileProvider', () {
    late HeightProfileProvider provider;

    setUpAll(() async {
      // final path = (await Directory.systemTemp.createTemp()).path;
      const path = "./test_tmp";
      provider = HeightProfileProvider(initPath: path);
      // provider = await HeightProfileProvider.withAppDir();
    });

    test('getHeight returns correct elevation', () async {
      final tests = [
        const Tuple2(476, LatLng(46.0, 6.0)), // Random point
        const Tuple2(370, LatLng(46.496589, 6.519988)), // Lake Geneva
        const Tuple2(370, LatLng(46.451990, 6.665779)), // Lake Geneva
        const Tuple2(4770, LatLng(45.832620, 6.865174)), // Mont Blanc
        const Tuple2(-32768, LatLng(42.887981, 7.491991)), // Mediterranean sea
        const Tuple2(-415, LatLng(31.454393, 35.494922)), // Dead sea
        const Tuple2(-394, LatLng(31.133904, 35.432717)), // Dead sea 2
        const Tuple2(8729, LatLng(27.988110, 86.924970)), // Mount Everest
        const Tuple2(8326, LatLng(35.879971, 76.515084)) // K2
      ];

      for (var test in tests){
        print("Testing $test");
        expect(await provider.getHeight(test.item2), test.item1);
      }
    });

    test('performance measurements of panorama', () async {
      // Start: 3.65s-3.89s
      // simplify gray: 3.75s-3.79s
      // no await in getHeight: 192ms
      // Now this is strange, as for the real painting the speed increase is
      // not as big, but only 8.7s -> 5.1s.
      Completer<void> done = Completer();

      final pib = PanoramaImageBuilder(provider);
      pib.getStream().listen((event) {
        event.isPaintPercentage((perc) {
          if (perc % 10 == 0) {
            print("Painting: $perc%");
          }
          if (perc == 99){
            done.complete();
          }
        });
        event.isDownloadStatus((msg) {
          print("Downloading ${msg.name}: ${msg.percentage}");
        });
      });
      pib.drawPanorama(10, const LatLng(46.5, 6.5));
      await done.future;
    });
  });
}
