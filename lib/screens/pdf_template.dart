import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PDFTemplate {
  static Future<pw.Document> generateQuote(
      String customerName,
      List<Map<String, dynamic>> products,
      double total,
      double vat,
      double grandTotal,
      String deliveryDate,
      String quoteDuration) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Teklif', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 16),
            pw.Text('Müşteri: $customerName', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Kodu', 'Detay', 'Adet', 'Adet Fiyatı', 'İskonto', 'Toplam Fiyat'],
              data: products.map((product) {
                return [
                  product['Kodu'],
                  product['Detay'],
                  product['Adet'],
                  product['Adet Fiyatı'],
                  product['İskonto'],
                  product['Toplam Fiyat'],
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Toplam: \$${total.toStringAsFixed(2)}'),
                    pw.Text('KDV: \$${vat.toStringAsFixed(2)}'),
                    pw.Text('Genel Toplam: \$${grandTotal.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Teslim Tarihi: $deliveryDate', style: pw.TextStyle(fontSize: 18)),
            pw.Text('Teklif Süresi: $quoteDuration', style: pw.TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );

    return pdf;
  }
}
