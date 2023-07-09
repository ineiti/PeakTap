import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

// Code started by ChatGPT https://chat.openai.com/share/a7fd62ce-7b91-4fa3-a5cc-bac968b584ee
// Then rewritten and implemented using
// https://developer.adobe.com/content/dam/udp/en/open/standards/tiff/TIFF6.pdf

// This can only read files from https://srtm.csi.cgiar.org/contact-us/
// and return pixels from the file.
// It checks as many tags as necessary to make sure it is not fed a different
// TIFF file type.
// Unfortunately it cannot decode any non-SRTM files.
// And as of July 4th 2023, the srtm website doesn't have a valid certificate
// anymore, so tiles cannot be downloaded without ignoring the certificate error.

class TiffImage {
  late ByteData _byteData;
  late IFD _image;
  late Endian _endianness;

  TiffImage(Uint8List fileData) {
    _byteData = ByteData.view(fileData.buffer);
    _readHeader();
  }

  void _readHeader() {
    if (_byteData.getUint16(0, Endian.little) == 0x4949) {
      _endianness = Endian.little;
    } else {
      _endianness = Endian.big;
    }

    final meaningOfLife = _byteData.getUint16(2, _endianness);
    if (meaningOfLife != 42) {
      throw Exception("Not a TIFF file");
    }

    final offset = _byteData.getUint32(4, _endianness);

    _image = IFD.fromBytes(_byteData, _endianness, offset);
    if (_image.nextOffset > 0) {
      print("There would be a next IFD at ${_image.nextOffset}");
    }

    // print("Found $_image");
  }

  int readPixel(LatLng pos) {
    // print("Position is: $pos - Top left is: (${_image.degreeTop}, ${_image.degreeLeft})");
    if (pos.latitude > _image.degreeTop ||
        pos.latitude <= _image.degreeTop - 5 ||
        pos.longitude < _image.degreeLeft ||
        pos.longitude >= _image.degreeLeft + 5) {
      print(
          "Pos is: $pos, image top left is: (${_image.degreeTop}, ${_image.degreeLeft})");
      throw Exception("Position outside of this tile");
    }

    int x = ((pos.longitude - _image.degreeLeft) / 5.0 * _image.width).floor();
    int y = ((_image.degreeTop - pos.latitude) / 5.0 * _image.height).floor();
    int strip = y ~/ _image.rowsPerStrip;
    int stripLine = y % _image.rowsPerStrip;

    int offset =
        _image.stripOffsets[strip] + (stripLine * _image.width + x) * 2;
    // print("Offset is: $offset");

    return _byteData.getInt16(offset, _endianness);
  }
}

class IFD {
  late int width;
  late int height;
  late double degreeLeft;
  late double degreeTop;
  late int rowsPerStrip;
  List<int> stripOffsets = [];
  List<int> stripByteCounts = [];
  int nextOffset = 0;

  static const int typeByte = 1;
  static const int typeASCII = 2;
  static const int typeShort = 3;
  static const int typeLong = 4;
  static const int typeRational = 5;
  static const int typeFloat = 11;
  static const int typeDouble = 12;

  static const int tagImageWidth = 0x100;
  static const int tagImageHeight = 0x101;
  static const int tagBitsPerSample = 0x102;
  static const int tagCompression = 0x103;
  static int valueCompressionNone = 1;
  static const int tagPhotometricInterpretation = 0x106;
  static int valuePhotoWhiteBlack = 0;
  static int valuePhotoBlackWhite = 1;
  static int valuePhotoRGB = 2;
  static int valuePhotoPalette = 3;
  static const int tagStripOffsets = 0x111;
  static const int tagSamplesPerPixel = 0x115;
  static const int tagRowsPerStrip = 0x116;
  static const int tagStripByteCounts = 0x117;
  static const int tagPlanarConfiguration = 0x11c;
  static const int tagSampleFormat = 0x153;

  // From https://docs.ogc.org/is/19-008r4/19-008r4.html
  static const int geoModelPixelScaleTag = 0x830e;
  static const int geoModelTiepointTag = 0x8482; // interesting
  static const int geoGeoKeyDirectoryTag = 0x87af;
  static const int geoGeoAsciiParamsTag = 0x87b1;
  static const int geoGDALNoData = 0xa481;

  static IFD fromBytes(ByteData data, Endian endianness, int offset) {
    IFD ret = IFD();
    int nbrEntries = data.getUint16(offset, endianness);

    for (int entry = 0; entry < nbrEntries; entry++) {
      final ifdOffset = offset + 2 + entry * 12;
      final tag = data.getUint16(ifdOffset, endianness);
      final type = data.getUint16(ifdOffset + 2, endianness);
      final count = data.getUint32(ifdOffset + 4, endianness);
      final offsetValue = data.getUint32(ifdOffset + 8, endianness);

      switch (tag) {
        case IFD.tagImageWidth:
          assert(count == 1);
          ret.width = offsetValue;
          break;
        case IFD.tagImageHeight:
          assert(count == 1);
          ret.height = offsetValue;
          break;
        case IFD.tagBitsPerSample:
          assert(count == 1);
          assert(offsetValue == 16);
          break;
        case IFD.tagCompression:
          assert(count == 1);
          assert(type == IFD.typeShort);
          if (offsetValue != IFD.valueCompressionNone) {
            throw "Compression not handled";
          }
          break;
        case IFD.tagPhotometricInterpretation:
          assert(type == IFD.typeShort);
          assert(count == 1);
          if (offsetValue != IFD.valuePhotoBlackWhite) {
            throw "Only support grayscale image";
          }
          break;
        case IFD.tagSamplesPerPixel:
          assert(count == 1);
          assert(offsetValue == 1);
          break;
        case IFD.tagPlanarConfiguration:
          assert(count == 1);
          assert(offsetValue == 1);
          break;
        case IFD.tagSampleFormat:
          assert(count == 1);
          assert(offsetValue == 2);
          break;
        case IFD.geoModelTiepointTag:
          // This would be interesting as it should show which points are tied
          // from the raster to the 'real' world.
          // Let's print them:
          assert(type == IFD.typeDouble);
          for (int i = 0; i < 3; i++) {
            assert(data.getFloat64(offsetValue + i * 8, endianness) == 0.0);
          }
          ret.degreeLeft = data.getFloat64(offsetValue + 3 * 8, endianness);
          ret.degreeTop = data.getFloat64(offsetValue + 4 * 8, endianness);
          break;
        case IFD.geoModelPixelScaleTag:
        case IFD.geoGeoKeyDirectoryTag:
        case IFD.geoGeoAsciiParamsTag:
        case IFD.geoGDALNoData:
          break;
        case IFD.tagStripOffsets:
          assert(type == IFD.typeLong);
          for (int i = 0; i < count; i++) {
            ret.stripOffsets
                .add(data.getUint32(offsetValue + i * 4, endianness));
          }
          break;
        case IFD.tagRowsPerStrip:
          assert(count == 1);
          ret.rowsPerStrip = offsetValue;
          break;
        case IFD.tagStripByteCounts:
          assert(type == IFD.typeLong);
          for (int i = 0; i < count; i++) {
            ret.stripByteCounts
                .add(data.getUint32(offsetValue + i * 4, endianness));
          }
          break;
        // This can be used to debug new tags, like the Geotags found at the end.
        // default:
        //   print("Field 0x${tag.toRadixString(16)} with value "
        //       "0x${offsetValue.toRadixString(16)} not handled yet");
      }
    }
    ret.nextOffset = data.getUint32(offset + 2 + nbrEntries * 12, endianness);

    return ret;
  }

  IFD();
}
