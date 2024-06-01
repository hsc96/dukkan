import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'dovizservice.dart';
import 'firestore_service.dart';

class ScanScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  TextEditingController searchController = TextEditingController();
  List<String> customers = [];
  List<String> filteredCustomers = [];
  String? selectedCustomer;
  String barcodeResult = "";
  String dolarKur = "";
  String euroKur = "";

  List<Map<String, dynamic>> scannedProducts = [];
  final FirestoreService firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    fetchCustomers();
    fetchDovizKur();
  }

  void filterCustomers(String query) {
    setState(() {
      filteredCustomers = customers
          .where((customer) =>
          customer.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (!filteredCustomers.contains(selectedCustomer)) {
        selectedCustomer = null;
      }
    });
  }

  Future<void> fetchCustomers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('veritabanideneme').get();
    var docs = querySnapshot.docs;
    var descriptions = docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['Açıklama'] ?? 'Açıklama bilgisi yok';
    }).cast<String>().toList();

    setState(() {
      customers = descriptions;
      filteredCustomers = descriptions;
    });
  }

  Future<void> fetchDovizKur() async {
    DovizService dovizService = DovizService();
    try {
      var kurlar = await dovizService.fetchDovizKur();
      setState(() {
        dolarKur = kurlar['dolar']!;
        euroKur = kurlar['euro']!;
      });
    } catch (e) {
      setState(() {
        dolarKur = 'Hata';
        euroKur = 'Hata';
      });
    }
  }

  Future<void> scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      setState(() {
        barcodeResult = result.rawContent;
      });
      fetchProductDetails(barcodeResult);
    } catch (e) {
      setState(() {
        barcodeResult = 'Hata: $e';
      });
    }
  }

  Future<void> fetchProductDetails(String barcode) async {
    var products = await firestoreService.fetchProductsByBarcode(barcode);
    if (products.isNotEmpty) {
      if (products.length > 1) {
        showProductSelectionDialog(products);
      } else {
        addProductToTable(products.first);
      }
    }
  }

  void showProductSelectionDialog(List<Map<String, dynamic>> products) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürün Seçin'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(products[index]['Detay']),
                  onTap: () {
                    addProductToTable(products[index]);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void addProductToTable(Map<String, dynamic> productData) {
    double priceInTl = 0.0;
    double price = double.tryParse(productData['Fiyat']) ?? 0.0;
    String currency = productData['Doviz'] ?? '';

    if (currency == 'Euro') {
      priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
    }

    setState(() {
      scannedProducts.add({
        'Kodu': productData['Kodu'] ?? '',
        'Detay': productData['Detay'] ?? '',
        'Adet': '1',
        'Adet Fiyatı': priceInTl.toStringAsFixed(2),
        'Toplam Fiyat': (priceInTl * 1).toStringAsFixed(2)
      });
    });
  }

  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(scannedProducts[index]['Adet Fiyatı']) ?? 0.0;
      scannedProducts[index]['Adet'] = quantity;
      scannedProducts[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);
    });
  }

  void removeProduct(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürünü Kaldır'),
          content: Text('Bu ürünü kaldırmak istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  scannedProducts.removeAt(index);
                });
                Navigator.of(context).pop();
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Ürün Tara'),
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.barcode, size: 24, color: colorTheme5),
                onPressed: scanBarcode,
              ),
              DropdownButton<String>(
                hint: Text('MÜŞTERİ SEÇ'),
                value: selectedCustomer,
                icon: Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: TextStyle(color: Colors.black),
                underline: Container(
                  height: 2,
                  color: Colors.grey,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedCustomer = newValue;
                  });
                },
                items: filteredCustomers.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: searchController,
              onChanged: (query) => filterCustomers(query),
              decoration: InputDecoration(
                hintText: 'Müşteri ara...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.grey,
                  ),
                ),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(height: 30),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text('Kodu')),
                DataColumn(label: Text('Detay')),
                DataColumn(label: Text('Adet')),
                DataColumn(label: Text('Adet Fiyatı')),
                DataColumn(label: Text('Toplam Fiyat')),
                DataColumn(label: Text('Sil')),
              ],
              rows: scannedProducts.map((product) {
                int index = scannedProducts.indexOf(product);
                return DataRow(cells: [
                  DataCell(Text(product['Kodu'])),
                  DataCell(Text(product['Detay'])),
                  DataCell(
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => updateQuantity(index, value),
                      controller: TextEditingController()..text = product['Adet'],
                    ),
                  ),
                  DataCell(Text(product['Adet Fiyatı'])),
                  DataCell(Text(product['Toplam Fiyat'])),
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
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
      bottomSheet: Container(
        padding: EdgeInsets.all(8),
        color: Colors.grey[200],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 USD: $dolarKur', style: TextStyle(fontSize: 16, color: Colors.black)),
            Text('1 EUR: $euroKur', style: TextStyle(fontSize: 16, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
