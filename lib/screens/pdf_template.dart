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
            pw.Header(
              level: 0,
              child: pw.Text('SATIŞ RSALIYESI', style: pw.TextStyle(fontSize: 24)),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FİRMA ÜNVANI: $customerName', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('YETKİLİ: ', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('TELEFON: ', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('FAKS: ', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('ADRES: ', style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('OSB Aykosan Sanayi Sitesi Dörtlü', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('A Blok No:234 Kıraç', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('Bağcılar/İSTANBUL', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('satis@madte.com.tr', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('http://www.madte.com.tr', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('TEL: +90 212 671 69 32', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('FAX: +90 212 671 69 33', style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['SIRA', 'STOK KODU', 'MALZEME ADI', 'ADET', 'BİRİM FİYATI', 'TUTAR'],
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
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('MAL TOPLAMI: ${total.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('SK. TOPLAM: 0.00 TL', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('ARA TOPLAM: ${total.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('KDV: ${vat.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('GENEL TOPLAM: ${grandTotal.toStringAsFixed(2)} TL', style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Yalnız: [Tutarın yazı ile yazılmış hali]', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 16),
            pw.Text('ÖDEME ŞEKLİ: ', style: pw.TextStyle(fontSize: 12)),
            pw.Text('TESLİM TARİHİ: $deliveryDate', style: pw.TextStyle(fontSize: 12)),
            pw.Text('TEKLİF VEREN/ŞARTLAR: ', style: pw.TextStyle(fontSize: 12)),
            pw.Text('ALAN: ', style: pw.TextStyle(fontSize: 12)),
            pw.Text('MÜŞTERİ ONAYI: ', style: pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );

    return pdf;
  }
}
