import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductsPDF {
  static Future<void> generateProductsPDF(List<Map<String, dynamic>> products, bool selectedOnly) async {
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

    String customerName = products.first['customerName'] ?? 'N/A';

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Faturalanacak Ürünler - $formattedDate', style: pw.TextStyle(fontSize: 18, font: ttf)),
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
              headers: ['SIRA', 'STOK KODU', 'MALZEME ADI', 'ADET', 'BİRİM FİYATI', 'TOPLAM FİYAT', 'BİLGİ'],
              data: products.asMap().entries.map((entry) {
                int index = entry.key + 1;
                Map<String, dynamic> product = entry.value;
                return [
                  index.toString(),
                  product['Kodu'] ?? '',
                  product['Detay'] ?? '',
                  product['Adet'] ?? '',
                  product['Adet Fiyatı'] ?? '',
                  product['Toplam Fiyat'] ?? '',
                  _buildProductInfo(product),
                ];
              }).toList(),
              cellStyle: pw.TextStyle(fontSize: 8, font: ttf),  // Tüm hücreler için yazı boyutunu 8 yapıyoruz
              headerStyle: pw.TextStyle(fontSize: 10, font: ttf, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey700),
              border: null,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.topLeft,  // Bilgi hücresi için hizalama
              },
            ),
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
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/faturalanacak_urunler_$formattedDate.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }

  static String _buildProductInfo(Map<String, dynamic> product) {
    List<String> info = [];
    if (product['buttonInfo'] == 'Teklif') {
      info.add('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}');
      info.add('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}');
      info.add('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}');
    } else if (product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A') {
      info.add('Ana Kit Adı: ${product['Ana Kit Adı']}');
      info.add('Alt Kit Adı: ${product['Alt Kit Adı'] ?? 'N/A'}');
      info.add('Oluşturan Kişi: ${product['Oluşturan Kişi'] ?? 'Admin'}');
      info.add('İşleme Alma Tarihi: ${product['işleme Alma Tarihi'] != null ? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format((product['işleme Alma Tarihi'] as Timestamp).toDate()) : 'N/A'}');
    } else if (product['whoTook'] != null && product['whoTook'] != 'N/A') {
      info.add('Ürünü Kim Aldı: ${product['whoTook']}');
      if (product['whoTook'] == 'Müşterisi') {
        info.add('Müşteri İsmi: ${product['recipient'] ?? 'N/A'}');
        info.add('Firmadan Bilgilendirilecek Kişi İsmi: ${product['contactPerson'] ?? 'N/A'}');
      } else if (product['whoTook'] == 'Kendi Firması') {
        info.add('Teslim Alan Çalışan İsmi: ${product['recipient'] ?? 'N/A'}');
      }
      info.add('Sipariş Şekli: ${product['orderMethod'] ?? 'N/A'}');
      info.add('Tarih: ${product['siparisTarihi'] ?? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}');
    } else if (product['buttonInfo'] == 'B.sipariş') {
      info.add('Beklenen Teklif Bilgisi');
      info.add('Müşteri: ${product['Müşteri'] ?? 'N/A'}');
      info.add('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}');
      info.add('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}');
      info.add('Teklif Tarihi: ${product['Teklif Tarihi'] ?? 'N/A'}');
      info.add('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}');
      if (product['Ürün Hazır Olma Tarihi'] != null) {
        DateTime readyDate = (product['Ürün Hazır Olma Tarihi'] as Timestamp).toDate();
        info.add('Ürün Hazır Olma Tarihi: ${DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(readyDate)}');
      }
    }
    return info.join('\n');
  }
}
