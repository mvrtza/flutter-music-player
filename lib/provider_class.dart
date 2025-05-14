import 'package:flutter/material.dart';

class ProviderClassName with ChangeNotifier {
  int value = 0;

  void setValue(int newValue) {
    value = newValue;
    notifyListeners();
  }

  int getValue() {
    return value;
  }
}