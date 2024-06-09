import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerName;

  CustomerDetailsScreen({required this.customerName});

  @override
  _CustomerDetailsScreenState createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    fetchCustomerProducts();
  }

  Future<void> fetchCustomerProducts() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('customerProducts')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    var docs = querySnapshot.docs;
    var productsList = docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'Kodu': data['Kodu'] ?? '',
        'Detay': data['Detay'] ?? '',
        'Adet': data['Adet'] ?? '',
        'Adet Fiyatı': data['Adet Fiyatı'] ?? '',
        'Toplam Fiyat': data['Toplam Fiyat'] ?? '',
        'İskonto': data['İskonto'] ?? ''
      };
    }).toList();

    setState(() {
      products = productsList;
    });
  }

  void addProduct(Map<String, dynamic> product) {
    setState(() {
      products.add(product);
    });
    saveProductToFirestore(product);
  }

  Future<void> saveProductToFirestore(Map<String, dynamic> product) async {
    await FirebaseFirestore.instance.collection('customerProducts').add({
      'customerName': widget.customerName,
      ...product,
    });
  }

  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(products[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      products[index]['Adet'] = quantity;
      products[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);
    });
    saveProductToFirestore(products[index]);
  }

  void removeProduct(int index) {
    setState(() {
      products.removeAt(index);
    });
    // Firestore'dan da ürünü silmek için kod eklenebilir
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: '${widget.customerName} - Detaylar'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Kodu')),
                    DataColumn(label: Text('Detay')),
                    DataColumn(label: Text('Adet')),
                    DataColumn(label: Text('Adet Fiyatı')),
                    DataColumn(label: Text('İskonto')),
                    DataColumn(label: Text('Toplam Fiyat')),
                    DataColumn(label: Text('Sil')),
                  ],
                  rows: products.map((product) {
                    int index = products.indexOf(product);
                    return DataRow(cells: [
                      DataCell(Text(product['Kodu']?.toString() ?? '')),
                      DataCell(Text(product['Detay']?.toString() ?? '')),
                      DataCell(
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => updateQuantity(index, value),
                          controller: TextEditingController()..text = product['Adet']?.toString() ?? '',
                        ),
                      ),
                      DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                      DataCell(Text(product['İskonto']?.toString() ?? '')),
                      DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeProduct(index),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
