import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için
import 'archived_orders_screen.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class LowStockProductsScreen extends StatefulWidget {
  @override
  _LowStockProductsScreenState createState() => _LowStockProductsScreenState();
}

class _LowStockProductsScreenState extends State<LowStockProductsScreen> {
  List<Map<String, dynamic>> lowStockProducts = [];

  @override
  void initState() {
    super.initState();
    fetchLowStockProducts();
  }

  Future<void> fetchLowStockProducts() async {
    // Firestore'daki 'lowStockRequests' koleksiyonundan ürünleri çekiyoruz
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('lowStockRequests').get();

    List<Map<String, dynamic>> products = [];

    for (var doc in snapshot.docs) {
      Map<String, dynamic>? product = doc.data() as Map<String, dynamic>?;

      if (product != null) {
        products.add({
          'Kodu': product['Kodu'],
          'Detay': product['Detay'],
          'Adet': product['Adet']?.toString() ?? '1',
          'Sipariş Adeti': product['orderQuantity']?.toString() ?? '',
          'Açıklama': product['description'] ?? '',
          'Talep Eden': product['requestedBy'] ?? '',
          'Talep Tarihi': product['requestDate'],
        });
      }
    }

    setState(() {
      lowStockProducts = products;
    });
  }


  Widget buildProductsTable() {
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
          DataColumn(label: Text('İşlem')), // Yeni sütun
        ],
        rows: lowStockProducts.map((product) {
          return DataRow(cells: [
            DataCell(Text('${product['Kodu'] ?? ''}')),
            DataCell(Text('${product['Detay'] ?? ''}')),
            DataCell(Text('${product['Adet'] ?? ''}')),
            DataCell(Text('${product['Sipariş Adeti'] ?? ''}')),
            DataCell(Text('${product['Açıklama'] ?? ''}')),
            DataCell(Text('${product['Talep Eden'] ?? ''}')),
            DataCell(
              Text(
                product['Talep Tarihi'] != null
                    ? DateFormat('dd/MM/yyyy').format(
                  (product['Talep Tarihi'] as Timestamp).toDate(),
                )
                    : '',
              ),
            ),
            DataCell(
              ElevatedButton(
                onPressed: () {
                  processOrder(product);
                },
                child: Text('Siparişe Alındı'),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
  Future<void> processOrder(Map<String, dynamic> product) async {
    try {
      // Ürünü 'ArchivedOrders' koleksiyonuna ekle
      await FirebaseFirestore.instance.collection('ArchivedOrders').add({
        ...product,
        'archiveDate': DateTime.now(),
      });

      // 'lowStockRequests' koleksiyonundan ürünü sil
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('lowStockRequests')
          .where('Kodu', isEqualTo: product['Kodu'])
          .where('requestedBy', isEqualTo: product['Talep Eden'])
          .where('requestDate', isEqualTo: product['Talep Tarihi'])
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Listeyi güncelle
      setState(() {
        lowStockProducts.remove(product);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün siparişe alındı ve arşivlendi.')),
      );
    } catch (e) {
      print('Error processing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem sırasında bir hata oluştu: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Stok Durumu Düşük Ürünler'),
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ArchivedOrdersScreen()),
              );
            },
            child: Text('Arşiv Siparişler'),
          ),
          Expanded(
            child: lowStockProducts.isEmpty
                ? Center(child: Text('Stok durumu düşük ürün bulunamadı.'))
                : SingleChildScrollView(
              child: Column(
                children: [
                  buildProductsTable(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }

}
