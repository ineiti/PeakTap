import 'package:latlong2/latlong.dart';
import 'package:peak_tap/elevation/elevation.dart';

enum LocationUsage {
  none,
  viewPoint,
  pointOfInterest,
}

enum Message {
  fitHorizon,
  setupFinish,
  downloadStatus,
  paintingStatus,
  exception,
}

void debug(String s) {
  // print(s);
}

class MapParams {
  LatLng? location;
  LocationUsage usage = LocationUsage.none;
  Message? message;
  List<LatLng>? horizon;
  int? paintPerc;
  HPMessage? hpMsg;
  String? strMsg;

  @override
  String toString() {
    if (message != null) {
      switch (message!) {
        case Message.fitHorizon:
          return "fitHorizon";
        case Message.setupFinish:
          return "setupFinish";
        case Message.downloadStatus:
          return "downloadStatus";
        case Message.paintingStatus:
          return "paintingStatus";
        case Message.exception:
          return "exception";
      }
    }
    return "Something else";
  }

  void isDownloadStatus(void Function(HPMessage msg) useIt) {
    if (message != null && message == Message.downloadStatus) {
      useIt(hpMsg!);
    }
  }

  void isPaintingStatus(void Function(int perc) useIt) {
    if (message != null && message == Message.paintingStatus) {
      useIt(paintPerc!);
    }
  }

  void isLocation(LocationUsage u, void Function(LatLng loc) useIt) {
    if (location != null && usage == u) {
      debug("IsLocation $u");
      useIt(location!);
    }
  }

  void isLocationViewpoint(void Function(LatLng loc) useIt) {
    isLocation(LocationUsage.viewPoint, useIt);
  }

  void isLocationPOI(void Function(LatLng loc) useIt) {
    isLocation(LocationUsage.pointOfInterest, useIt);
  }

  void isSetupFinish(void Function() useIt) {
    if (message == Message.setupFinish) {
      debug("IsSetupFinish");
      useIt();
    }
  }

  void isHorizon(void Function(List<LatLng>) useIt) {
    if (horizon != null) {
      debug("IsHorizon");
      useIt(horizon!);
    }
  }

  void isFitHorizon(void Function() useIt) {
    if (message == Message.fitHorizon) {
      debug("IsFitHorizon");
      useIt();
    }
  }

  void isException(void Function(String) useIt) {
    if (message == Message.exception) {
      useIt(strMsg!);
    }
  }

  static MapParams sendLocation(LatLng loc, LocationUsage u) {
    debug("SendLocation $u");
    return MapParams()
      ..location = loc
      ..usage = u;
  }

  static MapParams sendLocationViewpoint(LatLng loc) {
    return sendLocation(loc, LocationUsage.viewPoint);
  }

  static MapParams sendLocationPOI(LatLng loc) {
    return sendLocation(loc, LocationUsage.pointOfInterest);
  }

  static MapParams sendSetupFinish() {
    debug("SendSetupFinish");
    return MapParams()..message = Message.setupFinish;
  }

  static MapParams sendHorizon(List<LatLng> h) {
    debug("SendHorizon");
    return MapParams()..horizon = h;
  }

  static MapParams sendFitHorizon() {
    return MapParams()..message = Message.fitHorizon;
  }

  static MapParams sendDownloadStatus(HPMessage msg) {
    return MapParams()
      ..message = Message.downloadStatus
      ..hpMsg = msg;
  }

  static MapParams sendPaintingStatus(int perc) {
    return MapParams()
      ..message = Message.paintingStatus
      ..paintPerc = perc;
  }

  static MapParams sendException(String e) {
    return MapParams()
      ..message = Message.exception
      ..strMsg = e;
  }
}
