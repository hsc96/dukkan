import 'package:pdf/widgets.dart' as pw;

class PDFTemplate {
  static pw.Document generateQuote(String customerName, List<Map<String, dynamic>> products) {
    final pdf = pw.Document();
    final tableHeaders = ['Kodu', 'Detay', 'Adet', 'Adet Fiyatı', 'İskonto', 'Toplam Fiyat'];

    // PDF'e eklemek için tablodaki verileri hazırlayın
    final tableData = products.map((product) {
      return [
        product['Kodu']?.toString() ?? '',
        product['Detay']?.toString() ?? '',
        product['Adet']?.toString() ?? '',
        product['Adet Fiyatı']?.toString() ?? '',
        product['İskonto']?.toString() ?? '',
        product['Toplam Fiyat']?.toString() ?? '',
      ];
    }).toList();

    // PDF'e tablo ekleme
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
                headers: tableHeaders,
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
