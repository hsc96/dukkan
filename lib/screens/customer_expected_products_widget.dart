import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerExpectedProductsWidget extends StatelessWidget {
  final String customerName;

  CustomerExpectedProductsWidget({required this.customerName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('pendingProducts')
          .where('Müşteri Ünvanı', isEqualTo: customerName)
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
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
                    Text('Teklif Tarihi: ${data['Teklif Tarihi']}'),
                    Text('Sipariş Tarihi: ${data['Sipariş Tarihi']}'),
                    Text('İşleme Alan: ${data['İşleme Alan'] ?? 'admin'}'),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
