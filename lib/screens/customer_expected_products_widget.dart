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
              DateTime aDate = (a['deliveryDate'] as Timestamp).toDate();
              DateTime bDate = (b['deliveryDate'] as Timestamp).toDate();
              return aDate.compareTo(bDate);
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
                  child: ListTile(
                    title: Text(data['Detay'] ?? 'Detay yok'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Müşteri: ${data['Müşteri Ünvanı'] ?? 'Müşteri bilgisi yok'}'),
                        Text('Tahmini Teslim Tarihi: ${deliveryDate != null ? DateFormat('dd MMMM yyyy', 'tr_TR').format(deliveryDate) : 'Tarih yok'}'),
                        Text('Teklif No: ${data['Teklif No'] ?? 'Teklif numarası yok'}'),
                        Text('Sipariş No: ${data['Sipariş No'] ?? 'Sipariş numarası yok'}'),
                        Text('Adet Fiyatı: ${data['Adet Fiyatı'] ?? 'Adet fiyatı yok'}'),
                        Text('Adet: ${data['Adet'] ?? 'Adet yok'}'),
                        Text('Teklif Tarihi: ${data['Teklif Tarihi'] ?? 'Tarih yok'}'),
                        Text('Sipariş Tarihi: ${data['Sipariş Tarihi'] ?? 'Tarih yok'}'),
                        Text('İşleme Alan: ${data['İşleme Alan'] ?? 'admin'}'),
                      ],
                    ),
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
