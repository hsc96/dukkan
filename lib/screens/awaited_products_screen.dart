import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class AwaitedProductsScreen extends StatefulWidget {
  @override
  _AwaitedProductsScreenState createState() => _AwaitedProductsScreenState();
}

class _AwaitedProductsScreenState extends State<AwaitedProductsScreen> {
  Future<void> markProductAsReady(String productId, Map<String, dynamic> productData) async {
    var uniqueId = productData['Unique ID'];
    var customerSnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Vergi Kimlik Numarası', isEqualTo: uniqueId)
        .get();

    if (customerSnapshot.docs.isEmpty) {
      customerSnapshot = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('T.C. Kimlik Numarası', isEqualTo: uniqueId)
          .get();
    }

    if (customerSnapshot.docs.isNotEmpty) {
      var customerData = customerSnapshot.docs.first.data() as Map<String, dynamic>;
      var customerName = customerData['Açıklama'];

      var customerProductsCollection = FirebaseFirestore.instance.collection('customerDetails');
      var customerDetailsSnapshot = await customerProductsCollection.where('customerName', isEqualTo: customerName).get();

      if (customerDetailsSnapshot.docs.isNotEmpty) {
        var docRef = customerDetailsSnapshot.docs.first.reference;
        var existingProducts = List<Map<String, dynamic>>.from(customerDetailsSnapshot.docs.first.data()['products'] ?? []);

        var productInfo = {
          'Kodu': productData['Kodu'],
          'Detay': productData['Detay'],
          'Adet': productData['Adet'],
          'Adet Fiyatı': productData['Adet Fiyatı'],
          'Toplam Fiyat': (double.tryParse(productData['Adet']?.toString() ?? '0') ?? 0) *
              (double.tryParse(productData['Adet Fiyatı']?.toString() ?? '0') ?? 0),
          'Teklif Numarası': productData['Teklif Numarası'],
          'Teklif Tarihi': productData['Teklif Tarihi'],
          'Sipariş Numarası': productData['Sipariş Numarası'],
          'Sipariş Tarihi': productData['Sipariş Tarihi'],
          'Beklenen Teklif': true,
          'Ürün Hazır Olma Tarihi': Timestamp.now(),
          'buttonInfo': 'B.sipariş', // buttonInfo alanını 'B.sipariş' olarak ayarlıyoruz
          'Müşteri': customerName // Müşteri unvanını ekliyoruz
        };

        existingProducts.add(productInfo);

        await docRef.update({
          'products': existingProducts,
        });

        // Remove product from pendingProducts collection
        await FirebaseFirestore.instance.collection('pendingProducts').doc(productId).delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Beklenen Ürünler'),
      endDrawer: CustomDrawer(),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('pendingProducts').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Beklenen ürün yok'));
          }

          var docs = snapshot.data!.docs;

          // Teslim tarihine göre sıralama
          docs.sort((a, b) {
            DateTime? aDate = a['deliveryDate'] != null ? (a['deliveryDate'] as Timestamp).toDate() : null;
            DateTime? bDate = b['deliveryDate'] != null ? (b['deliveryDate'] as Timestamp).toDate() : null;

            if (aDate == null && bDate == null) {
              return 0;
            } else if (aDate == null) {
              return 1;
            } else if (bDate == null) {
              return -1;
            } else {
              return aDate.compareTo(bDate);
            }
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              DateTime? deliveryDate = data['deliveryDate'] != null
                  ? (data['deliveryDate'] as Timestamp).toDate()
                  : null;

              return Card(
                child: ExpansionTile(
                  title: Text(data['Detay'] ?? 'Detay yok'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Müşteri: ${data['Müşteri'] ?? 'Müşteri bilgisi yok'}'),
                      Text('Tahmini Teslim Tarihi: ${deliveryDate != null ? DateFormat('dd MMMM yyyy').format(deliveryDate) : 'Tarih yok'}'),
                    ],
                  ),
                  children: [
                    ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kodu: ${data['Kodu'] ?? 'Kodu yok'}'),
                          Text('Teklif No: ${data['Teklif Numarası'] ?? 'Teklif numarası yok'}'),
                          Text('Sipariş No: ${data['Sipariş Numarası'] ?? 'Sipariş numarası yok'}'),
                          Text('Adet Fiyatı: ${data['Adet Fiyatı'] ?? 'Adet fiyatı yok'}'),
                          Text('Adet: ${data['Adet'] ?? 'Adet yok'}'),
                          Text('Teklif Tarihi: ${data['Teklif Tarihi'] ?? 'Tarih yok'}'),
                          Text('Sipariş Tarihi: ${data['Sipariş Tarihi'] ?? 'Tarih yok'}'),
                          Text('İşleme Alan: ${data['İşleme Alan'] ?? 'admin'}'),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          markProductAsReady(docs[index].id, data);
                        },
                        child: Text('Ürün Hazır'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
