import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';

class FaturalaScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Örnek veri
    List<Map<String, dynamic>> invoiceData = [
      {"customer": "Ahmet", "amount": 12532.32},
      {"customer": "Elif", "amount": 802.11},
      {"customer": "Hasan", "amount": 1500.00}, // Ek örnek veri
      {"customer": "Ayşe", "amount": 650.75}, // Ek örnek veri
    ];

    return Scaffold(
      appBar: CustomAppBar(title: 'Faturala'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MÜŞTERİ - FATURALANACAK ÜRÜNLER',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('MÜŞTERİ')),
                    DataColumn(label: Text('FATURALANACAK ÜRÜNLER')),
                  ],
                  rows: invoiceData.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item["customer"])),
                      DataCell(Text('${item["amount"].toStringAsFixed(2)} TL')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
