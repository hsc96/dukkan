import 'dart:async';
import 'package:flutter/material.dart';

class LoadingProvider with ChangeNotifier {
  bool _isLoading = false;
  double _progress = 0.0;

  bool get isLoading => _isLoading;
  double get progress => _progress;

  void startLoading() {
    _isLoading = true;
    _progress = 0.0;
    notifyListeners();
  }

  void updateProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    _progress = 0.0;
    notifyListeners();
  }
}
