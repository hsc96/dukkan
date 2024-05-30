import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'firestore_service.dart'; // FirestoreService sınıfını içe aktar

class ScanScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();
  TextEditingController searchController = TextEditingController();
  List<DocumentSnapshot> _customers = [];
  List<String> filteredCustomers = [];
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  String? selectedCustomer;
  String barcodeResult = "";

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _fetchMoreData();
      }
    });
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    _firestoreService.fetchCustomers().listen((data) {
      setState(() {
        _customers = data;
        filteredCustomers = _customers.map((doc) => doc['Açıklama'] as String).toList();
        if (_customers.isNotEmpty) {
          _lastDocument = _customers.last;
        }
        _isLoading = false;
      });
    });
  }

  Future<void> _fetchMoreData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _firestoreService.fetchCustomers(startAfter: _lastDocument).listen((data) {
      setState(() {
        _customers.addAll(data);
        filteredCustomers = _customers.map((doc) => doc['Açıklama'] as String).toList();
        if (_customers.isNotEmpty) {
          _lastDocument = _customers.last;
        }
        _isLoading = false;
      });
    });
  }

  void filterCustomers(String query) {
    setState(() {
      filteredCustomers = _customers
          .map((doc) => doc['Açıklama'] as String)
          .where((customer) => customer.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (!filteredCustomers.contains(selectedCustomer)) {
        selectedCustomer = null;
      }
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
              controller: _scrollController,
              itemCount: filteredCustomers.length + 1,
              itemBuilder: (context, index) {
                if (index == filteredCustomers.length) {
                  return _isLoading ? Center(child: CircularProgressIndicator()) : Container();
                }
                return ListTile(
                  title: Text(filteredCustomers[index]),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
