import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerExpectedProductsWidget extends StatelessWidget {
  final String customerName;

  CustomerExpectedProductsWidget({required this.customerName});

  Future<String?> getCustomerUniqueId() async {
    var customerSnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Açıklama', isEqualTo: customerName)
        .get();

    if (customerSnapshot.docs.isEmpty) {
      return null;
    }

    var customerData = customerSnapshot.docs.first.data() as Map<String, dynamic>;
    return customerData['Vergi Kimlik Numarası']?.toString() ?? customerData['T.C. Kimlik Numarası']?.toString() ?? null;
  }

  Future<void> markProductAsReady(String productId, Map<String, dynamic> productData) async {
    var customerProductsCollection = FirebaseFirestore.instance.collection('customerDetails');
    var customerSnapshot = await customerProductsCollection.where('customerName', isEqualTo: customerName).get();

    if (customerSnapshot.docs.isNotEmpty) {
      var docRef = customerSnapshot.docs.first.reference;
      var existingProducts = List<Map<String, dynamic>>.from(customerSnapshot.docs.first.data()['products'] ?? []);
      existingProducts.add({
        'Kodu': productData['Kodu'],
        'Detay': productData['Detay'],
        'Adet': productData['Adet'],
        'Adet Fiyatı': productData['Adet Fiyatı'],
        'Toplam Fiyat': (double.tryParse(productData['Adet']?.toString() ?? '0') ?? 0) *
            (double.tryParse(productData['Adet Fiyatı']?.toString() ?? '0') ?? 0),
        'Teklif Numarası': productData['Teklif No'],
        'Teklif Tarihi': productData['Teklif Tarihi'],
        'Sipariş Numarası': productData['Sipariş No'],
        'Sipariş Tarihi': productData['Sipariş Tarihi'],
        'Beklenen Teklif': true, // Ek bilgi
        'Ürün Hazır Olma Tarihi': Timestamp.now(), // Ürün hazır olma tarihi
      });

      await docRef.update({
        'products': existingProducts,
      });

      // Remove product from pendingProducts collection
      await FirebaseFirestore.instance.collection('pendingProducts').doc(productId).delete();
    }
  }




  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: getCustomerUniqueId(),
      builder: (context, uniqueIdSnapshot) {
        if (uniqueIdSnapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (uniqueIdSnapshot.hasError || !uniqueIdSnapshot.hasData) {
          return Text('Hata: ${uniqueIdSnapshot.error}');
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('pendingProducts')
              .where('Unique ID', isEqualTo: uniqueIdSnapshot.data)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text('Hata: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('Beklenen ürün yok');
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
              shrinkWrap: true,
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
                        Text('Müşteri: ${data['Müşteri Ünvanı'] ?? 'Müşteri bilgisi yok'}'),
                        Text('Tahmini Teslim Tarihi: ${deliveryDate != null ? DateFormat('dd MMMM yyyy').format(deliveryDate) : 'Tarih yok'}'),
                      ],
                    ),
                    children: [
                      ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kodu: ${data['Kodu'] ?? 'Kodu yok'}'),
                            Text('Teklif No: ${data['Teklif No'] ?? 'Teklif numarası yok'}'),
                            Text('Sipariş No: ${data['Sipariş No'] ?? 'Sipariş numarası yok'}'),
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
        );
      },
    );
  }
}
