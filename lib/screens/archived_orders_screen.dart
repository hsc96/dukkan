import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class ArchivedOrdersScreen extends StatefulWidget {
  @override
  _ArchivedOrdersScreenState createState() => _ArchivedOrdersScreenState();
}

class _ArchivedOrdersScreenState extends State<ArchivedOrdersScreen> {
  List<Map<String, dynamic>> archivedOrders = [];

  @override
  void initState() {
    super.initState();
    fetchArchivedOrders();
  }

  Future<void> fetchArchivedOrders() async {
    DateTime fifteenDaysAgo = DateTime.now().subtract(Duration(days: 15));

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('ArchivedOrders')
        .where('archiveDate', isGreaterThanOrEqualTo: fifteenDaysAgo)
        .get();

    List<Map<String, dynamic>> orders = [];

    for (var doc in snapshot.docs) {
      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        orders.add({
          'Kodu': data['Kodu'],
          'Detay': data['Detay'],
          'Adet': data['Adet'],
          'Sipariş Adeti': data['Sipariş Adeti'] ?? '',
          'Açıklama': data['Açıklama'] ?? '',
          'Talep Eden': data['Talep Eden'] ?? '',
          'Talep Tarihi': data['Talep Tarihi'],
          'Arşiv Tarihi': data['archiveDate'],
        });
      }
    }

    setState(() {
      archivedOrders = orders;
    });
  }

  Widget buildOrdersTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Kodu')),
          DataColumn(label: Text('Detay')),
          DataColumn(label: Text('Adet')),
          DataColumn(label: Text('Sipariş Adeti')),
          DataColumn(label: Text('Açıklama')),
          DataColumn(label: Text('Talep Eden')),
          DataColumn(label: Text('Talep Tarihi')),
          DataColumn(label: Text('Arşiv Tarihi')),
        ],
        rows: archivedOrders.map((order) {
          return DataRow(cells: [
            DataCell(Text('${order['Kodu'] ?? ''}')),
            DataCell(Text('${order['Detay'] ?? ''}')),
            DataCell(Text('${order['Adet'] ?? ''}')),
            DataCell(Text('${order['Sipariş Adeti'] ?? ''}')),
            DataCell(Text('${order['Açıklama'] ?? ''}')),
            DataCell(Text('${order['Talep Eden'] ?? ''}')),
            DataCell(
              Text(
                order['Talep Tarihi'] != null
                    ? DateFormat('dd/MM/yyyy').format(
                  (order['Talep Tarihi'] as Timestamp).toDate(),
                )
                    : '',
              ),
            ),
            DataCell(
              Text(
                order['Arşiv Tarihi'] != null
                    ? DateFormat('dd/MM/yyyy').format(
                  (order['Arşiv Tarihi'] as Timestamp).toDate(),
                )
                    : '',
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Arşiv Siparişler'),
      endDrawer: CustomDrawer(),
      body: archivedOrders.isEmpty
          ? Center(child: Text('Arşivlenmiş sipariş bulunamadı.'))
          : SingleChildScrollView(
        child: Column(
          children: [
            buildOrdersTable(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
