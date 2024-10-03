// lib/stock_products_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'blinking_circle.dart'; // BlinkingCircle widget'ını import edin

class StockProductsScreen extends StatefulWidget {
  @override
  _StockProductsScreenState createState() => _StockProductsScreenState();
}

class _StockProductsScreenState extends State<StockProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> stockProducts = [];
  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  bool hasMore = true;
  bool _isConnected = true;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    fetchStockProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        fetchStockProducts();
      }
    });
    _checkInitialConnectivity();

    // İnternet bağlantısı değişikliklerini dinleyin
    connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      print('Connectivity Changed: $_isConnected'); // Debug için
    });
  }

  // Mevcut internet bağlantısını kontrol eden fonksiyon
  void _checkInitialConnectivity() async {
    try {
      ConnectivityResult result = await _connectivity.checkConnectivity();
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      print('Initial Connectivity Status: $_isConnected'); // Debug için
    } catch (e) {
      print("Bağlantı durumu kontrol edilirken hata oluştu: $e");
      setState(() {
        _isConnected = false;
      });
    }
  }

  // Yardımcı fonksiyon: İnternet yoksa uyarı dialog'u gösterir
  void _showNoConnectionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    connectivitySubscription.cancel(); // Aboneliği iptal et
    super.dispose();
  }

  Future<void> fetchStockProducts() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('stoktaUrunler') // Yeni koleksiyon adını kullanın
        .orderBy('createdAt', descending: true) // Eklenme tarihine göre sırala
        .limit(50);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }

    try {
      var querySnapshot = await query.get();
      print('Fetched ${querySnapshot.docs.length} stock products');

      if (querySnapshot.docs.isNotEmpty) {
        lastDocument = querySnapshot.docs.last;

        var newStockProducts = querySnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'Ana Birim': data['Ana Birim'] ?? '',
            'Barkod': data['Barkod'] ?? '',
            'Detay': data['Detay'] ?? '',
            'Doviz': data['Doviz'] ?? '',
            'Fiyat': data['Fiyat'] ?? '',
            'Kodu': data['Kodu'] ?? '',
            'Marka': data['Marka'] ?? '',
            'Adet': data['Adet'] ?? 0,
            'createdAt': data['createdAt'] ?? Timestamp.now(),
          };
        }).toList();

        setState(() {
          stockProducts.addAll(newStockProducts);
        });

        if (newStockProducts.length < 50) {
          setState(() {
            hasMore = false;
          });
        }
      } else {
        setState(() {
          hasMore = false;
        });
      }
    } catch (e) {
      print('Error fetching stock products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ürünleri getirilirken hata oluştu: $e')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  // Ürünü stoğundan kaldırma fonksiyonu
  Future<void> removeFromStock(String productCode) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Stoktan Kaldır'),
          content: Text('Bu ürünü stoğundan kaldırmak istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('stoktaUrunler').doc(productCode).delete();
        setState(() {
          stockProducts.removeWhere((product) => product['Kodu'] == productCode);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün stoğundan kaldırıldı.')),
        );
      } catch (e) {
        print("Ürünü stoğundan kaldırırken hata oluştu: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürünü stoğundan kaldırma başarısız oldu.')),
        );
      }
    }
  }

  Widget buildStockProductsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Eklenme Tarihi')),
          DataColumn(label: Text('Ana Birim')),
          DataColumn(label: Text('Kodu')),
          DataColumn(label: Text('Detay')),
          DataColumn(label: Text('Doviz')),
          DataColumn(label: Text('Fiyat')),
          DataColumn(label: Text('Barkod No')),
          DataColumn(label: Text('Adet')),
          DataColumn(label: Text('Stoktan Kaldır')),
        ],
        rows: stockProducts.map((product) {
          DateTime addedDate = product['createdAt'] is Timestamp
              ? (product['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          String formattedDate = "${addedDate.day}/${addedDate.month}/${addedDate.year} ${addedDate.hour}:${addedDate.minute}";

          return DataRow(cells: [
            DataCell(Text(formattedDate)),
            DataCell(Text(product['Ana Birim'])),
            DataCell(Text(product['Kodu'])),
            DataCell(Text(product['Detay'])),
            DataCell(Text(product['Doviz'])),
            DataCell(Text(product['Fiyat'].toString())),
            DataCell(Text(product['Barkod'])),
            DataCell(Text(product['Adet'].toString())),
            DataCell(
              IconButton(
                icon: Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  removeFromStock(product['Kodu']);
                },
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Stoktaki Ürünler'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Arama ve Filtreleme Alanı (isteğe bağlı)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Arama',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      // Arama fonksiyonunu buraya ekleyebilirsiniz
                      // Örneğin, filtreleme yapabilirsiniz
                    },
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: () {
                    // Filtreleme fonksiyonunu buraya ekleyebilirsiniz
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            // Ürünler Tablosu
            Expanded(
              child: stockProducts.isEmpty && !isLoading
                  ? Center(child: Text('Stokta ürün bulunamadı.'))
                  : SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    buildStockProductsTable(),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
