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
          .where('customerName', isEqualTo: customerName)
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
                title: Text(data['product']['Detay'] ?? 'Detay yok'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tahmini Teslim Tarihi: ${deliveryDate != null ? DateFormat('dd MMMM yyyy').format(deliveryDate) : 'Tarih yok'}'),
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
