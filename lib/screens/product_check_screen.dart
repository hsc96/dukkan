import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductCheckScreen extends StatefulWidget {
  @override
  _ProductCheckScreenState createState() => _ProductCheckScreenState();
}

class _ProductCheckScreenState extends State<ProductCheckScreen> {
  List<Map<String, dynamic>> newProducts = [];

  @override
  void initState() {
    super.initState();
    fetchNewProducts();
  }

  Future<void> fetchNewProducts() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('newProducts').get();
    setState(() {
      newProducts = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Belge kimliğini ekliyoruz
        return data;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ürün Kontrol'),
      ),
      body: ListView.builder(
        itemCount: newProducts.length,
        itemBuilder: (context, index) {
          var product = newProducts[index];
          return ListTile(
            title: Text(product['Detay'] ?? ''),
            subtitle: Text('Kodu: ${product['Kodu']} - Kimden Alındı: ${product['supplier']}'),
          );
        },
      ),
    );
  }
}
