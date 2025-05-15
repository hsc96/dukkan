// lib/excel_export_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExcelExportScreen extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String customerName; // Firestore’daki “Açıklama” alanı

  const ExcelExportScreen({
    Key? key,
    required this.products,
    required this.customerName,
  }) : super(key: key);

  @override
  _ExcelExportScreenState createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndOpenExcel());
  }

  Future<void> _generateAndOpenExcel() async {
    final products = widget.products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün listesi boş, Excel oluşturulamadı.')),
      );
      Navigator.of(context).pop();
      return;
    }

    // Firestore’dan müşteri belgesini çek
    String unvan = '';
    String kodu  = '';
    try {
      final qs = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('Açıklama', isEqualTo: widget.customerName)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        final data = qs.docs.first.data();
        unvan = (data['unvan'] ?? '').toString();
        kodu  = (data['Kodu']   ?? '').toString();
      }
    } catch (_) { /* hata olsa da atla */ }

    // Toplamları hesapla
    double total     = products.fold(0.0, (s, p) => s + (double.tryParse(p['Toplam Fiyat'].toString()) ?? 0.0));
    double vatTotal  = total * 0.20;
    double grandTotal= total + vatTotal;

    // Excel oluştur
    final wb    = xlsio.Workbook();
    final sheet = wb.worksheets[0];

    // Başlıklar A–F
    sheet.getRangeByName('A1').setText('STOK KODU');
    sheet.getRangeByName('B1').setText('MALZEME ADI');
    sheet.getRangeByName('C1').setText('ADET');
    sheet.getRangeByName('D1').setText('BİRİM FİYAT');
    sheet.getRangeByName('E1').setText('KDV (%)');
    sheet.getRangeByName('F1').setText('TOPLAM FİYAT');

    // Ünvan & Kodu başlıkları H sütunu
    sheet.getRangeByName('H1').setText('Müşteri Ünvanı');
    sheet.getRangeByName('H2').setText(unvan);
    sheet.getRangeByName('H3').setText('Müşteri Kodu');
    sheet.getRangeByName('H4').setText(kodu);

    // Ürünleri yaz
    for (int i = 0; i < products.length; i++) {
      final r = i + 2;
      final p = products[i];
      sheet.getRangeByIndex(r, 1).setText(p['Kodu']?.toString()           ?? '');
      sheet.getRangeByIndex(r, 2).setText(p['Detay']?.toString()         ?? '');
      sheet.getRangeByIndex(r, 3).setNumber(
          (int.tryParse(p['Adet']?.toString() ?? '') ?? 0).toDouble()
      );
      sheet.getRangeByIndex(r, 4).setText(
          (double.tryParse(p['Adet Fiyatı']?.toString() ?? '') ?? 0.0)
              .toStringAsFixed(2)
              .replaceAll('.', ',')
      );
      sheet.getRangeByIndex(r, 5).setNumber(20);
      sheet.getRangeByIndex(r, 6).setText(
          (double.tryParse(p['Toplam Fiyat']?.toString() ?? '') ?? 0.0)
              .toStringAsFixed(2)
              .replaceAll('.', ',')
      );
    }

    // Alt toplamlar
    final footer = products.length + 3;
    sheet.getRangeByIndex(footer,    5).setText('Toplam:');
    sheet.getRangeByIndex(footer,    6).setText(total.toStringAsFixed(2).replaceAll('.', ','));
    sheet.getRangeByIndex(footer+1,  5).setText('KDV %20:');
    sheet.getRangeByIndex(footer+1,  6).setText(vatTotal.toStringAsFixed(2).replaceAll('.', ','));
    sheet.getRangeByIndex(footer+2,  5).setText('Genel Toplam:');
    sheet.getRangeByIndex(footer+2,  6).setText(grandTotal.toStringAsFixed(2).replaceAll('.', ','));

    // Kaydet & aç
    final bytes = wb.saveAsStream();
    wb.dispose();
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.customerName}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Excel hazırlanıyor...')),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
