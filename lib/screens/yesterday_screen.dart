import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';

class YesterdayScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Örnek veri
    List<Map<String, dynamic>> yesterdayData = [
      {"customer": "Mehmet", "sales": "200,20 TL", "offer": "X", "currentSales": "X"},
      {"customer": "Ahmet", "sales": "X", "offer": "4320 TL", "currentSales": "645 TL"},
      {"customer": "Hasan", "sales": "150,00 TL", "offer": "X", "currentSales": "X"},
      {"customer": "Ayşe", "sales": "X", "offer": "X", "currentSales": "500 TL"},
    ];

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Dün',
        showYesterdayButton: false, // "Dün" butonu olmadan
      ),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MÜŞTERİ - SATIŞ - TEKLİF - CARİ SATIŞ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('MÜŞTERİ')),
                    DataColumn(label: Text('SATIŞ')),
                    DataColumn(label: Text('TEKLİF')),
                    DataColumn(label: Text('CARİ SATIŞ')),
                  ],
                  rows: yesterdayData.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item["customer"])),
                      DataCell(Text(item["sales"])),
                      DataCell(Text(item["offer"])),
                      DataCell(Text(item["currentSales"])),
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
