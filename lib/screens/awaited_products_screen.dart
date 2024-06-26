import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class AwaitedProductsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Beklenen Ürünler'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beklenen Ürünler',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('pendingProducts').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Hata: ${snapshot.error}');
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('Veri bulunamadı');
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
                            Text('Müşteri: ${data['customerName'] ?? 'Müşteri bilgisi yok'}'),
                            Text('Tahmini Teslim Tarihi: ${deliveryDate != null ? DateFormat('dd MMMM yyyy').format(deliveryDate) : 'Tarih bilgisi yok'}'),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
