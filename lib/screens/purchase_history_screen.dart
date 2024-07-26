import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class PurchaseHistoryScreen extends StatelessWidget {
  final String productId;
  final String productDetail; // Ürün detayını parametre olarak ekliyoruz

  PurchaseHistoryScreen({required this.productId, required this.productDetail}); // Ürün detayını alıyoruz

  Future<List<Map<String, dynamic>>> fetchSalesHistory() async {
    List<Map<String, dynamic>> salesHistory = [];

    // customerDetails koleksiyonundan verileri çekme
    var customerDetailsQuerySnapshot = await FirebaseFirestore.instance
        .collection('customerDetails')
        .get();

    for (var doc in customerDetailsQuerySnapshot.docs) {
      var data = doc.data();
      var products = data['products'] as List<dynamic>;

      for (var product in products) {
        if (product['Kodu'] == productId) {
          salesHistory.add({
            'source': 'customerDetails',
            'customerName': data['customerName'],
            'date': product['İşlem Tarihi'],
            'quantity': product['Adet'],
            'price': product['Adet Fiyatı'],
            'detail': product['Detay'],
            'documentNo': product['Sipariş Numarası'] ?? '',  // Eğer varsa belge numarasını ekleyin
          });
        }
      }
    }

    // islenenler koleksiyonundan verileri çekme
    var islenenlerQuerySnapshot = await FirebaseFirestore.instance
        .collection('islenenler')
        .get();

    for (var doc in islenenlerQuerySnapshot.docs) {
      var data = doc.data();
      var products = data['products'] as List<dynamic>;

      for (var product in products) {
        if (product['Kodu'] == productId) {
          var date = (data['date'] as Timestamp).toDate();
          var formattedDate = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(date);

          salesHistory.add({
            'source': 'islenenler',
            'customerName': data['customerName'],
            'date': formattedDate,
            'quantity': product['Adet'],
            'price': product['Adet Fiyatı'],
            'detail': product['Detay'],
            'documentNo': product['Sipariş Numarası'] ?? '',  // Eğer varsa belge numarasını ekleyin
          });
        }
      }
    }

    return salesHistory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Satış Geçmişi - $productDetail'), // App bar'da ürün detayı gösteriliyor
      endDrawer: CustomDrawer(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchSalesHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Satış geçmişi bulunamadı.'));
          }

          var salesHistory = snapshot.data!;
          var groupedHistory = <String, List<Map<String, dynamic>>>{};

          for (var entry in salesHistory) {
            if (!groupedHistory.containsKey(entry['customerName'])) {
              groupedHistory[entry['customerName']] = [];
            }
            groupedHistory[entry['customerName']]!.add(entry);
          }

          return ListView(
            children: groupedHistory.entries.map((entry) {
              var customerName = entry.key;
              var customerSales = entry.value;

              return ExpansionTile(
                title: Text(customerName),
                subtitle: Text('Satış Tarihi: ${customerSales.first['date']}'),
                children: customerSales.map((sale) {
                  return ListTile(
                    title: Text('Belge No: ${sale['documentNo']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Miktar: ${sale['quantity']}'),
                        Text('Fiyat: ${sale['price']}'),
                        Text('Satış Tarihi: ${sale['date']}'),
                      ],
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
