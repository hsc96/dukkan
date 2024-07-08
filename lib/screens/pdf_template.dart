import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart'; // Tarih formatı için eklenmiştir.

class PDFTemplate {
  static Future<pw.Document> generateQuote(String customerName,
      List<Map<String, dynamic>> products,
      double total,
      double vat,
      double grandTotal,
      String deliveryDate,
      String quoteDuration,
      String quoteNumber,
      DateTime quoteDate,) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) =>
            pw.Column(
              children: [
                pw.Text('Teklif', style: pw.TextStyle(fontSize: 18, font: ttf)),
                pw.Divider(color: PdfColors.black),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Zafer Mahallesi Bakım Onarım',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('7. Sokak No :18',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('Çorlu/TEKİRDAĞ',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('info@coskunsizdirmazlik.com',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('http://www.coskunsizdirmazlik.com',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('TEL: +90 282 673 44 47',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Müşteri: $customerName',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('Teklif No: $quoteNumber',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('Teklif Tarihi: ${DateFormat(
                            'dd MMMM yyyy', 'tr_TR').format(quoteDate)}',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [
                    'SIRA',
                    'STOK KODU',
                    'MALZEME ADI',
                    'ADET',
                    'BİRİM FİYATI',
                    'TUTAR'
                  ],
                  data: products
                      .asMap()
                      .entries
                      .map((entry) {
                    int index = entry.key + 1;
                    Map<String, dynamic> product = entry.value;
                    return [
                      index.toString(),
                      product['Kodu'] ?? '',
                      product['Detay'] ?? '',
                      product['Adet'] ?? '',
                      product['Adet Fiyatı'] ?? '',
                      product['Toplam Fiyat'] ?? '',
                    ];
                  }).toList(),
                  cellStyle: pw.TextStyle(fontSize: 10, font: ttf),
                  headerStyle: pw.TextStyle(
                      fontSize: 10, font: ttf, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey700),
                  border: null,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                  },
                  cellDecoration: (rowIndex, columnIndex, cell) =>
                      pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.5,
                            style: pw.BorderStyle.dotted,
                          ),
                        ),
                      ),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('MAL TOPLAMI: ${total.toStringAsFixed(2)} TL',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text('KDV: ${vat.toStringAsFixed(2)} TL',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                        pw.Text(
                            'GENEL TOPLAM: ${grandTotal.toStringAsFixed(2)} TL',
                            style: pw.TextStyle(fontSize: 12, font: ttf)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text('Yalnız: [Tutarın yazı ile yazılmış hali]',
                    style: pw.TextStyle(fontSize: 12, font: ttf)),
                pw.SizedBox(height: 16),
                pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('TESLİM TARİHİ: $deliveryDate',
                        style: pw.TextStyle(fontSize: 12, font: ttf))),
                    pw.Expanded(child: pw.Text('MÜŞTERİ ONAYI: ',
                        style: pw.TextStyle(fontSize: 12, font: ttf))),
                  ],
                ),
              ],
            ),
      ),
    );

    return pdf;
  }

  static Future<pw.Document> generateKitPDF(
      String customerName,
      List<Map<String, dynamic>> products,
      double total,
      double vat,
      double grandTotal,
      String kitName,
      DateTime kitDate,
      ) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Text('Kit: $kitName', style: pw.TextStyle(fontSize: 18, font: ttf)),
              ],
            ),
            pw.Divider(color: PdfColors.black),
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
                    pw.Text('Tarih: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(kitDate)}', style: pw.TextStyle(fontSize: 12, font: ttf)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: [
                'SIRA',
                'STOK KODU',
                'MALZEME ADI',
                'ADET',
                'BİRİM FİYATI',
                'TOPLAM FİYAT',
                'ALT KİT ADI',
              ],
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
                  product['Alt Kit Adı'] ?? '',
                ];
              }).toList(),
              cellStyle: pw.TextStyle(fontSize: 10, font: ttf),
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
                6: pw.Alignment.centerLeft,
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

    return pdf;
  }
}