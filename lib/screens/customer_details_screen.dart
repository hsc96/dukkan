import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerName;

  CustomerDetailsScreen({required this.customerName});

  @override
  _CustomerDetailsScreenState createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  List<Map<String, dynamic>> customerProducts = [];
  bool isEditing = false;
  int editingIndex = -1;

  @override
  void initState() {
    super.initState();
    fetchCustomerProducts();
  }

  Future<void> fetchCustomerProducts() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('customerDetails')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      setState(() {
        customerProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
      });
    }
  }

  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(customerProducts[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      customerProducts[index]['Adet'] = quantity;
      customerProducts[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);
      updateTotalAndVat();
    });
  }

  void updateDiscount(int index, String discount) {
    setState(() {
      double discountRate = double.tryParse(discount) ?? 0.0;
      double originalPrice = double.tryParse(customerProducts[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      double discountedPrice = originalPrice * (1 - (discountRate / 100));
      customerProducts[index]['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
      customerProducts[index]['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
      customerProducts[index]['Toplam Fiyat'] = (discountedPrice * (double.tryParse(customerProducts[index]['Adet']?.toString() ?? '1') ?? 1)).toStringAsFixed(2);
      updateTotalAndVat();
    });
  }

  void updateTotalAndVat() {
    double toplamTutar = 0.0;
    customerProducts.forEach((product) {
      if (product['Kodu']?.toString() != '' && product['Toplam Fiyat']?.toString() != '') {
        toplamTutar += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      }
    });

    double kdv = toplamTutar * 0.20;
    double genelToplam = toplamTutar + kdv;

    setState(() {
      // Toplam Tutar, KDV %20 ve Genel Toplam satırları tablonun sonuna ekleniyor.
      customerProducts.removeWhere((product) =>
      product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
          product['Adet Fiyatı']?.toString() == 'KDV %20' ||
          product['Adet Fiyatı']?.toString() == 'Genel Toplam');

      customerProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Toplam Tutar',
        'Toplam Fiyat': toplamTutar.toStringAsFixed(2),
      });
      customerProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'KDV %20',
        'Toplam Fiyat': kdv.toStringAsFixed(2),
      });
      customerProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Genel Toplam',
        'Toplam Fiyat': genelToplam.toStringAsFixed(2),
      });
    });
  }

  void removeProduct(int index) {
    setState(() {
      customerProducts.removeAt(index);
      updateTotalAndVat();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Müşteri Detayları - ${widget.customerName}'),
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
                    DataColumn(label: Text('Düzenle')),
                  ],
                  rows: customerProducts.map((product) {
                    int index = customerProducts.indexOf(product);
                    return DataRow(cells: [
                      DataCell(Text(product['Kodu']?.toString() ?? '')),
                      DataCell(Text(product['Detay']?.toString() ?? '')),
                      DataCell(
                        isEditing && editingIndex == index
                            ? TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => updateQuantity(index, value),
                          controller: TextEditingController()..text = product['Adet']?.toString() ?? '',
                        )
                            : Text(product['Adet']?.toString() ?? ''),
                      ),
                      DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                      DataCell(
                        isEditing && editingIndex == index
                            ? TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => updateDiscount(index, value),
                          controller: TextEditingController()..text = product['İskonto']?.toString() ?? '',
                        )
                            : Text(product['İskonto']?.toString() ?? ''),
                      ),
                      DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                      DataCell(
                        isEditing && editingIndex == index
                            ? Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                setState(() {
                                  isEditing = false;
                                  editingIndex = -1;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  isEditing = false;
                                  editingIndex = -1;
                                });
                              },
                            ),
                          ],
                        )
                            : IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              isEditing = true;
                              editingIndex = index;
                            });
                          },
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
