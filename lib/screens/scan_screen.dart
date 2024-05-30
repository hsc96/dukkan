import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/cupertino.dart'; // CupertinoIcons için gerekli import
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

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

  @override
  void initState() {
    super.initState();
    fetchCustomers();
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

  Future<void> scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      setState(() {
        barcodeResult = result.rawContent;
      });
    } catch (e) {
      setState(() {
        barcodeResult = 'Hata: $e';
      });
    }
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.barcode, size: 24, color: colorTheme5),
                onPressed: scanBarcode,
              ),
              SizedBox(width: 10),
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
            child: ListView.builder(
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(filteredCustomers[index]),
                  onTap: () {
                    setState(() {
                      selectedCustomer = filteredCustomers[index];
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
