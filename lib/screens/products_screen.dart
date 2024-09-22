import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'purchase_history_screen.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'low_stock_products_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'archived_orders_screen.dart';


class ProductsScreen extends StatefulWidget {
  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> products = [];
  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  bool hasMore = true;
  String searchQuery = '';
  List<String> selectedDoviz = [];
  List<String> selectedMarka = [];

  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  bool _isLoadingButton = false; // Yükleme durumu (isteğe bağlı)

  @override
  void initState() {
    super.initState();
    fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        fetchProducts();
      }
    });
    _checkInitialConnectivity(); // Mevcut bağlantı durumunu kontrol et

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
    _searchController.dispose();
    connectivitySubscription.cancel(); // Aboneliği iptal et
    super.dispose();
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('urunler')
        .orderBy('Kodu')
        .limit(50);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }

    try {
      var querySnapshot = await query.get();
      print('Fetched ${querySnapshot.docs.length} documents');

      var filteredDocs = querySnapshot.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        bool matchesDoviz = selectedDoviz.isEmpty || selectedDoviz.contains(data['Doviz']);
        bool matchesMarka = selectedMarka.isEmpty || selectedMarka.contains(data['Marka']);
        return matchesDoviz && matchesMarka;
      }).toList();

      print('Filtered ${filteredDocs.length} documents based on selectedDoviz and selectedMarka');

      if (filteredDocs.isNotEmpty) {
        lastDocument = filteredDocs.last;

        var newProducts = filteredDocs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'Ana Birim': data['Ana Birim'] ?? '',
            'Barkod': data['Barkod'] ?? '',
            'Detay': data['Detay'] ?? '',
            'Doviz': data['Doviz'] ?? '',
            'Fiyat': data['Fiyat'] ?? '',
            'Kodu': data['Kodu'] ?? '',
            'Marka': data['Marka'] ?? '',
          };
        }).toList();

        // Mükerrer kontrolü
        var existingKoduSet = products.map((product) => product['Kodu']).toSet();

        var uniqueProducts = newProducts.where((product) => !existingKoduSet.contains(product['Kodu'])).toList();

        setState(() {
          products.addAll(uniqueProducts);
        });

        if (uniqueProducts.isEmpty) {
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
      print('Error fetching products: $e');
    }

    setState(() {
      isLoading = false;
    });
  }


  void searchProducts(String query) {
    setState(() {
      searchQuery = query;
      products.clear();
      lastDocument = null;
      hasMore = true;
    });

    // Arama işlemi
    Query koduQuery = FirebaseFirestore.instance
        .collection('urunler')
        .where('Kodu', isGreaterThanOrEqualTo: searchQuery)
        .where('Kodu', isLessThanOrEqualTo: searchQuery + '\uf8ff')
        .limit(50);

    Query detayQuery = FirebaseFirestore.instance
        .collection('urunler')
        .where('Detay', isGreaterThanOrEqualTo: searchQuery)
        .where('Detay', isLessThanOrEqualTo: searchQuery + '\uf8ff')
        .limit(50);

    Future.wait([koduQuery.get(), detayQuery.get()]).then((results) {
      var allDocs = [...results[0].docs, ...results[1].docs];
      print('Search returned ${allDocs.length} documents');

      // Mükerrer kontrolü
      var uniqueDocs = {};
      allDocs.forEach((doc) {
        uniqueDocs[doc['Kodu']] = doc;
      });

      var uniqueDocList = uniqueDocs.values.toList();

      print('Unique documents count: ${uniqueDocList.length}');

      if (uniqueDocList.isNotEmpty) {
        lastDocument = uniqueDocList.last;

        var newProducts = uniqueDocList.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'Ana Birim': data['Ana Birim'] ?? '',
            'Barkod': data['Barkod'] ?? '',
            'Detay': data['Detay'] ?? '',
            'Doviz': data['Doviz'] ?? '',
            'Fiyat': data['Fiyat'] ?? '',
            'Kodu': data['Kodu'] ?? '',
            'Marka': data['Marka'] ?? '',
          };
        }).toList();

        setState(() {
          products.addAll(newProducts);
        });

        if (newProducts.isEmpty) {
          setState(() {
            hasMore = false;
          });
        }
      } else {
        setState(() {
          hasMore = false;
        });
      }
    }).catchError((error) {
      print('Error searching products: $error');
    });
  }

  Future<bool> showAlreadyLowStockWarning() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Uyarı'),
          content: Text('Bu ürün zaten son 1 hafta içinde stok durumu düşük olarak belirtilmiş. Yine de bildirim yapmak istiyor musunuz?'),
          actions: [
            TextButton(
              child: Text('Hayır'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Evet'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> checkIfProductIsAlreadyLowStock(String productCode) async {
    DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('lowStockRequests')
        .where('Kodu', isEqualTo: productCode)
        .where('requestDate', isGreaterThanOrEqualTo: oneWeekAgo)
        .get();

    return snapshot.docs.isNotEmpty;
  }



  Future<void> scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      var barcode = result.rawContent;

      if (barcode.isNotEmpty) {
        var querySnapshot = await FirebaseFirestore.instance
            .collection('urunler')
            .where('Barkod', isEqualTo: barcode)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var product = querySnapshot.docs.first.data();
          var productId = product['Kodu'] as String;
          var productDetail = product['Detay'] as String;

          // Yeni dialog ekranını açıyoruz
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Ne yapmak istersiniz?'),
                content: Text('Lütfen bir seçenek seçiniz:'),
                actions: [
                  TextButton(
                    child: Text('Ürün Satış Geçmişini Göster'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Dialog'u kapat

                      // Ürün satış geçmişi sayfasına yönlendir
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PurchaseHistoryScreen(
                            productId: productId,
                            productDetail: productDetail,
                          ),
                        ),
                      );
                    },
                  ),
                  TextButton(
                    child: Text('Stok Durumu Düşük'),
                    onPressed: () async {
                      Navigator.of(context).pop(); // Dialog'u kapat

                      // Sipariş geçilecek adet ve açıklama soran dialog'u aç
                      await showLowStockDialog(product);
                    },
                  ),
                ],
              );
            },
          );
        } else {
          print('Ürün bulunamadı.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ürün bulunamadı.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        print('Barkod tarama hatası: $e');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod tarama hatası: $e')),
      );
    }
  }

  Future<void> showLowStockDialog(Map<String, dynamic> productData) async {
    TextEditingController orderQuantityController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    // Ürünün daha önce düşük stok olarak işaretlenip işaretlenmediğini kontrol edelim
    bool isAlreadyLowStock = await checkIfProductIsAlreadyLowStock(productData['Kodu']);

    if (isAlreadyLowStock) {
      bool proceed = await showAlreadyLowStockWarning();
      if (!proceed) {
        // Kullanıcı 'Hayır' dediyse, işlem yapmadan geri dön
        return;
      }
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Stok Durumu Düşük'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ürün Kodu: ${productData['Kodu']}'),
              Text('Detay: ${productData['Detay']}'),
              TextField(
                controller: orderQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sipariş Geçilecek Adet',
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Kaydet'),
              onPressed: () async {
                int? orderQuantity = int.tryParse(orderQuantityController.text);
                String description = descriptionController.text;

                if (orderQuantity == null || orderQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lütfen geçerli bir adet giriniz.')),
                  );
                  return;
                }

                // Kullanıcı adını al
                User? currentUser = FirebaseAuth.instance.currentUser;
                String? currentUserFullName;

                if (currentUser != null) {
                  var userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .get();
                  currentUserFullName = userDoc.data()?['fullName'] ?? 'Unknown User';
                }

                // Verileri Firestore'a kaydet
                await FirebaseFirestore.instance.collection('lowStockRequests').add({
                  'Kodu': productData['Kodu'],
                  'Detay': productData['Detay'],
                  'Adet': '1',
                  'orderQuantity': orderQuantity,
                  'description': description,
                  'requestedBy': currentUserFullName ?? 'Unknown User',
                  'requestDate': DateTime.now(),
                });

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Talebiniz kaydedildi.')),
                );
              },
            ),
          ],
        );
      },
    );
  }





  void showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filtrele'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text('Döviz:'),
                FilterChipWidget(
                  filterList: selectedDoviz,
                  filterType: 'Doviz',
                  onSelectionChanged: (selectedList) {
                    setState(() {
                      selectedDoviz = selectedList;
                    });
                  },
                ),
                SizedBox(height: 20),
                Text('Marka:'),
                FilterChipWidget(
                  filterList: selectedMarka,
                  filterType: 'Marka',
                  onSelectionChanged: (selectedList) {
                    setState(() {
                      selectedMarka = selectedList;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Filtrele'),
              onPressed: () {
                setState(() {
                  products.clear();
                  lastDocument = null;
                  hasMore = true;
                });
                fetchProducts();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildProductsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Ana Birim')),
          DataColumn(label: Text('Barkod')),
          DataColumn(label: Text('Detay')),
          DataColumn(label: Text('Doviz')),
          DataColumn(label: Text('Fiyat')),
          DataColumn(label: Text('Kodu')),
          DataColumn(label: Text('Marka')),
        ],
        rows: products.map((product) {
          return DataRow(cells: [
            DataCell(Text(product['Ana Birim'])),
            DataCell(Text(product['Barkod'])),
            DataCell(Text(product['Detay'])),
            DataCell(Text(product['Doviz'])),
            DataCell(Text(product['Fiyat'].toString())),
            DataCell(
              Text(product['Kodu']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseHistoryScreen(
                      productId: product['Kodu'],
                      productDetail: product['Detay'],
                    ),
                  ),
                );
              },
            ),
            DataCell(Text(product['Marka'])),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Ürünler'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt, color: Colors.blue),
                  onPressed: () {
                    if (_isConnected) {
                      scanBarcode();
                    } else {
                      _showNoConnectionDialog(
                        'Bağlantı Sorunu',
                        'İnternet bağlantısı yok, barkod tarama işlemi gerçekleştirilemiyor.',
                      );
                    }
                  },
                ),
                Text('Ürün Tara'),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Arama',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: searchProducts,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: () {
                    if (_isConnected) {
                      showFilterDialog();
                    } else {
                      _showNoConnectionDialog(
                        'Bağlantı Sorunu',
                        'İnternet bağlantısı yok, filtreleme işlemi gerçekleştirilemiyor.',
                      );
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            // Buraya yeni butonu ekliyoruz
            ElevatedButton(
              onPressed: () {
                // 'Stok Durumu Düşük Ürünler' sayfasına yönlendiriyoruz
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LowStockProductsScreen()),
                );
              },
              child: Text('Stok Durumu Düşük Ürünler'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: products.isEmpty && !isLoading
                  ? Center(child: Text('Veri bulunamadı'))
                  : SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    buildProductsTable(),
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

class FilterChipWidget extends StatefulWidget {
  final List<String> filterList;
  final String filterType;
  final ValueChanged<List<String>> onSelectionChanged;

  FilterChipWidget({required this.filterList, required this.filterType, required this.onSelectionChanged});

  @override
  _FilterChipWidgetState createState() => _FilterChipWidgetState();
}

class _FilterChipWidgetState extends State<FilterChipWidget> {
  List<String> selectedFilters = [];

  @override
  void initState() {
    super.initState();
    selectedFilters = widget.filterList;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('urunler').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        List<String> filters = [];
        snapshot.data!.docs.forEach((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String value = data[widget.filterType] ?? '';
          if (!filters.contains(value)) {
            filters.add(value);
          }
        });

        return Wrap(
          spacing: 8.0,
          children: filters.map((filter) {
            return FilterChip(
              label: Text(filter),
              selected: selectedFilters.contains(filter),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedFilters.add(filter);
                  } else {
                    selectedFilters.removeWhere((String name) {
                      return name == filter;
                    });
                  }
                });
                widget.onSelectionChanged(selectedFilters);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
