import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

class PDFQuoteTemplate {
  static Future<pw.Document> generateQuote({
    required String customerName,
    required List<Map<String, dynamic>> products,
    required double total,
    required double vat,
    required double grandTotal,
    required String deliveryDate,
    required String quoteDuration,
    required String quoteNumber,
    required DateTime quoteDate,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Teklif', style: pw.TextStyle(fontSize: 18, font: ttf)),
            pw.Divider(color: PdfColors.black),
            _buildHeader(customerName, quoteNumber, quoteDate, ttf),
            pw.SizedBox(height: 16),
            _buildProductTable(products, ttf),
            pw.SizedBox(height: 16),
            _buildTotalSummary(total, vat, grandTotal, ttf),
            pw.SizedBox(height: 16),
            pw.Text('Yalnız: [Tutarın yazı ile yazılmış hali]',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 16),
            _buildFooter(deliveryDate, ttf),
          ],
        ),
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(String customerName, String quoteNumber,
      DateTime quoteDate, pw.Font ttf) {
    return pw.Row(
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
            pw.Text(
                'Teklif Tarihi: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(quoteDate)}',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildProductTable(
      List<Map<String, dynamic>> products, pw.Font ttf) {
    return pw.Table.fromTextArray(
      headers: [
        'SIRA',
        'STOK KODU',
        'MALZEME ADI',
        'ADET',
        'BİRİM FİYATI',
        'TUTAR'
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
        ];
      }).toList(),
      cellStyle: pw.TextStyle(fontSize: 10, font: ttf),
      headerStyle:
      pw.TextStyle(fontSize: 10, font: ttf, color: PdfColors.white),
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
      cellDecoration: (rowIndex, columnIndex, cell) => pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.black,
            width: 0.5,
            style: pw.BorderStyle.dotted,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildTotalSummary(
      double total, double vat, double grandTotal, pw.Font ttf) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('MAL TOPLAMI: ${total.toStringAsFixed(2)} TL',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('KDV: ${vat.toStringAsFixed(2)} TL',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('GENEL TOPLAM: ${grandTotal.toStringAsFixed(2)} TL',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(String deliveryDate, pw.Font ttf) {
    return pw.Row(
      children: [
        pw.Expanded(
            child: pw.Text('TESLİM TARİHİ: $deliveryDate',
                style: pw.TextStyle(fontSize: 12, font: ttf))),
        pw.Expanded(
            child: pw.Text('MÜŞTERİ ONAYI: ',
                style: pw.TextStyle(fontSize: 12, font: ttf))),
      ],
    );
  }
}
