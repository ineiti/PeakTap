import 'dart:typed_data';

// Code started by ChatGPT https://chat.openai.com/share/a7fd62ce-7b91-4fa3-a5cc-bac968b584ee
// Then rewritten and implemented using
// https://developer.adobe.com/content/dam/udp/en/open/standards/tiff/TIFF6.pdf

class TiffImage {
  late ByteData _byteData;
  late int _width;
  late int _height;
  late int _bitsPerSample;
  late List<int> _data;
  late Endian endianness;

  TiffImage(Uint8List fileData) {
    _byteData = ByteData.view(fileData.buffer);
    _readHeader();
  }

  void _readHeader() {
    if (_byteData.getUint16(0, Endian.little) == 0x4949) {
      print("Little Endian");
      endianness = Endian.little;
    } else {
      print("Big Endian");
      endianness = Endian.big;
    }

    final meaningOfLife = _byteData.getUint16(2, endianness);
    if (meaningOfLife != 42) {
      throw Exception("Not a TIFF file");
    }

    final offset = _byteData.getUint32(4, endianness);

    final ifd = IFD.fromBytes(_byteData, endianness, offset);

    print("Found $ifd");
  }

  void _readImageData(int stripOffset) {
    final bytesPerRow = (_width * _bitsPerSample) ~/ 8;
    final bytesPerPixel = _bitsPerSample ~/ 8;
    final imageSize = bytesPerRow * _height;
    _data = List<int>.filled(imageSize, 0);

    for (var i = 0; i < imageSize; i += bytesPerPixel) {
      final pixelOffset = stripOffset + i * bytesPerPixel;
      final pixelValue = _readPixelValue(pixelOffset, bytesPerPixel);
      _data[i] = pixelValue;
    }
  }

  int _readPixelValue(int pixelOffset, int bytesPerPixel) {
    if (bytesPerPixel == 1) {
      return _byteData.getUint8(pixelOffset);
    } else if (bytesPerPixel == 2) {
      return _byteData.getUint16(pixelOffset, endianness);
    } else {
      throw Exception('Unsupported bit depth.');
    }
  }

  Pixel readPixel(int x, int y) {
    final bytesPerRow = (_width * _bitsPerSample) ~/ 8;
    final bytesPerPixel = _bitsPerSample ~/ 8;
    final pixelIndex = y * bytesPerRow + x * bytesPerPixel;

    if (pixelIndex >= 0 && pixelIndex < _data.length) {
      return Pixel(_data[pixelIndex], 0, 0);
    } else {
      throw Exception('Invalid pixel coordinates.');
    }
  }
}

class IFD {
  int nbrEntries;
  int? width;
  int? height;
  int? bits;

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
  static const int tagStropOffsets = 0x111;
  static const int tagRowsPerStrip = 0x116;
  static const int tagStripByteCounts = 0x117;

  static IFD fromBytes(ByteData data, Endian endianness, int offset) {
    IFD ret = IFD(data.getUint16(offset, endianness));

    print("Found ${ret.nbrEntries} entries");
    for (int entry = 0; entry < ret.nbrEntries; entry++) {
      final ifdOffset = offset + 2 + entry * 12;
      final tag = data.getUint16(ifdOffset, endianness);
      final type = data.getUint16(ifdOffset + 2, endianness);
      final count = data.getUint32(ifdOffset + 4, endianness);
      final offsetValue = data.getUint32(ifdOffset + 8, endianness);

      switch (tag) {
        case IFD.tagImageWidth:
          ret.width = offsetValue;
          break;
        case IFD.tagImageHeight:
          ret.height = offsetValue;
          break;
        case IFD.tagBitsPerSample:
          print("Bits per sample: $offsetValue");
          ret.bits = offsetValue;
          break;
        case IFD.tagCompression:
          if (offsetValue != IFD.valueCompressionNone) {
            throw "Compression not handled";
          }
          break;
        case IFD.tagPhotometricInterpretation:
          print("Photometric is ${offsetValue}");
          if (offsetValue != IFD.valuePhotoBlackWhite) {
            throw "Only support grayscale image";
          }
          break;
        default:
          print("Field 0x${tag.toRadixString(16)} with value "
              "0x${offsetValue.toRadixString(16)} not handled yet");
      }
    }

    return ret;
  }

  IFD(this.nbrEntries);
}

class Pixel {
  final int r, g, b;

  Pixel(this.r, this.g, this.b);
}

void testIt() {
  final fileData = Uint8List.fromList([
    // TIFF file data goes here
  ]);

  final image = TiffImage(fileData);

  final red = image.readPixel(0, 0);
  final green = image.readPixel(0, 1);
  final blue = image.readPixel(0, 2);

  print('Red: $red, Green: $green, Blue: $blue');
}
