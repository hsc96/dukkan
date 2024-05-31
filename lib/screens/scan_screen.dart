import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'dovizservice.dart';

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

  @override
  void initState() {
    super.initState();
    fetchCustomers();
    fetchDovizKur();
  }

  void filterCustomers(String query) {
    setState(() {
      filteredCustomers = customers
          .where((customer) => customer.toLowerCase().contains(query.toLowerCase()))
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
      await fetchProductDetails(barcodeResult);
    } catch (e) {
      setState(() {
        barcodeResult = 'Hata: $e';
      });
    }
  }

  Future<void> fetchProductDetails(String barcode) async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('urunler')
        .where('Barkod', isEqualTo: barcode)
        .get();
    var docs = querySnapshot.docs;

    if (docs.isNotEmpty) {
      var data = docs.first.data() as Map<String, dynamic>;
      double fiyat = double.tryParse(data['Fiyat'].replaceAll(',', '.')) ?? 0.0;
      double kur = 1.0;

      if (data['Doviz'] == 'USD') {
        kur = double.tryParse(dolarKur.replaceAll(',', '.')) ?? 1.0;
      } else if (data['Doviz'] == 'Euro') {
        kur = double.tryParse(euroKur.replaceAll(',', '.')) ?? 1.0;
      }

      double adetFiyati = fiyat * kur;

      var product = {
        'Kodu': data['Kodu'],
        'Detay': data['Detay'],
        'Adet': 1,
        'AdetFiyati': adetFiyati,
        'ToplamFiyati': adetFiyati
      };

      setState(() {
        scannedProducts.add(product);
      });
    } else {
      setState(() {
        barcodeResult = 'Ürün bulunamadı';
      });
    }
  }

  void updateProductTotalPrice(Map<String, dynamic> product) {
    setState(() {
      product['ToplamFiyati'] = product['Adet'] * product['AdetFiyati'];
    });
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Kodu')),
                  DataColumn(label: Text('Detay')),
                  DataColumn(label: Text('Adet')),
                  DataColumn(label: Text('Adet Fiyatı')),
                  DataColumn(label: Text('Toplam Fiyatı')),
                ],
                rows: scannedProducts.map((product) {
                  return DataRow(cells: [
                    DataCell(Text(product['Kodu'])),
                    DataCell(Text(product['Detay'])),
                    DataCell(
                      TextFormField(
                        initialValue: product['Adet'].toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            product['Adet'] = int.tryParse(value) ?? 1;
                            updateProductTotalPrice(product);
                          });
                        },
                      ),
                    ),
                    DataCell(Text(product['AdetFiyati'].toStringAsFixed(2))),
                    DataCell(Text(product['ToplamFiyati'].toStringAsFixed(2))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 USD: $dolarKur', style: TextStyle(fontSize: 16, color: Colors.black)),
                Text('1 EUR: $euroKur', style: TextStyle(fontSize: 16, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
