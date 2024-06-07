import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

class PDFTemplate {
  static Future<pw.Document> generateQuote(String customerName, List<Map<String, dynamic>> products, double toplamTutar, double kdv, double genelToplam, String teslimTarihi, String teklifSuresi) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(await rootBundle.load("lib/assets/fonts/Roboto-Regular.ttf"));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // Üst kısım
              pw.Container(
                color: PdfColors.deepOrange,
                height: 20,
              ),
              pw.SizedBox(height: 10),
              // Başlık ve müşteri bilgileri
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Coşkun Hidrolik Pnömatik Sız. Elemanları',
                        style: pw.TextStyle(fontSize: 18, font: font),
                      ),
                      pw.Text('Çorlu / Türkiye', style: pw.TextStyle(font: font)),
                      pw.Text('İletişim Bilgileri', style: pw.TextStyle(font: font)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FİYAT TEKLİFİ', style: pw.TextStyle(fontSize: 18, font: font)),
                      pw.SizedBox(height: 10),
                      pw.Text('TARİH: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}', style: pw.TextStyle(font: font)),
                      pw.Text('TESLİM TARİHİ: $teslimTarihi', style: pw.TextStyle(font: font)),
                      pw.Text('TEKLİF SÜRESİ: $teklifSuresi gün', style: pw.TextStyle(font: font)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              // Ürün tablosu
              pw.Table.fromTextArray(
                headers: ['Açıklama', 'Birim', 'Adet Fiyat', 'Toplam Fiyat'],
                data: products.map((product) {
                  return [
                    product['Detay']?.toString() ?? '',
                    product['Adet']?.toString() ?? '',
                    product['Adet Fiyatı']?.toString() ?? '',
                    product['Toplam Fiyat']?.toString() ?? '',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                cellStyle: pw.TextStyle(font: font),
                cellHeight: 25,
              ),
              pw.SizedBox(height: 20),
              // Alt kısım

              pw.SizedBox(height: 20),
              // Alt kısımda tekrar turuncu şerit
              pw.Container(
                color: PdfColors.deepOrange,
                height: 20,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
