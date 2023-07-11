import 'package:latlong2/latlong.dart';

enum LocationUsage {
  none,
  viewPoint,
  pointOfInterest,
}

enum Message {
  fitHorizon,
  setupFinish,
}

void debug(String s){
  // print(s);
}

class MapParams {
  LatLng? location;
  LocationUsage usage = LocationUsage.none;
  Message ?message;
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
    if (message == Message.setupFinish) {
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

  void isFitHorizon(void Function() useIt){
    if (message == Message.fitHorizon){
      debug("IsFitHorizon");
      useIt();
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

  static MapParams sendHorizon(List<LatLng> h){
    debug("SendHorizon");
    return MapParams()..horizon = h;
  }

  static MapParams sendFitHorizon(){
    return MapParams()..message = Message.fitHorizon;
  }
}
