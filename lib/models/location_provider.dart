import 'package:flutter/material.dart';

class LocationProvider extends ChangeNotifier {
  String _location = '';
  String get location => _location;

  void setLocation(String newLocation) {
    if (_location != newLocation) {
      _location = newLocation;
      notifyListeners();
    }
  }
}
