// network_service.dart

import 'dart:io';
import 'package:flutter/material.dart';

class NetworkService {
  // İnternet bağlantısını kontrol eder
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  // İnternet yoksa kullanıcıya uyarı mesajı gösterir
  static Future<void> showNoInternetDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("İnternet Bağlantı Hatası"),
          content: Text("İnternet bağlantınız yok. Lütfen internet bağlantınızı kontrol edin."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
              },
              child: Text("Tamam"),
            ),
          ],
        );
      },
    );
  }
}
