import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp için gerekli

class PDFSalesTemplate {
  static Future<void> generateSalesPDF(List<Map<String, dynamic>> products, String customerName, bool selectedOnly) async {
    if (products.isEmpty) {
      print('PDF oluşturulurken hata: Ürün listesi boş.');
      return;
    }

    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd MMMM yyyy', 'tr_TR').format(now);

    double total = products.fold(0, (sum, item) => sum + (double.tryParse(item['Toplam Fiyat'].toString()) ?? 0.0));
    double vat = total * 0.20;
    double grandTotal = total + vat;

    final int rowsPerPage = 20;
    int pageCount = (products.length / rowsPerPage).ceil();

    for (int i = 0; i < pageCount; i++) {
      int start = i * rowsPerPage;
      int end = start + rowsPerPage;
      if (end > products.length) end = products.length;
      var productsSubset = products.sublist(start, end);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            children: [
              pw.Text('Hesaplanacak Ürünler - $formattedDate', style: pw.TextStyle(fontSize: 18, font: ttf)),
              pw.Divider(color: PdfColors.black),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Zafer Mahallesi Bakım Onarım', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('7. Sokak No :18', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('Çorlu/TEKİRDAĞ', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('info@coskunsizdirmazlik.com', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('http://www.coskunsizdirmazlik.com', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('TEL: +90 282 673 44 47', style: pw.TextStyle(fontSize: 12, font: ttf)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Müşteri: $customerName', style: pw.TextStyle(fontSize: 12, font: ttf)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['STOK KODU', 'MALZEME ADI', 'ADET', 'BİRİM FİYATI', 'TOPLAM FİYAT', 'BİLGİ'],
                data: productsSubset.asMap().entries.map((entry) {
                  Map<String, dynamic> product = entry.value;
                  return [
                    product['Kodu'] ?? '',
                    product['Detay'] ?? '',
                    product['Adet'] ?? '',
                    product['Adet Fiyatı'] ?? '',
                    product['Toplam Fiyat'] ?? '',
                    _buildProductInfo(product, ttf),
                  ];
                }).toList(),
                cellStyle: pw.TextStyle(fontSize: 8, font: ttf),  // Tüm hücreler için yazı boyutunu 8 yapıyoruz
                headerStyle: pw.TextStyle(fontSize: 10, font: ttf, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey700),
                border: null,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.topLeft,  // Bilgi hücresi için hizalama
                },
              ),
              if (i == pageCount - 1) // Sadece son sayfada toplamları göster
                pw.Column(
                  children: [
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('MAL TOPLAMI: ${total.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12, font: ttf)),
                            pw.Text('KDV: ${vat.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12, font: ttf)),
                            pw.Text('GENEL TOPLAM: ${grandTotal.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12, font: ttf)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    try {
      final output = await getTemporaryDirectory();
      final directoryPath = "${output.path}/$customerName";

      // Klasörün var olup olmadığını kontrol edin, eğer yoksa oluşturun
      final directory = Directory(directoryPath);
      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }

      final file = File("$directoryPath/hesaplanacak_urunler_$formattedDate.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }



  static pw.Widget _buildProductInfo(Map<String, dynamic> product, pw.Font ttf) {
    List<pw.Widget> infoWidgets = [];
    if (product['buttonInfo'] == 'Teklif') {
      infoWidgets.add(pw.Text('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
    } else if (product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A') {
      infoWidgets.add(pw.Text('Ana Kit Adı: ${product['Ana Kit Adı']}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Alt Kit Adı: ${product['Alt Kit Adı'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Oluşturan Kişi: ${product['Oluşturan Kişi'] ?? 'Admin'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('İşleme Alma Tarihi: ${product['işleme Alma Tarihi'] != null ? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format((product['işleme Alma Tarihi'] as Timestamp).toDate()) : 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
    } else if (product['whoTook'] != null && product['whoTook'] != 'N/A') {
      infoWidgets.add(pw.Text('Ürünü Kim Aldı: ${product['whoTook']}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      if (product['whoTook'] == 'Müşterisi') {
        infoWidgets.add(pw.Text('Müşteri İsmi: ${product['recipient'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
        infoWidgets.add(pw.Text('Firmadan Bilgilendirilecek Kişi İsmi: ${product['contactPerson'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      } else if (product['whoTook'] == 'Kendi Firması') {
        infoWidgets.add(pw.Text('Teslim Alan Çalışan İsmi: ${product['recipient'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      }
      infoWidgets.add(pw.Text('Sipariş Şekli: ${product['orderMethod'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Tarih: ${product['siparisTarihi'] ?? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
    } else if (product['buttonInfo'] == 'B.sipariş') {
      infoWidgets.add(pw.Text('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Teklif Tarihi: ${product['Teklif Tarihi'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      infoWidgets.add(pw.Text('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      if (product['Ürün Hazır Olma Tarihi'] != null) {
        DateTime readyDate = (product['Ürün Hazır Olma Tarihi'] as Timestamp).toDate();
        infoWidgets.add(pw.Text('Ürün Hazır Olma Tarihi: ${DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(readyDate)}', style: pw.TextStyle(fontSize: 2.74, font: ttf)));
      }
    }

    return pw.Column(children: infoWidgets);
  }
}
