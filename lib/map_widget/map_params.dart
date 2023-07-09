import 'package:latlong2/latlong.dart';

enum LocationUsage {
  none,
  viewPoint,
  pointOfInterest,
}

void debug(String s){
  // print(s);
}

class MapParams {
  LatLng? location;
  LocationUsage usage = LocationUsage.none;
  bool? setupFinish;
  List<LatLng>? horizon;

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
    if (setupFinish != null) {
      debug("IsSetupFinish");
      useIt();
    }
  }

  void isHorizon(void Function(List<LatLng>) useIt){
    if (horizon != null){
      debug("IsHorizon");
      useIt(horizon!);
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
    return MapParams()..setupFinish = true;
  }

  static MapParams sendHorizon(List<LatLng> h){
    debug("SendHorizon");
    return MapParams()..horizon = h;
  }
}
