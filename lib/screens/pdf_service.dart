import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PDFService {
  Future<void> createPDF(String customerName, List<Map<String, dynamic>> products) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Fiyat Teklifi', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Müşteri: $customerName', style: pw.TextStyle(fontSize: 18)),
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
              ),
              pw.SizedBox(height: 16),
              pw.Text('Teklifi Hazırlayan: [Hazırlayan Adı]', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 16),
              pw.Text('Yukarıdaki fiyatlandırmanın, ürünlerin tahmini birim fiyatları baz alınarak hesaplandığını lütfen göz önünde bulundurunuz.', style: pw.TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/${customerName}_fiyat_teklifi.pdf"); // Dosya adını oluşturmak için customerName kullanıldı.
    await file.writeAsBytes(await pdf.save());
    // Burada PDF'i kullanıcıya göstermek veya paylaşmak için gerekli kodu ekleyebilirsiniz.
  }
}
