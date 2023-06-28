enum LocationUsage {
  none,
  viewPoint,
  pointOfInterest,
}

void debug(String s){
  // print(s);
}

class MapParams {
  List<double>? location;
  LocationUsage usage = LocationUsage.none;
  bool? setupFinish;
  List<List<double>>? horizon;

  void isLocation(LocationUsage u, void Function(List<double> loc) useIt) {
    if (location != null && usage == u) {
      debug("IsLocation $u");
      useIt(location!);
    }
  }

  void isLocationViewpoint(void Function(List<double> loc) useIt) {
    isLocation(LocationUsage.viewPoint, useIt);
  }

  void isLocationPOI(void Function(List<double> loc) useIt) {
    isLocation(LocationUsage.pointOfInterest, useIt);
  }

  void isSetupFinish(void Function() useIt) {
    if (setupFinish != null) {
      debug("IsSetupFinish");
      useIt();
    }
  }

  void isHorizon(void Function(List<List<double>>) useIt){
    if (horizon != null){
      debug("IsHorizon");
      useIt(horizon!);
    }
  }

  static MapParams sendLocation(List<double> loc, LocationUsage u) {
    debug("SendLocation $u");
    return MapParams()
      ..location = loc
      ..usage = u;
  }

  static MapParams sendLocationViewpoint(List<double> loc) {
    return sendLocation(loc, LocationUsage.viewPoint);
  }

  static MapParams sendLocationPOI(List<double> loc) {
    return sendLocation(loc, LocationUsage.pointOfInterest);
  }

  static MapParams sendSetupFinish() {
    debug("SendSetupFinish");
    return MapParams()..setupFinish = true;
  }

  static MapParams sendHorizon(List<List<double>> h){
    debug("SendHorizon");
    return MapParams()..horizon = h;
  }
}
