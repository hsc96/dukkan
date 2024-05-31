import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
              future: FirebaseFirestore.instance.collection('urunler').get(),
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
                docs.shuffle(); // Rastgele sıralama

                var products = docs.take(3).map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return {
                    'Ana Birim': data['Ana Birim'],
                    'Barkod': data['Barkod'],
                    'Detay': data['Detay'],
                    'Gercek Stok': data['Gercek Stok'],
                    'Kodu': data['Kodu'],
                  };
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: products.map((product) {
                    return Card(
                      child: ListTile(
                        title: Text(product['Detay']),
                        subtitle: Text('Barkod: ${product['Barkod']}\nStok: ${product['Gercek Stok']}'),
                        trailing: Text('Kod: ${product['Kodu']}'),
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