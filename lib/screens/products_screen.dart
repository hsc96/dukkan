// lib/products_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barcode_scan2/barcode_scan2.dart';

// Diğer sayfa ve widget'ları import edin
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'add_product_screen.dart';
import 'product_check_screen.dart';
import 'low_stock_products_screen.dart';
import 'purchase_history_screen.dart';
import 'blinking_circle.dart'; // BlinkingCircle widget'ını import edin

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

  // Stoktaki ürünlerin Kodu'larını tutmak için Set
  Set<String> inStockKoduSet = {};

  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    fetchInStockKodu(); // Stoktaki ürün kodlarını fetch et
    fetchProducts(); // Ürünleri fetch etmeye başla
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

  // Stoktaki ürünlerin Kodu'larını Fetch et ve Set'e ekle
  void fetchInStockKodu() {
    FirebaseFirestore.instance.collection('stoktaUrunler').snapshots().listen((snapshot) {
      Set<String> newSet = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('Kodu')) {
          newSet.add(data['Kodu']);
        }
      }
      setState(() {
        inStockKoduSet = newSet;
      });
    }, onError: (error) {
      print("StoktaKodu setini çekerken hata oluştu: $error");
    });
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

        if (uniqueProducts.length < 50) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürünler getirilirken hata oluştu: $e')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  void searchProducts(String queryText) {
    setState(() {
      searchQuery = queryText;
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
      var uniqueDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in allDocs) {
        uniqueDocs[doc['Kodu']] = doc;
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün ararken hata oluştu: $error')),
      );
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
    ) ??
        false;
  }

  Future<bool> checkIfProductIsAlreadyLowStock(String productCode) async {
    DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    Timestamp oneWeekAgoTimestamp = Timestamp.fromDate(oneWeekAgo);

    print('Checking product code: $productCode since $oneWeekAgo');

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('lowStockRequests')
        .where('Kodu', isEqualTo: productCode)
        .where('requestDate', isGreaterThanOrEqualTo: oneWeekAgoTimestamp)
        .get();

    print('Found ${snapshot.docs.length} documents');

    return snapshot.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>?> showProductSelectionDialog(List<Map<String, dynamic>> productsList) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürün Seçimi'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: productsList.length,
              itemBuilder: (context, index) {
                var product = productsList[index];
                return ListTile(
                  title: Text(product['Detay'] ?? ''),
                  subtitle: Text('Kodu: ${product['Kodu']}'),
                  onTap: () {
                    Navigator.of(context).pop(product);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> scanBarcode() async {
    try {
      // Barkod tarama işlemi gerçekleştirin
      var scanResult = await BarcodeScanner.scan();

      if (scanResult.type == ResultType.Barcode && scanResult.rawContent.isNotEmpty) {
        String barcode = scanResult.rawContent;

        var querySnapshot = await FirebaseFirestore.instance
            .collection('urunler')
            .where('Barkod', isEqualTo: barcode)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Mükerrer kontrolü için Map kullanıyoruz
          Map<String, Map<String, dynamic>> uniqueProductsMap = {};

          for (var doc in querySnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;
            // 'Kodu' alanını benzersiz anahtar olarak kullanıyoruz
            uniqueProductsMap[data['Kodu']] = data;
          }

          List<Map<String, dynamic>> productsList = uniqueProductsMap.values.toList();

          Map<String, dynamic>? selectedProduct;

          if (productsList.length == 1) {
            selectedProduct = productsList.first;
          } else {
            // Birden fazla ürün varsa, kullanıcıya seçim yapması için dialog göster
            selectedProduct = await showProductSelectionDialog(productsList);
            if (selectedProduct == null) {
              // Kullanıcı seçim yapmadıysa veya dialog'u kapattıysa işlemi iptal et
              return;
            }
          }

          var productId = selectedProduct['Kodu'] as String;
          var productDetail = selectedProduct['Detay'] as String;

          // Ürün stoğa ekli mi kontrol et
          bool isInStock = inStockKoduSet.contains(productId);

          // Dialog ekranını açıyoruz
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Ürün Detayı'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detay: $productDetail'),
                    SizedBox(height: 10),
                    isInStock
                        ? Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Stokta mevcut',
                          style: TextStyle(fontSize: 16, color: Colors.green),
                        ),
                        SizedBox(width: 10),
                        BlinkingCircle(),
                      ],
                    )
                        : ElevatedButton.icon(
                      onPressed: () async {
                        // Stoğa ekleme işlemi
                        await addToStock(selectedProduct!); // Non-nullable olarak geçildi
                      },
                      icon: Icon(Icons.add),
                      label: Text('Stoğa Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, // 'primary' yerine 'backgroundColor' kullanıldı
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('İptal'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Dialog'u kapat
                    },
                  ),
                  if (isInStock)
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
      } else {
        // Tarama başarısız oldu veya iptal edildi
        print('Barkod tarama iptal edildi veya başarısız oldu.');
      }
    } catch (e) {
      // Hata yönetimi
      print('Barkod tarama hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod tarama hatası: $e')),
      );
    }
  }

  Future<void> addToStock(Map<String, dynamic> productData) async {
    TextEditingController quantityController = TextEditingController(text: '1');
    bool isLowStock = false;
    TextEditingController orderQuantityController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Stoğa Ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Adet girişi
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Adet',
                    ),
                  ),
                  SizedBox(height: 10),
                  // Stok durumu düşük checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: isLowStock,
                        onChanged: (value) {
                          setState(() {
                            isLowStock = value ?? false;
                          });
                        },
                      ),
                      Text('Stok Durumu Düşük'),
                    ],
                  ),
                  if (isLowStock) ...[
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
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('İptal'),
                onPressed: () {
                  Navigator.of(context).pop(); // Dialog'u kapat
                },
              ),
              TextButton(
                child: Text('Kaydet'),
                onPressed: () async {
                  int? quantity = int.tryParse(quantityController.text);
                  if (quantity == null || quantity <= 0) {
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
                  try {
                    await FirebaseFirestore.instance.collection('stoktaUrunler').doc(productData['Kodu']).set({
                      'Kodu': productData['Kodu'],
                      'Detay': productData['Detay'] ?? '',
                      'Doviz': productData['Doviz'] ?? '',
                      'Fiyat': productData['Fiyat'] ?? '',
                      'Marka': productData['Marka'] ?? '',
                      'Barkod': productData['Barkod'] ?? '',
                      'Adet': quantity,
                      'createdAt': FieldValue.serverTimestamp(),
                      'requestedBy': currentUserFullName ?? 'Unknown User',
                      if (isLowStock) ...{
                        'isLowStock': true,
                        'orderQuantity': int.tryParse(orderQuantityController.text) ?? 0,
                        'description': descriptionController.text,
                      },
                    });

                    Navigator.of(context).pop(); // Dialog'u kapat

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ürün stoğa eklendi.')),
                    );
                  } catch (e) {
                    print("Stoğa ekleme hatası: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stoğa ekleme başarısız oldu: $e')),
                    );
                  }
                },
              ),
            ],
          );
        });
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
          DataColumn(label: Text('Stok Durumu')),
        ],
        rows: products.map((product) {
          bool isInStock = inStockKoduSet.contains(product['Kodu']);
          return DataRow(cells: [
            DataCell(Text(product['Ana Birim'])),
            DataCell(Text(product['Barkod'])),
            DataCell(Text(product['Detay'])),
            DataCell(Text(product['Doviz'])),
            DataCell(Text(product['Fiyat'].toString())),
            DataCell(Text(product['Kodu'])),
            DataCell(Text(product['Marka'])),
            DataCell(
              isInStock
                  ? Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  SizedBox(width: 5),
                  BlinkingCircle(),
                ],
              )
                  : ElevatedButton(
                onPressed: () async {
                  // Stoğa ekleme işlemi
                  await addToStock(product);
                },
                child: Text('Stoğa Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  void showAddProductOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürün Ekle'),
          content: Text('Lütfen bir seçenek seçiniz:'),
          actions: [
            TextButton(
              child: Text('Barkod ile Ürün Ekle'),
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                // 'AddProductScreen' sayfasına yönlendiriyoruz
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddProductScreen(addByBarcode: true),
                  ),
                );
              },
            ),
            TextButton(
              child: Text('Yakın Ürün Seçerek Ekle'),
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                // 'AddProductScreen' sayfasına yönlendiriyoruz
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddProductScreen(addByBarcode: false),
                  ),
                );
              },
            ),
          ],
        );
      },
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
            // Arama ve Filtreleme Alanı
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
                SizedBox(width: 10),
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
            // Ürün Ekleme ve Kontrol Butonları - Yatay Kaydırılabilir
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // 'Ürün Ekle' seçeneklerini gösteren fonksiyonu çağırıyoruz
                      showAddProductOptions();
                    },
                    child: Text('Ürün Ekle'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      // 'Ürün Kontrol' sayfasına yönlendiriyoruz
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProductCheckScreen()),
                      );
                    },
                    child: Text('Ürün Kontrol'),
                  ),
                  SizedBox(width: 10),
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
                  // Ek butonlar eklemek isterseniz buraya ekleyebilirsiniz
                ],
              ),
            ),
            SizedBox(height: 20),
            // Ürünler Tablosu
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

  FilterChipWidget({
    required this.filterList,
    required this.filterType,
    required this.onSelectionChanged,
  });

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
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String value = data[widget.filterType] ?? '';
          if (value.isNotEmpty && !filters.contains(value)) {
            filters.add(value);
          }
        }

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
                    selectedFilters.remove(filter);
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
