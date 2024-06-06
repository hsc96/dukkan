import 'package:pdf/widgets.dart' as pw;

class PDFTemplate {
  static pw.Document generateQuote(String customerName, List<Map<String, dynamic>> products) {
    final pdf = pw.Document();
    final tableHeaders = ['Description', 'Date', 'Quantity', 'Unit Price', 'VAT', 'Total'];

    // PDF'e eklemek için tablodaki verileri hazırlayın
    final tableData = products.map((product) {
      return [
        product['Detay']?.toString() ?? '',
        DateTime.now().toString().split(' ')[0], // Date formatını burada düzenleyebilirsiniz
        product['Adet']?.toString() ?? '',
        product['Adet Fiyatı']?.toString() ?? '',
        '19.0%', // Sabit KDV oranı, gerekirse hesaplama ekleyin
        product['Toplam Fiyat']?.toString() ?? '',
      ];
    }).toList();

    double netTotal = tableData.fold(0, (sum, item) => sum + double.tryParse(item[5])!);
    double vatAmount = netTotal * 0.19; // %19 KDV
    double totalAmountDue = netTotal + vatAmount;

    // PDF'e tablo ekleme
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Sarah Field', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Sarah Street 9, Beijing, China', style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://paypal.me/sarahfieldzz', // QR kod verisi
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Apple Inc.', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Apple Street, Cupertino, CA 95014', style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice Number: 2021-9999', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Invoice Date: 3/25/2021', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Payment Terms: 7 days', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Due Date: 4/1/2021', style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('My description...', style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Net total', style: pw.TextStyle(fontSize: 12)),
                          pw.Text(' \$${netTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Vat 19.0%', style: pw.TextStyle(fontSize: 12)),
                          pw.Text(' \$${vatAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total amount due', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(' \$${totalAmountDue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text('Address  Sarah Street 9, Beijing, China', style: pw.TextStyle(fontSize: 12)),
              pw.Text('Paypal  https://paypal.me/sarahfieldzz', style: pw.TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
