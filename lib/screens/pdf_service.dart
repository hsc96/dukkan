import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PDFService {
  Future<void> createPDF(String customerName, List<Map<String, dynamic>> products) async {
    final pdf = pw.Document();

    // Fontu yükleme
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    double total = 0;
    double vat = 0;
    double grandTotal = 0;

    for (var product in products) {
      double quantity = double.tryParse(product['Adet'].toString()) ?? 0;
      double price = double.tryParse(product['Adet Fiyatı'].toString()) ?? 0;
      double productTotal = quantity * price;
      total += productTotal;
    }
    vat = total * 0.20;
    grandTotal = total + vat;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Fiyat Teklifi', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: ttf)),
              pw.SizedBox(height: 16),
              pw.Text('Müşteri: $customerName', style: pw.TextStyle(fontSize: 18, font: ttf)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Kodu', 'Detay', 'Adet', 'Fiyat', 'İskonto', 'Toplam Fiyat'],
                data: products.map((product) {
                  return [
                    product['Kodu']?.toString() ?? '',
                    product['Detay']?.toString() ?? '',
                    product['Adet']?.toString() ?? '',
                    product['Adet Fiyatı']?.toString() ?? '',
                    product['İskonto']?.toString() ?? '',
                    product['Toplam Fiyat']?.toString() ?? '',
                  ];
                }).toList(),
                border: null,
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Toplam: \$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('KDV: \$${vat.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, font: ttf)),
                      pw.Text('Genel Toplam: \$${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, font: ttf)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text('Teklifi Hazırlayan: [Hazırlayan Adı]', style: pw.TextStyle(fontSize: 16, font: ttf)),
              pw.SizedBox(height: 16),
              pw.Text('Yukarıdaki fiyatlandırmanın, ürünlerin tahmini birim fiyatları baz alınarak hesaplandığını lütfen göz önünde bulundurunuz.', style: pw.TextStyle(fontSize: 12, font: ttf)),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/${customerName}_fiyat_teklifi.pdf");
    await file.writeAsBytes(await pdf.save());
    // Burada PDF'i kullanıcıya göstermek veya paylaşmak için gerekli kodu ekleyebilirsiniz.
  }
}
