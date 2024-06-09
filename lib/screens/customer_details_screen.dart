import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class CustomerDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> customer;

  CustomerDetailsScreen({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Müşteri Detayları'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          Text(
            customer['Açıklama'] ?? 'Müşteri Adı Yok',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('KODU')),
                    DataColumn(label: Text('DETAY')),
                    DataColumn(label: Text('ADET')),
                    DataColumn(label: Text('ADET FİYATI')),
                    DataColumn(label: Text('TOPLAM FİYAT')),
                  ],
                  rows: _generateRows(customer),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }

  List<DataRow> _generateRows(Map<String, dynamic> customer) {
    // Bu örnek veri. Gerçek verilerinizi burada işleyip döndürebilirsiniz.
    // Örneğin: customer['products'].map((product) => DataRow(...)).toList();
    return [
      DataRow(cells: [
        DataCell(Text('001')),
        DataCell(Text('Ürün Detay')),
        DataCell(Text('10')),
        DataCell(Text('100 TL')),
        DataCell(Text('1000 TL')),
      ]),
      DataRow(cells: [
        DataCell(Text('002')),
        DataCell(Text('Başka Ürün Detay')),
        DataCell(Text('5')),
        DataCell(Text('200 TL')),
        DataCell(Text('1000 TL')),
      ]),
    ];
  }
}
