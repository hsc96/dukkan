// lib/backup_restore_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupRestoreScreen extends StatefulWidget {
  @override
  _BackupRestoreScreenState createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isProcessing = false;

  // Depolama izinlerini istemek için fonksiyon
  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          // İzin reddedildiğinde uyarı göster
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('İzin Gerekiyor'),
                content: Text('Depolama izni yedekleme için gereklidir. Lütfen izin verin.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Tamam'),
                  ),
                ],
              ),
            );
          }
          throw Exception('Depolama izni verilmedi.');
        }
      }
    }
  }

  // Firestore verilerini yedeklemek için fonksiyon
  Future<Map<String, dynamic>> _backupFirestore() async {
    Map<String, dynamic> completeData = {};

    // Veritabanı adı 'veritabani'
    final List<String> collectionNames = [
      'veritabani/users',
      'veritabani/products',
      'veritabani/sales',
      // Diğer koleksiyon isimleri...
    ];

    for (String collectionName in collectionNames) {
      QuerySnapshot snapshots = await FirebaseFirestore.instance.collection(collectionName).get();

      List<Map<String, dynamic>> documentsData = [];
      for (var doc in snapshots.docs) {
        documentsData.add({
          'id': doc.id,
          'data': doc.data(),
        });
      }

      completeData[collectionName] = documentsData;
    }

    return completeData;
  }

  // JSON verisini SAF kullanarak kaydetmek için fonksiyon
  Future<void> _saveJsonWithSAF(Map<String, dynamic> jsonData) async {
    try {
      String jsonString = jsonEncode(jsonData);
      final Uint8List data = Uint8List.fromList(jsonString.codeUnits);

      final params = SaveFileDialogParams(
        data: data,
        fileName: 'firestore_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        // mimeType: 'application/json', // Bu satırı kaldırın veya doğru parametreyi kullanın
      );

      String? path = await FlutterFileDialog.saveFile(params: params);

      if (path != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedekleme başarıyla kaydedildi: $path')),
        );

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Yedekleme Tamamlandı'),
            content: Text('Yedekleme dosyanız kaydedildi:\n\n$path'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Tamam'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Dosya kaydedilmedi.');
      }
    } catch (e) {
      print('Hata: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yedekleme başarısız: $e')),
      );
    }
  }

  // Yedekleme işlemini başlatan fonksiyon
  Future<void> _startBackup() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _requestStoragePermission();
      Map<String, dynamic> firestoreData = await _backupFirestore();
      await _saveJsonWithSAF(firestoreData);
    } catch (e, stack) {
      if (!mounted) return;
      print('Hata: $e');
      print('Stack Trace: $stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yedekleme başarısız: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // JSON dosyasını okumak için fonksiyon
  Future<Map<String, dynamic>> _readJsonFromFile(String filePath) async {
    File file = File(filePath);

    if (await file.exists()) {
      String jsonString = await file.readAsString();
      Map<String, dynamic> jsonData = jsonDecode(jsonString);
      return jsonData;
    } else {
      throw Exception('Yedek dosyası bulunamadı: $filePath');
    }
  }

  // Firestore'a verileri yüklemek için fonksiyon
  Future<void> _restoreFirestore(Map<String, dynamic> jsonData) async {
    for (String collectionName in jsonData.keys) {
      List<dynamic> documents = jsonData[collectionName];

      for (var document in documents) {
        String docId = document['id'];
        Map<String, dynamic> data = Map<String, dynamic>.from(document['data']);

        try {
          await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(docId)
              .set(data);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Belge yüklenirken hata oluştu: $e')),
          );
        }
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Veriler başarıyla yüklendi.')),
    );
  }

  // Yükleme işlemini başlatan fonksiyon
  Future<void> _startRestore() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Yedekleme dosyasını seçmek için dosya seçici aç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        String selectedFilePath = result.files.single.path!;
        Map<String, dynamic> jsonData = await _readJsonFromFile(selectedFilePath);
        await _restoreFirestore(jsonData);
      } else {
        throw Exception('Dosya seçilmedi.');
      }
    } catch (e, stack) {
      if (!mounted) return;
      print('Hata: $e');
      print('Stack Trace: $stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme başarısız: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('BackupRestoreScreen açıldı');

    return Scaffold(
      appBar: AppBar(
        title: Text('Yedekleme ve Yükleme'),
      ),
      body: Center(
        child: _isProcessing
            ? CircularProgressIndicator()
            : Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _startBackup,
                icon: Icon(Icons.backup),
                label: Text('Yedekle'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startRestore,
                icon: Icon(Icons.restore),
                label: Text('Yükle'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
