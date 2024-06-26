import 'package:flutter/material.dart';

class QuoteScreen extends StatelessWidget {
  final String quoteNumber;
  final List<Map<String, dynamic>> products;

  QuoteScreen({required this.quoteNumber, required this.products});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teklif Detayları - $quoteNumber'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Kodu')),
              DataColumn(label: Text('Detay')),
              DataColumn(label: Text('Adet')),
              DataColumn(label: Text('Adet Fiyatiı')),
              DataColumn(label: Text('İskonto')),
              DataColumn(label: Text('Toplam Fiyat')),
            ],
            rows: products.map((product) {
              return DataRow(cells: [
                DataCell(Text(product['Kodu']?.toString() ?? '')),
                DataCell(Text(product['Detay']?.toString() ?? '')),
                DataCell(Text(product['Adet']?.toString() ?? '')),
                DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                DataCell(Text(product['İskonto']?.toString() ?? '')),
                DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
