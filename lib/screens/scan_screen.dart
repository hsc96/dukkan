import 'dart:convert';
import 'dart:io'; // Dosya işlemleri için
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
import 'package:intl/intl.dart'; // Tarih formatı için eklenmiştir.
import 'package:path_provider/path_provider.dart'; // Dosya yolları için
import 'package:pdf/widgets.dart' as pw; // PDF işlemleri için
import 'package:open_file/open_file.dart'; // Dosya açma işlemleri için
import 'pdf_sales_template.dart'; // PDF şablonu için
import 'customer_details_screen.dart'; // Müşteri detayları ekranını import et
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui; // Use ui for TextDirection
import 'customer_selection_service.dart';
import 'custom_header_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'blinking_circle.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'excel_export_util.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onCustomerProcessed;
  final String? documentId; // Make it nullable



  ScanScreen({
    required this.onCustomerProcessed,
    this.documentId, // documentId is now optional
  });

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
  double subtotal = 0.0;
  double vat = 0.0;
  bool _isConnected = true; // İnternet bağlantısı durumu


  bool isProcessing = false;
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();

  double grandTotal = 0.0;
  String currentUserName = ''; // Mevcut kullanıcının ismi burada tutulacak
  String currentDate = DateFormat('d MMMM y', 'tr_TR').format(
      DateTime.now()); // Tarih formatı ayarlandı.
  final CustomerSelectionService _customerSelectionService = CustomerSelectionService();
  ScrollController _scrollController = ScrollController();

  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? currentUser;
  List<Map<String, dynamic>> scannedProducts = [];
  List<Map<String, dynamic>> originalProducts = [
  ]; // Orijinal ürün verileri listesi


  final FirestoreService firestoreService = FirestoreService();

  double toplamTutar = 0.0;
  double kdv = 0.0;
  double genelToplam = 0.0;
  bool isEditing = false;
  int editingIndex = -1;
  Map<String, dynamic>? originalProductData;
  TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getCurrentUserName();

    _scrollController = ScrollController();
    fetchCustomers(); // Mevcut müşterileri çek
    initializeDovizKur(); // Döviz kurlarını başlat
    fetchCurrentUser(); // Mevcut kullanıcıyı çek

    // Mevcut internet bağlantısı durumunu kontrol edin
    _checkInitialConnectivity();

    // İnternet bağlantısı değişikliklerini dinleyin
    connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
          setState(() {
            _isConnected = result != ConnectivityResult.none;
          });

          print('Connectivity Changed: $_isConnected'); // Debug için

          // Eğer internet bağlantısı yoksa, updateProductsForCustomer() fonksiyonunu çağır
          if (!_isConnected) {
            updateProductsForCustomer();
          }
        });

    FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc(widget.documentId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null && mounted) {
          setState(() {
            selectedCustomer =
            data['customerName']; // Seçili müşteri bilgilerini güncelle
            scannedProducts = List<Map<String, dynamic>>.from(
                data['products'] ?? []); // Ürünleri güncelle
            updateTotalAndVat(); // Toplam ve KDV hesaplamalarını güncelle
          });
        }
      }
    });
  }


  @override
  void dispose() {
    connectivitySubscription.cancel();
    _scrollController.dispose();
    searchController.dispose(); // Eğer kullanıyorsanız
    super.dispose();
  }


  Future<void> _loadInitialData() async {
    // Seçili müşteri ve ürünleri yükle
    selectedCustomer = await _customerSelectionService.getSelectedCustomer();
    scannedProducts = await _customerSelectionService.getProductList();
    updateTotalAndVat();
    setState(() {});
  }

  Future<void> fetchCurrentUser() async {
    currentUser = _auth.currentUser;
  }


  Future<void> getCurrentUserName() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          currentUserName = userDoc.data()?['fullName'] ?? 'Unknown User';
        });
      }
    }
  }


  Future<void> initializeDovizKur() async {
    DovizService dovizService = DovizService();
    dovizService.scheduleDailyUpdate();
    var kurlar = await dovizService.getDovizKur();
    setState(() {
      dolarKur = kurlar['dolar']!;
      euroKur = kurlar['euro']!;
    });
  }

  void filterCustomers(String query) {
    setState(() {
      filteredCustomers = customers.where((customer) =>
          customer.toLowerCase().contains(query.toLowerCase())).toList();
      if (!filteredCustomers.contains(selectedCustomer)) {
        selectedCustomer = null;
      }
    });
  }

  double hesaplaToplamTutar() {
    double toplamTutar = 0.0;

    for (var product in scannedProducts) {
      double fiyat = double.tryParse(
          product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      toplamTutar += fiyat;
    }

    return toplamTutar;
  }

  void onCustomerSelected(String customerName) async {
    // Önce veritabanı işlemlerini yapıyoruz
    await _selectCustomer(
        customerName); // Müşteriyi seç ve ilgili bilgileri yükle
    await updateDiscountAndBrandForCustomer(); // İskonto ve marka bilgilerini güncelle

    // Daha sonra toplam tutarı hesaplıyoruz
    double amount = hesaplaToplamTutar(); // Toplam tutarı hesapla

    // Firestore'a müşteri ve toplam tutar bilgisini kaydediyoruz
    await FirebaseFirestore.instance.collection('customerSelections').add({
      'customerName': customerName,
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Tüm işlemler tamamlandıktan sonra UI'ı güncelliyoruz
    if (mounted) {
      setState(() {
        selectedCustomer = customerName;
        // Diğer UI güncellemeleri burada yapılabilir
      });
    }

    // Firestore'a kaydedildikten sonra CustomHeaderScreen'e geri dön
    Navigator.pop(context);
  }

  Future<void> fetchCustomers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection(
        'veritabanideneme').get();
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


  Future<bool> isConnected() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> processSale() async {
    // İnternet bağlantısını kontrol edelim
    bool connected = await isConnected();
    if (!connected) {
      // Eğer internet yoksa işlemi durdur ve kullanıcıya uyarı ver
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Bağlantı Sorunu'),
            content: Text(
                'İnternet bağlantısı yok, işlem gerçekleştirilemiyor.'),
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
      return; // İşlem iptal
    }

    if (selectedCustomer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lütfen bir müşteri seçin')),
          );
        }
      });
      return;
    }

    User? currentUser = FirebaseAuth.instance.currentUser;
    String? fullName;

    if (currentUser != null) {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        fullName = userDoc.data()?['fullName'];
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kullanıcı bilgisi alınamadı')),
            );
          }
        });
        return;
      }
    }

    // temporarySelections belgesinden verileri çekelim
    DocumentSnapshot<Map<String, dynamic>> tempSelectionSnapshot =
    await FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc(widget.documentId)
        .get();

    if (!tempSelectionSnapshot.exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Geçici seçimler bulunamadı')),
          );
        }
      });
      return;
    }

    Map<String, dynamic>? data = tempSelectionSnapshot.data();
    List<dynamic> products = data?['products'] ?? [];

    // Toplam satırlarını filtreleyelim
    List<Map<String, dynamic>> actualProducts = products.where((product) {
      return product['Kodu'] != null && product['Kodu']
          .toString()
          .isNotEmpty;
    }).cast<Map<String, dynamic>>().toList();

    // Satışa katkıda bulunan satış elemanlarını toplayalım
    Set<String> salespersons = actualProducts.map<String>((product) {
      return product['addedBy'] ?? 'Unknown Salesperson';
    }).toSet();

    // processedProducts listesini oluşturalım
    var processedProducts = actualProducts.map((product) {
      double unitPrice =
          double.tryParse(product['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      int quantity = int.tryParse(product['Adet']?.toString() ?? '1') ?? 1;
      double totalPrice = unitPrice * quantity;

      return {
        'Kodu': product['Kodu'],
        'Detay': product['Detay'],
        'Adet': quantity.toString(),
        'Adet Fiyatı': unitPrice.toStringAsFixed(2),
        'Toplam Fiyat': totalPrice.toStringAsFixed(2),
        'İskonto': product['İskonto'],
        'addedBy': product['addedBy'] ?? 'Unknown User',
        'whoTook': 'Müşteri',
        'recipient': 'Teslim Alan',
        'contactPerson': 'İlgili Kişi',
        'orderMethod': 'Telefon',
        'siparisTarihi': DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(
            DateTime.now()),
        'islemeAlan': fullName ?? 'Unknown',
      };
    }).toList();

    // Toplam tutarı hesaplayalım
    double toplamTutar = processedProducts.fold(0.0, (sum, product) {
      return sum + (double.tryParse(product['Toplam Fiyat'] ?? '0') ?? 0.0);
    });

    try {
      var customerCollection =
      FirebaseFirestore.instance.collection('customerDetails');
      var querySnapshot = await customerCollection
          .where('customerName', isEqualTo: selectedCustomer)
          .get();

      int saleNumber = 1; // Varsayılan olarak 1

      if (querySnapshot.docs.isNotEmpty) {
        var docRef = querySnapshot.docs.first.reference;
        var customerData = querySnapshot.docs.first.data();
        var existingProducts =
        List<Map<String, dynamic>>.from(customerData['products'] ?? []);

        // Mevcut saleCount değerini al ve artır
        saleNumber = (customerData['saleCount'] ?? 0) + 1;

        // processedProducts içindeki her ürüne saleNumber ekleyelim
        processedProducts = processedProducts.map((product) {
          return {
            ...product,
            'saleNumber': saleNumber,
          };
        }).toList();

        existingProducts.addAll(processedProducts);

        await docRef.update({
          'products': existingProducts,
          'saleCount': saleNumber, // saleCount değerini güncelle
        });
      } else {
        // İlk kez satış yapılıyorsa
        // processedProducts içindeki her ürüne saleNumber ekleyelim
        processedProducts = processedProducts.map((product) {
          return {
            ...product,
            'saleNumber': saleNumber,
          };
        }).toList();

        await customerCollection.add({
          'customerName': selectedCustomer,
          'products': processedProducts,
          'saleCount': saleNumber,
        });
      }

      // Satış verisini kaydedelim
      await FirebaseFirestore.instance.collection('sales').add({
        'salespersons': salespersons.toList(),
        'date': DateFormat('dd.MM.yyyy').format(DateTime.now()),
        'customerName': selectedCustomer,
        'amount': toplamTutar,
        'products': processedProducts,
        'saleNumber': saleNumber, // Satış numarasını ekleyelim
      });

      // İşlem başarılı olduğunda temporarySelections belgesini silelim
      await FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc(widget.documentId)
          .delete();

      // UI'ı sıfırlayalım
      if (mounted) {
        setState(() {
          selectedCustomer = null;
          scannedProducts.clear();
          // Diğer gerekli sıfırlamaları yapın
        });

        // Önce bir uyarı mesajı gösterelim
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('İşlem Tamamlandı'),
              content: Text('Anasayfaya yönlendiriliyorsunuz.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dialog'u kapat
                    // Ardından kullanıcıyı CustomHeaderScreen'e yönlendirelim
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CustomHeaderScreen()),
                    );
                  },
                  child: Text('Tamam'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Hata oluştu: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('İşlem tamamlanamadı: $e')),
            );
          }
        });
      }

      if (widget.documentId != null) {
        await FirebaseFirestore.instance
            .collection('temporarySelections')
            .doc(widget.documentId)
            .delete();
        print('temporarySelections belge (${widget
            .documentId}) processSale içinde başarıyla silindi.');
      }
      // Hata durumunda temporarySelections belgesini SİLMİYORUZ
      // Veriler korunuyor, kullanıcı tekrar deneyebilir
    }
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

  Future<void> addProductToCurrentCustomer(Map<String, dynamic> productData,
      String? currentUserFullName) async {
    try {
      if (widget.documentId != null) {
        DocumentReference<
            Map<String, dynamic>> currentDocRef = FirebaseFirestore.instance
            .collection('temporarySelections')
            .doc(widget.documentId);

        DocumentSnapshot<Map<String, dynamic>> snapshot = await currentDocRef
            .get();

        if (snapshot.exists) {
          List<dynamic> existingProducts = snapshot.data()?['products'] ?? [];

          // Ürün fiyatını ve stok bilgisini 'urunler' koleksiyonundan çek
          Map<String, dynamic> productDetails = await firestoreService
              .fetchProductDetails(productData['Kodu']);
          double price = double.tryParse(
              productDetails['Fiyat']?.toString() ?? '') ?? 0.0;

          // Eğer fiyat 0.0 ise uyarı ver ve işleme almayı durdur
          if (price == 0.0) {
            print(
                "Warning: Price is 0.0 for product code ${productData['Kodu']}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(
                  'Ürün fiyatı eksik veya hatalı! Ürün kodu: ${productData['Kodu']}')),
            );
            return; // Fiyat 0.0 ise işleme devam etmiyoruz
          }

          // Döviz çevirisini yap
          double priceInTl = price;
          String currency = productDetails['Doviz']?.toString() ?? '';

          if (currency == 'Euro') {
            priceInTl =
                price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
          } else if (currency == 'Dolar') {
            priceInTl =
                price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
          } else {
            priceInTl =
                price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
          }

          // İskonto uygulanması
          double discountedPrice = priceInTl;
          double discountRate = 0.0;

          if (selectedCustomer != null) {
            var customerDiscount = await firestoreService.getCustomerDiscount(
                selectedCustomer!);

            // İskonto seviyesi alma
            String discountLevel = customerDiscount['iskonto'] ?? '';
            print("İskonto seviyesi: $discountLevel");

            if (discountLevel.isNotEmpty) {
              // İlgili marka için iskonto oranını al
              var discountData = await firestoreService.getDiscountRates(
                  discountLevel, productDetails['Marka']?.toString() ?? '');
              discountRate =
                  double.tryParse(discountData['rate']?.toString() ?? '0.0') ??
                      0.0;
              discountedPrice = priceInTl * (1 - (discountRate / 100));
            }
          }

          // **Adet bilgisi girmek için dialog aç**
          Map<String, dynamic>? dialogResult = await showQuantityInputDialog(
              productDetails['Kodu']);

          if (dialogResult == null) {
            // Kullanıcı dialog'u iptal ettiyse işlem yapma
            return;
          }

          int quantity = dialogResult['quantity'] ?? 1;
          bool isLowStock = dialogResult['isLowStock'] ?? false;
          int? orderQuantity = dialogResult['orderQuantity'];
          String? description = dialogResult['description'];

          // Ürün bilgilerini oluştur
          Map<String, dynamic> productInfo = {
            'Kodu': productDetails['Kodu'],
            'Detay': productDetails['Detay'],
            'Adet': quantity.toString(),
            'Adet Fiyatı': discountedPrice.toStringAsFixed(2),
            // İskonto uygulanmış fiyat
            'Toplam Fiyat': (discountedPrice * quantity).toStringAsFixed(2),
            'İskonto': discountRate > 0 ? '%$discountRate' : '0%',
            // İskonto bilgisi
            'addedBy': currentUserFullName ?? 'Unknown User',
            // Ekleyen kullanıcı bilgisi
          };

          existingProducts.add(productInfo);

          await currentDocRef.update({'products': existingProducts});

          // Eğer stok durumu düşük olarak işaretlendiyse, lowStockRequests koleksiyonuna ekle
          if (isLowStock) {
            await addProductToLowStockRequests(
              productDetails,
              currentUserFullName,
              orderQuantity,
              description,
            );
          }
        } else {
          print('Snapshot exists hatası: snapshot bulunamadı.');
        }
      } else {
        print('Document ID hatası: widget.documentId null.');
      }
    } catch (e) {
      print('Hata oluştu: $e'); // Hatayı yakalayıp terminale yazdırıyoruz
    }
  }

  Future<void> addProductToLowStockRequests(Map<String, dynamic> productDetails,
      String? currentUserFullName,
      int? orderQuantity,
      String? description,) async {
    try {
      await FirebaseFirestore.instance.collection('lowStockRequests').add({
        'Kodu': productDetails['Kodu'],
        'Detay': productDetails['Detay'],
        'Adet': '1',
        'orderQuantity': orderQuantity,
        'description': description,
        'requestedBy': currentUserFullName ?? 'Unknown User',
        'requestDate': DateTime.now(),
      });
      print('Product added to lowStockRequests from scan_screen');
    } catch (e) {
      print('Error adding product to lowStockRequests: $e');
    }
  }

  Future<Map<String, dynamic>?> showQuantityInputDialog(
      String productCode) async {
    TextEditingController quantityController = TextEditingController(text: '1');
    TextEditingController orderQuantityController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    bool isLowStock = false;
    bool isInStock = false; // Stok durumu
    bool showAddToStockButton = false; // "Ürünü stoğa ekle" butonunu göstermek için

    // Ürünün stok durumunu kontrol et
    try {
      DocumentSnapshot<
          Map<String, dynamic>> productSnapshot = await FirebaseFirestore
          .instance
          .collection('stoktaUrunler')
          .doc(productCode)
          .get();

      if (productSnapshot.exists) {
        var productData = productSnapshot.data();
        if (productData != null) {
          isInStock =
          true; // Ürün stokta, çünkü stoktaUrunler koleksiyonunda mevcut
        }
      } else {
        // Ürün stokta değil, stoğa ekle butonunu göster
        showAddToStockButton = true;
      }
    } catch (e) {
      print("Stok durumu kontrol edilirken hata oluştu: $e");
      // Hata durumunda stoğa ekle butonunu göster
      showAddToStockButton = true;
    }

    // Dialog ekranı açılıyor
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Adet Giriniz'),
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
                    SizedBox(height: 20),
                    // Stok durumu bilgisi veya stoğa ekle butonu
                    if (isInStock)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Bu ürün stokta var',
                            style: TextStyle(fontSize: 16, color: Colors.green),
                          ),
                          SizedBox(width: 10),
                          // Yanıp sönen yeşil yuvarlak kutucuk
                          BlinkingCircle(),
                        ],
                      )
                    else
                      if (showAddToStockButton)
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Stoğa ekleme işlemi
                            bool confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Ürünü Stoğa Ekle'),
                                  content: Text(
                                      'Bu ürünü stoğa eklemek istediğinizden emin misiniz?'),
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
                                // Stoğa ekle (stoktaUrunler koleksiyonuna ekle)
                                await FirebaseFirestore.instance
                                    .collection('stoktaUrunler')
                                    .doc(productCode)
                                    .set({
                                  'Kodu': productCode,
                                  // Diğer ürün bilgilerini buraya ekleyebilirsiniz
                                  'Detay': 'Detay bilgisi',
                                  // Örnek veri, gerçek veriyi eklemelisiniz
                                  'Doviz': 'USD',
                                  'Fiyat': 100.0,
                                  'Marka': 'Marka A',
                                  'Barkod': '1234567890123',
                                }, SetOptions(merge: true));

                                // UI'ı güncelle
                                setState(() {
                                  isInStock = true;
                                  showAddToStockButton = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Ürün stoğa eklendi.')),
                                );
                              } catch (e) {
                                print("Stoğa ekleme hatası: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(
                                      'Stoğa ekleme başarısız oldu.')),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.add),
                          label: Text('Ürünü Stoğa Ekle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors
                                .orange, // 'primary' yerine 'backgroundColor' kullanıldı
                          ),
                        ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('İptal'),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Dialog'u kapatır ve null döndürür
                  },
                ),
                TextButton(
                  child: Text('Tamam'),
                  onPressed: () {
                    int quantity = int.tryParse(quantityController.text) ?? 1;
                    int? orderQuantity;
                    if (isLowStock) {
                      orderQuantity =
                          int.tryParse(orderQuantityController.text) ?? 0;
                    }
                    Navigator.of(context).pop({
                      'quantity': quantity,
                      'isLowStock': isLowStock,
                      'orderQuantity': orderQuantity,
                      'description': descriptionController.text,
                    }); // Girilen değerleri döndürür
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


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


  Future<void> updateProductPricesForCustomer() async {
    if (selectedCustomer == null) return;

    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = scannedProducts[i];

      // Ürünün fiyatını ve diğer bilgileri "urunler" koleksiyonundan çek
      var productDetails = await firestoreService.fetchProductDetails(
          productData['Kodu']);
      double price = double.tryParse(
          productDetails['Fiyat']?.toString() ?? '0') ??
          0.0; // Fiyatı buradan alıyoruz

      if (price == 0.0) {
        print("Warning: Price is 0.0 for product code ${productData['Kodu']}");
        continue; // Eğer fiyat 0.0 ise işleme devam etmiyoruz
      }

      // İskonto oranını ve fiyatı güncelle
      await applyDiscountToProduct(productData); // Bu doğru

      double adet = double.tryParse(productData['Adet']?.toString() ?? '1') ??
          1;

      setState(() {
        scannedProducts[i]['Adet Fiyatı'] = productData['Adet Fiyatı'];
        scannedProducts[i]['Toplam Fiyat'] =
            (adet * (double.tryParse(productData['Adet Fiyatı'] ?? '0') ?? 0))
                .toStringAsFixed(2);
        scannedProducts[i]['İskonto'] = productData['İskonto'];
      });
    }

    // Güncellenmiş ürünleri Firestore'da güncelleyin
    await FirebaseFirestore.instance.collection('temporarySelections').doc(
        widget.documentId).update({
      'products': scannedProducts,
    });

    updateTotalAndVat(); // Toplam ve KDV güncellemesi
  }


  void printProductPrices() {
    if (scannedProducts.isNotEmpty) {
      print("Müşteri değiştirildi, mevcut ürünlerin fiyatları:");
      for (var product in scannedProducts) {
        print(
            "Ürün Kodu: ${product['Kodu']}, Adet Fiyatı: ${product['Adet Fiyatı']}, Toplam Fiyat: ${product['Toplam Fiyat']}");
      }
    } else {
      print("Tabloda ürün bulunmuyor.");
    }
  }


  Future<void> updateDiscountAndBrandForCustomer() async {
    if (selectedCustomer == null) return;

    // Müşterinin iskonto bilgilerini al
    var customerDiscount = await firestoreService.getCustomerDiscount(
        selectedCustomer!);
    String discountLevel = customerDiscount['iskonto'] ?? '';

    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = scannedProducts[i];

      // Her ürün için fiyatı urunler koleksiyonundan tekrar çek
      var productDetails = await firestoreService.fetchProductDetails(
          productData['Kodu']);
      String brand = productDetails['Marka'] ?? '';
      double price = double.tryParse(
          productDetails['Fiyat']?.toString() ?? '0.0') ?? 0.0;
      double discountRate = 0.0;

      // Döviz dönüşümünü uygula
      String currency = productDetails['Doviz']?.toString() ?? '';
      double priceInTl = price;

      if (currency == 'Euro') {
        priceInTl =
            price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
      } else if (currency == 'Dolar') {
        priceInTl =
            price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
      } else {
        priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
      }

      if (discountLevel.isNotEmpty) {
        var discountData = await firestoreService.getDiscountRates(
            discountLevel, brand);
        discountRate =
            double.tryParse(discountData['rate']?.toString() ?? '0.0') ?? 0.0;
      }

      // Hesaplamalar
      double discountedPrice = priceInTl * (1 - (discountRate / 100));
      double adet = double.tryParse(productData['Adet']?.toString() ?? '1') ??
          1;

      // Diğer alanları güncellerken mevcut veriyi koruyun
      scannedProducts[i] = {
        ...scannedProducts[i], // Mevcut veriyi korur
        'Marka': brand,
        'İskonto': '%${discountRate.toStringAsFixed(2)}',
        'Adet Fiyatı': discountedPrice.toStringAsFixed(2),
        'Toplam Fiyat': (adet * discountedPrice).toStringAsFixed(2),
      };
    }

    // Güncellenmiş ürünleri Firestore'daki temporarySelections koleksiyonunda güncelle
    await FirebaseFirestore.instance.collection('temporarySelections').doc(
        widget.documentId).update({
      'products': scannedProducts,
    });
  }


  Future<void> fetchProductDetails(String barcode) async {
    print("Barkod tarandı: $barcode");

    var products = await firestoreService.fetchProductsByBarcode(barcode);
    if (products.isNotEmpty) {
      print("Ürünler bulundu: ${products.length} adet");

      var uniqueProducts = <Map<String, dynamic>>[];
      for (var product in products) {
        if (!uniqueProducts.any((p) => p['Kodu'] == product['Kodu'])) {
          uniqueProducts.add(product);
        }
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

      if (uniqueProducts.length > 1) {
        showProductSelectionDialog(uniqueProducts);
      } else {
        await addProductToCurrentCustomer(uniqueProducts.first,
            currentUserFullName); // 2 argüman gönderiliyor
      }
    } else {
      print("Hata: Ürün verisi bulunamadı.");
    }
  }

  Future<void> applyDiscountToProduct(Map<String, dynamic> productData) async {
    double basePrice = double.tryParse(
        productData['Fiyat']?.toString() ?? '0') ?? 0.0;
    String currency = productData['Doviz']?.toString() ?? '';

    // Döviz Kuru Alma
    double exchangeRate = 1.0;
    if (currency == 'Euro') {
      exchangeRate = double.tryParse(euroKur.replaceAll(',', '.')) ?? 1.0;
    } else if (currency == 'Dolar') {
      exchangeRate = double.tryParse(dolarKur.replaceAll(',', '.')) ?? 1.0;
    }

    // Fiyatı TL'ye Çevirme
    double priceInTl = basePrice * exchangeRate;

    print("Orijinal Fiyat: $basePrice $currency, TL Fiyatı: $priceInTl");

    // İskonto Uygulama
    double discountRate = await getDiscountRateForCustomer(
        productData['Marka']);
    double discountedPrice = priceInTl * (1 - (discountRate / 100));

    print(
        "İskonto Oranı: $discountRate%, İskonto Uygulanmış Fiyat: $discountedPrice TL");

    // Adet ve Toplam Fiyat Hesaplama
    double quantity = double.tryParse(productData['Adet']?.toString() ?? '1') ??
        1.0;
    double totalPrice = discountedPrice * quantity;

    // Ürün Verilerini Güncelleme
    productData['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
    productData['Toplam Fiyat'] = totalPrice.toStringAsFixed(2);
    productData['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
    productData['Fiyat TL'] =
        priceInTl.toStringAsFixed(2); // Gerekirse ileride kullanmak için
  }


  Future<double> getDiscountRateForCustomer(String brand) async {
    if (selectedCustomer == null) return 0.0;

    var customerDiscount = await firestoreService.getCustomerDiscount(
        selectedCustomer!);
    String discountLevel = customerDiscount['iskonto'] ?? '';

    if (discountLevel.isEmpty) return 0.0;

    var discountData = await firestoreService.getDiscountRates(
        discountLevel, brand);
    return double.tryParse(discountData['rate']?.toString() ?? '0') ?? 0.0;
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
                  onTap: () async {
                    // Kullanıcı adını al
                    User? currentUser = FirebaseAuth.instance.currentUser;
                    String? currentUserFullName;

                    if (currentUser != null) {
                      var userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .get();
                      currentUserFullName =
                          userDoc.data()?['fullName'] ?? 'Unknown User';
                    }

                    print(
                        "Seçilen Ürün: ${products[index]['Kodu']} Kullanıcı: $currentUserFullName"); // Hata ayıklama için çıktı al

                    // Ürünü tabloya ekle ve kullanıcı bilgisini ekle
                    await addProductToCurrentCustomer(
                        products[index], currentUserFullName);
                    Navigator.of(context).pop(); // Diyalog ekranını kapat
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }


  Future<void> addProductToTable(Map<String, dynamic> productData) async {
    // Ürün detaylarını "urunler" koleksiyonundan çek
    var productDetails = await firestoreService.fetchProductDetails(
        productData['Kodu']);

    double priceInTl = 0.0;
    double price = double.tryParse(
        productDetails['Fiyat']?.toString() ?? '0') ?? 0.0;
    String currency = productDetails['Doviz']?.toString() ?? '';

    // Döviz kuruna göre fiyatı TL'ye çevir
    if (currency == 'Euro') {
      priceInTl =
          price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      priceInTl =
          price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
    } else {
      priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
    }

    productData['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);

    // Müşteri seçilmişse iskonto uygula
    if (selectedCustomer != null) {
      await applyDiscountToProduct(productData); // Bu doğru
    } else {
      productData['Toplam Fiyat'] = (priceInTl * 1).toStringAsFixed(2);
    }

    // Ürünü tabloya ve veritabanına ekle
    setState(() {
      scannedProducts.add({
        'Kodu': productData['Kodu']?.toString() ?? '',
        'Detay': productData['Detay']?.toString() ?? '',
        'Adet': '1',
        'Adet Fiyatı': productData['Adet Fiyatı']?.toString(),
        'Toplam Fiyat': productData['Toplam Fiyat']?.toString(),
        'İskonto': productData['İskonto']?.toString() ?? ''
      });

      FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc(widget.documentId)
          .update({'products': scannedProducts});

      originalProducts.add({
        ...productData,
        'Original Fiyat': productDetails['Fiyat']?.toString() ?? '0',
      });

      updateTotalAndVat();

      // Yeni ürün eklendikten sonra sayfayı aşağı kaydır
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }


  Future<void> updateProductsForCustomer() async {
    if (selectedCustomer == null) return;

    for (var product in scannedProducts) {
      if (product['Kodu']
          ?.toString()
          ?.isEmpty ?? true) continue;

      // Veritabanından ürün detaylarını çek
      var productDetails = await firestoreService.fetchProductDetails(
          product['Kodu']);
      if (productDetails == null) continue;

      // Ürün verilerini güncelle
      product['Fiyat'] = productDetails['Fiyat'];
      product['Doviz'] = productDetails['Doviz'];
      product['Marka'] = productDetails['Marka'];

      // Fiyat hesaplamasını yap
      await applyDiscountToProduct(product);
    }

    // Firestore'da güncelle
    await FirebaseFirestore.instance.collection('temporarySelections').doc(
        widget.documentId).update({
      'products': scannedProducts,
    });

    // Toplamları güncelle
    updateTotalAndVat();
  }


  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(
          scannedProducts[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      scannedProducts[index]['Adet'] = quantity;
      scannedProducts[index]['Toplam Fiyat'] =
          (adet * price).toStringAsFixed(2);
    });

    // Sadece değişen ürünü Firestore'da güncelle
    FirebaseFirestore.instance.collection('temporarySelections').doc(
        widget.documentId).update({
      'products': scannedProducts,
    });

    // Toplam ve KDV'yi güncelle
    updateTotalAndVat();
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
                Navigator.of(context).pop(); // Dialog ekranını kapatır
              },
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () async {
                if (index >= 0 && index < scannedProducts.length) {
                  // Ürünü listeden kaldır
                  Map<String, dynamic> removedProduct = scannedProducts[index];
                  setState(() {
                    scannedProducts.removeAt(index);
                  });

                  // Firestore'dan ürünü kaldır
                  await FirebaseFirestore.instance
                      .collection('temporarySelections')
                      .doc(widget.documentId)
                      .update({
                    'products': FieldValue.arrayRemove([removedProduct]),
                  });

                  // Dialog ekranını kapat
                  Navigator.of(context).pop();

                  // Kaldırma işlemi başarılı olduktan sonra kullanıcıya bildirim gösterin
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ürün başarıyla kaldırıldı.')),
                  );
                } else {
                  // Hata durumunda kullanıcıya bildirim gösterin
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ürün kaldırılamadı.')),
                  );
                }
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }


  void updateTotalAndVat() {
    subtotal = 0.0;

    for (var product in scannedProducts) {
      if (product['Kodu']
          ?.toString()
          ?.isEmpty ?? true) continue;

      double productTotal = double.tryParse(
          product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      subtotal += productTotal;

      print(
          "Ürün Kodu: ${product['Kodu']}, Ürün Toplam Fiyatı: $productTotal TL");
    }

    vat = subtotal * 0.20;
    grandTotal = subtotal + vat;

    print(
        "Ara Toplam: $subtotal TL, KDV: $vat TL, Genel Toplam: $grandTotal TL");

    setState(() {
      // scannedProducts listesine dokunmayın
    });

    // Firestore güncellemesi
    updateTotalInFirestore(subtotal, vat, grandTotal);
  }


  void updateTotalInFirestore(double subtotal, double vat,
      double grandTotal) async {
    await FirebaseFirestore.instance.collection('temporarySelections').doc(
        widget.documentId).update({
      'subtotal': subtotal,
      'vat': vat,
      'grandTotal': grandTotal,
    });
  }


  Future<void> saveToCustomerDetails(
      String whoTook, String? recipient, String? contactPerson, String orderMethod) async {
    if (selectedCustomer == null) return;

    User? currentUser = FirebaseAuth.instance.currentUser;
    String? fullName;
    if (currentUser != null) {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        fullName = userDoc.data()?['fullName'];
      }
    }

    var customerCollection = FirebaseFirestore.instance.collection('customerDetails');
    var querySnapshot = await customerCollection.where('customerName', isEqualTo: selectedCustomer).get();

    var processedProducts = scannedProducts
        .where((product) => product['Kodu'] != null && product['Kodu'].toString().isNotEmpty)
        .map((product) {
      double unitPrice = double.tryParse(product['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      int quantity = int.tryParse(product['Adet']?.toString() ?? '1') ?? 1;
      double totalPrice = unitPrice * quantity;

      return {
        'Kodu': product['Kodu'],
        'Detay': product['Detay'],
        'Adet': quantity.toString(),
        'Adet Fiyatı': unitPrice.toStringAsFixed(2),
        'Toplam Fiyat': totalPrice.toStringAsFixed(2),
        'İskonto': product['İskonto'],
        'addedBy': product['addedBy'] ?? 'Unknown User',
        'whoTook': whoTook,
        'recipient': recipient,
        'contactPerson': contactPerson,
        'orderMethod': orderMethod,
        'siparisTarihi': DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now()),
        'islemeAlan': fullName ?? 'Unknown',
      };
    }).toList();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      var existingProducts = List<Map<String, dynamic>>.from(querySnapshot.docs.first['products'] ?? []);
      for (var product in processedProducts) {
        existingProducts.add(product);
      }
      await docRef.update({'products': existingProducts});
    } else {
      await customerCollection.add({
        'customerName': selectedCustomer,
        'products': processedProducts,
      });
    }

    // Artık burada: setState, Navigator, ScaffoldMessenger, showDialog **YOK**
  }

  // _ScanScreenState sınıfının içine bu fonksiyonu ekleyin veya güncelleyin:

  // _ScanScreenState sınıfının içine bu fonksiyonu ekleyin veya güncelleyin:

  Future<bool> showProcessingDialog() async {
    final _formKeyDialog = GlobalKey<FormState>();
    String? whoTookValue;
    final recipientController = TextEditingController();
    final contactPersonController = TextEditingController();
    String? orderMethodValue;
    final otherMethodController = TextEditingController();

    // Müşteri seçili değilse uyarı verip çık
    if (selectedCustomer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen bir müşteri seçin.')),
        );
      }
      return false;
    }

    // Geçerli ürün yoksa uyarı verip çık
    final validProducts = scannedProducts
        .where((p) => p['Kodu'] != null && p['Kodu'].toString().isNotEmpty)
        .toList();
    if (validProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listede geçerli ürün bulunmuyor.')),
        );
      }
      return false;
    }

    // Dialog göster
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Sipariş Bilgileri ve Onay'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.95,
                  ),
                  child: Form(
                    key: _formKeyDialog,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Müşteri: $selectedCustomer',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text('Ürünler:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 10,
                            columns: [
                              DataColumn(label: Text('Kodu', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Detay', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Adet', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Birim F.', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('İsk.', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Toplam F.', style: TextStyle(fontSize: 12))),
                            ],
                            rows: [
                              ...validProducts.map((product) {
                                return DataRow(cells: [
                                  DataCell(Text(product['Kodu']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                                  DataCell(Text(product['Detay']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                                  DataCell(Text(product['Adet']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                                  DataCell(Text(product['Adet Fiyatı']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                                  DataCell(Text(product['İskonto']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                                  DataCell(Text(product['Toplam Fiyat']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                                ]);
                              }).toList(),
                              DataRow(cells: [
                                DataCell(Text('')), DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                                DataCell(Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                DataCell(Text(subtotal.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ]),
                              DataRow(cells: [
                                DataCell(Text('')), DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                                DataCell(Text('KDV %20', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                DataCell(Text(vat.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ]),
                              DataRow(cells: [
                                DataCell(Text('')), DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                                DataCell(Text('Genel Top.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 11))),
                                DataCell(Text(grandTotal.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 11))),
                              ]),
                            ],
                          ),
                        ),
                        SizedBox(height: 15),
                        Text('Ek Sipariş Bilgileri:', style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Ürünü Kim Aldı?'),
                          value: whoTookValue,
                          items: ['Müşterisi', 'Kendi Firması']
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => setStateDialog(() => whoTookValue = v),
                          validator: (v) => v == null ? 'Bu alan zorunludur' : null,
                        ),
                        TextFormField(
                          controller: recipientController,
                          decoration: InputDecoration(labelText: 'Teslim Alan Kişi/Firma Adı'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Bu alan zorunludur' : null,
                        ),
                        if (whoTookValue == 'Müşterisi')
                          TextFormField(
                            controller: contactPersonController,
                            decoration: InputDecoration(labelText: 'İlgili Kişi İsmi'),
                            validator: (v) => (v == null || v.isEmpty) ? 'Bu alan zorunludur' : null,
                          ),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Sipariş Şekli'),
                          value: orderMethodValue,
                          items: ['Telefon', 'Mail', 'Yerinde', 'Diğer']
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => setStateDialog(() => orderMethodValue = v),
                          validator: (v) => v == null ? 'Bu alan zorunludur' : null,
                        ),
                        if (orderMethodValue == 'Diğer')
                          TextFormField(
                            controller: otherMethodController,
                            decoration: InputDecoration(labelText: 'Diğer Açıklama'),
                            validator: (v) => (v == null || v.isEmpty) ? 'Bu alan zorunludur' : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(false),
                  child: Text('İptal'),
                ),
                TextButton(
                  child: isSubmitting
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Kaydet'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (!_formKeyDialog.currentState!.validate()) return;
                    setStateDialog(() => isSubmitting = true);
                    try {
                      // 1) Veritabanına kayıt
                      await saveToCustomerDetails(
                        whoTookValue!,
                        recipientController.text,
                        whoTookValue == 'Müşterisi'
                            ? contactPersonController.text
                            : null,
                        orderMethodValue == 'Diğer'
                            ? otherMethodController.text
                            : orderMethodValue!,
                      );
                      // 2) sales koleksiyonuna ekle
                      await FirebaseFirestore.instance.collection('sales').add({
                        'customerName': selectedCustomer,
                        'products': List<Map<String, dynamic>>.from(scannedProducts),
                        'amount': grandTotal,
                        'date': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        'salespersons': [currentUserName],
                        'type': 'Hesaba İşle',
                      });
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Kaydetme hatası: $e')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }







  Future<void> saveAsPDF() async {
    await PDFSalesTemplate.generateSalesPDF(
      scannedProducts,
      selectedCustomer!,
      false,
    );
  }

  Future<String> _selectDate(BuildContext context) async {
    DateTime selectedDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      int businessDays = _calculateBusinessDays(selectedDate, picked);
      return '$businessDays iş günü';
    }
    return '0 iş günü';
  }

  Future<String> _selectOfferDuration(BuildContext context) async {
    String offerDuration = '';
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Teklif Süresi (gün)'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              offerDuration = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
    return offerDuration;
  }

  int _calculateBusinessDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = start;
    while (current.isBefore(end)) {
      current = current.add(Duration(days: 1));
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        count++;
      }
    }
    return count;
  }

  Future<DocumentReference> generateQuote() async {
    if (selectedCustomer == null) return Future.error('Müşteri seçilmedi');

    // Teklif numarasını oluştur
    String currentYear = DateFormat('yyyy').format(DateTime.now());
    String prefix = 'CSK$currentYear';
    var querySnapshot = await FirebaseFirestore.instance
        .collection('quotes')
        .where('quoteNumber', isGreaterThanOrEqualTo: prefix)
        .where('quoteNumber', isLessThan: prefix + 'Z')
        .orderBy('quoteNumber', descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (querySnapshot.docs.isNotEmpty) {
      String lastQuoteNumber = querySnapshot.docs.first['quoteNumber'];
      String lastNumberStr = lastQuoteNumber.substring(prefix.length);
      int lastNumber = int.tryParse(lastNumberStr) ?? 0;
      nextNumber = lastNumber + 1;
    }

    String quoteNumber = '$prefix${nextNumber.toString().padLeft(4, '0')}';

    // Teklifi Firestore'a kaydet
    DocumentReference docRef = await FirebaseFirestore.instance.collection(
        'quotes').add({
      'customerName': selectedCustomer,
      'quoteNumber': quoteNumber,
      'products': scannedProducts,
      'date': DateTime.now(),
      'salesperson': currentUserName,        // tek string
      'type': 'Teklif',
    });
    Navigator.of(context).pop();
    return docRef; // Teklif kaydedilen DocumentReference'ı döndür
  }


  void handleEditSubmit(int index) {
    setState(() {
      isEditing = false;
      editingIndex = -1;

      // Güncellenen ürün bilgisini Firestore'a kaydet
      FirebaseFirestore.instance.collection('temporarySelections').doc(
          widget.documentId).update({
        'products': scannedProducts,
      });
    });

    updateTotalAndVat(); // Toplam ve KDV'yi güncelle
  }


  void handleEditCancel(int index) {
    setState(() {
      scannedProducts[index] = originalProductData!;
      originalProductData = null;
      isEditing = false;
      editingIndex = -1;
    });
  }


  Future<void> _selectCustomer(String customerName) async {
    if (widget.documentId != null) {
      // Veritabanideneme koleksiyonundan müşteri bilgilerini çek
      var customerDoc = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('Açıklama', isEqualTo: customerName)
          .get();

      if (customerDoc.docs.isNotEmpty) {
        var customerData = customerDoc.docs.first.data();
        String iskontoLevel = customerData['iskonto'] ?? '';

        // Seçilen müşterinin iskonto bilgilerini temporarySelections koleksiyonuna kaydet
        await FirebaseFirestore.instance
            .collection('temporarySelections')
            .doc(widget.documentId)
            .update({
          'customerName': customerName,
          'iskonto': iskontoLevel, // İskonto seviyesini kaydet
          'products': scannedProducts, // Ürünleri de ekleyin
        });

        print(
            "Seçilen müşteri: $customerName, İskonto seviyesi: $iskontoLevel");
      } else {
        print("Müşteri bulunamadı.");
      }
    } else {
      print("Hata: Mevcut bir documentId yok.");
    }
  }


  void _processCustomer(String customerName, double amount) {
    widget.onCustomerProcessed({
      'customerName': customerName,
      'amount': amount,
    });
  }

  void _handleCustomerSelection(String customerName) {
    setState(() {
      selectedCustomer = customerName;
      // Seçilen müşteri bilgisini Firebase'e kaydet
      FirebaseFirestore.instance
          .collection('selectedCustomer')
          .doc('current')
          .set({'customerName': customerName});
    });
  }

  // void _clearScreen() {
//   setState(() {
//     scannedProducts.clear();
//     selectedCustomer = null;
//     _customerSelectionService.clearTemporaryData();
//   });
// }


  // void handleProcessCompletion() async {
//   if (selectedCustomer != null) {
//     await FirebaseFirestore.instance
//         .collection('temporarySelections')
//         .doc('current')
//         .set({
//       'products': [],
//     }, SetOptions(merge: true));

  Future<void> processCashPayment() async {
    if (selectedCustomer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lütfen bir müşteri seçin')),
          );
        }
      });
      return;
    }

    // Nakit tahsilat işlemini gerçekleştirin
    try {
      await FirebaseFirestore.instance.collection('cashPayments').add({
        'customerName': selectedCustomer,
        'amount': toplamTutar,
        'date': DateTime.now(),
        'products': scannedProducts,
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Nakit tahsilat başarıyla gerçekleştirildi')),
          );
        }
      });

      // TemporarySelections içindeki verileri temizle
      await _customerSelectionService.clearTemporaryData();

      // Verileri temizle
      clearScreen(); // Verileri kaydettikten sonra ekranı temizle
    } catch (e) {
      print('Nakit tahsilat hatası: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Nakit tahsilat işlemi sırasında hata oluştu')),
          );
        }
      });
    }
  }


  Future<void> clearSelections(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc(docId)
          .delete();
      // Ayrıca UI'ı da temizle (gerekirse)
      if (mounted) {
        setState(() {
          selectedCustomer = null;
          scannedProducts.clear();
          // ... diğer temizlikler
        });
      }
    } catch (e) {
      print('Temizlik hatası: $e');
    }
  }




  void clearScreen() {
    if (widget.documentId != null) {
      FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc(widget.documentId)
          .delete()
          .then((_) async {
        print("Firestore '${widget.documentId}' verisi başarıyla silindi");

        // UI'ı temizle
        if (mounted) {
          setState(() {
            selectedCustomer = null;
            scannedProducts.clear();
            originalProducts.clear();
            toplamTutar = 0.0;
            kdv = 0.0;
            genelToplam = 0.0;
          });
        }

        // Kullanıcıya bilgi mesajı göster ve yönlendir
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('İşlem Tamamlandı'),
              content: Text('Veriler başarıyla temizlendi.'),
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

        // İsteğe bağlı olarak kullanıcıyı yönlendirin
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CustomHeaderScreen()),
        );
      }).catchError((error) {
        print('Belge silinirken hata oluştu: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veri temizlenirken hata oluştu: $error')),
        );
      });
    } else {
      print("Hata: documentId null");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Belge silinirken hata oluştu: Document ID bulunamadı.')),
      );
    }
  }


  Future<void> updateDiscountsForAllProducts() async {
    if (selectedCustomer == null) return;

    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = scannedProducts[i];

      // Ürünün fiyatını ve diğer bilgileri "urunler" koleksiyonundan çek
      var productDetails = await firestoreService.fetchProductDetails(
          productData['Kodu']);

      if (productDetails == null || productDetails.isEmpty) {
        print("Product details not found for code: ${productData['Kodu']}");
        continue;
      }

      double price = double.tryParse(
          productDetails['Fiyat']?.toString() ?? '0') ??
          0.0; // Fiyatı buradan alıyoruz

      if (price == 0.0) {
        print("Warning: Price is 0.0 for product code ${productData['Kodu']}");
        continue; // Eğer fiyat 0.0 ise işleme devam etmiyoruz
      }

      // İskonto oranını ve fiyatı güncelle
      await applyDiscountToProduct(productData); // Bu doğru

      double adet = double.tryParse(productData['Adet']?.toString() ?? '1') ??
          1;

      setState(() {
        scannedProducts[i]['Adet Fiyatı'] = productData['Adet Fiyatı'];
        scannedProducts[i]['Toplam Fiyat'] =
            (adet * (double.tryParse(productData['Adet Fiyatı'] ?? '0') ?? 0))
                .toStringAsFixed(2);
        scannedProducts[i]['İskonto'] = productData['İskonto'];
      });
    }

    // Güncellenmiş ürünleri Firestore'da güncelleyin
    await FirebaseFirestore.instance.collection('temporarySelections').doc(
        widget.documentId).update({
      'products': scannedProducts,
    });

    updateTotalAndVat(); // Toplam ve KDV güncellemesi
  }


  Future<bool> checkInternetConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      // Eğer mobil veri veya Wi-Fi bağlıysa internet var
      return true;
    } else {
      // Bağlantı yok
      return false;
    }
  }


  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Ürün Tara'),
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          // Üstteki satır
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                    CupertinoIcons.barcode, size: 24, color: colorTheme5),
                onPressed: () {
                  if (_isConnected) {
                    scanBarcode();
                  } else {
                    _showNoConnectionDialog('Bağlantı Sorunu',
                        'İnternet bağlantısı yok, barkod taraması yapılamıyor.');
                  }
                },
              ),


              Row(
                children: [
                  DropdownButton<String>(
                    hint: Text('MÜŞTERİ SEÇ'),
                    value: selectedCustomer,
                    // Seçili müşteri
                    icon: Icon(Icons.arrow_downward),
                    iconSize: 24,
                    elevation: 16,
                    style: TextStyle(color: Colors.black),
                    underline: Container(
                      height: 2,
                      color: Colors.grey,
                    ),
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        if (_isConnected) {
                          // İnternet varsa işlemi gerçekleştirin
                          await _selectCustomer(newValue);
                          await updateDiscountAndBrandForCustomer();
                          setState(() {
                            selectedCustomer =
                                newValue; // Seçilen müşteri kaydediliyor
                          });
                        } else {
                          // İnternet yoksa, dialog göster
                          _showNoConnectionDialog('Bağlantı Sorunu',
                              'İnternet bağlantısı yok, müşteri seçimi yapılamıyor.');
                        }
                      }
                    },
                    items: filteredCustomers.map<DropdownMenuItem<String>>((
                        String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),

                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          // Müşteri arama alanı ve yenile butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) => filterCustomers(query),
                    decoration: InputDecoration(
                      hintText: 'Müşteri ara...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: colorTheme5),
                  onPressed: () {
                    updateProductsForCustomer();
                    updateTotalAndVat();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection(
                  'temporarySelections').doc(widget.documentId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text('No data found.'));
                }

                var customerData = snapshot.data!.data() as Map<String,
                    dynamic>?;
                if (customerData != null) {
                  selectedCustomer = customerData['customerName'];
                  scannedProducts = List<Map<String, dynamic>>.from(
                      customerData['products'] ?? []);
                } else {
                  return Center(child: Text('No customer data found.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      SingleChildScrollView(
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
                          rows: [
                            // Ürün satırları
                            ...scannedProducts.map((product) {
                              int index = scannedProducts.indexOf(product);
                              return DataRow(cells: [
                                DataCell(
                                    Text(product['Kodu']?.toString() ?? '')),
                                DataCell(
                                    Text(product['Detay']?.toString() ?? '')),
                                DataCell(
                                  _isConnected
                                      ? TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      // Ürün miktarını güncelle
                                      scannedProducts[index]['Adet'] = value;
                                    },
                                    onSubmitted: (value) {
                                      // Güncellemeyi yap
                                      updateQuantity(index, value);
                                    },
                                    controller: TextEditingController(
                                      text: scannedProducts[index]['Adet']
                                          ?.toString() ?? '',
                                    ),
                                  )
                                      : GestureDetector(
                                    onTap: () {
                                      // İnternet yoksa, uyarı göster
                                      _showNoConnectionDialog('Bağlantı Sorunu',
                                          'İnternet bağlantısı yok, miktar güncellenemiyor.');
                                    },
                                    child: Text(
                                      scannedProducts[index]['Adet']
                                          ?.toString() ?? '0',
                                      style: TextStyle(
                                          fontSize: 16.0, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                DataCell(Text(
                                    product['Adet Fiyatı']?.toString() ?? '')),
                                DataCell(
                                    Text(product['İskonto']?.toString() ?? '')),
                                DataCell(Text(
                                    product['Toplam Fiyat']?.toString() ?? '')),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                            Icons.edit, color: Colors.grey),
                                        onPressed: () {
                                          if (_isConnected) {
                                            setState(() {
                                              isEditing = true;
                                              editingIndex = index;
                                              originalProductData =
                                              Map<String, dynamic>.from(
                                                  product);
                                              quantityController.text =
                                                  product['Adet']?.toString() ??
                                                      '';
                                            });
                                          } else {
                                            // İnternet yoksa uyarı göster
                                            _showNoConnectionDialog(
                                                'Bağlantı Sorunu',
                                                'İnternet bağlantısı yok, düzenleme yapılamıyor.');
                                          }
                                        },
                                      ),
                                      if (isEditing && editingIndex == index)
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.check,
                                                  color: Colors.green),
                                              onPressed: () {
                                                if (_isConnected) {
                                                  handleEditSubmit(index);
                                                } else {
                                                  // İnternet yoksa uyarı göster
                                                  _showNoConnectionDialog(
                                                      'Bağlantı Sorunu',
                                                      'İnternet bağlantısı yok, işlem gerçekleştirilemiyor.');
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () {
                                                if (_isConnected) {
                                                  removeProduct(index);
                                                } else {
                                                  // İnternet yoksa uyarı göster
                                                  _showNoConnectionDialog(
                                                      'Bağlantı Sorunu',
                                                      'İnternet bağlantısı yok, işlem gerçekleştirilemiyor.');
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close,
                                                  color: Colors.red),
                                              onPressed: () {
                                                handleEditCancel(index);
                                              },
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                            // Toplam satırları
                            // Toplam Tutar Satırı
                            DataRow(cells: [
                              DataCell(Text('')),
                              // Kodu için boş hücre
                              DataCell(Text('')),
                              // Detay için boş hücre
                              DataCell(Text('')),
                              // Adet için boş hücre
                              DataCell(Text('')),
                              // Adet Fiyatı için boş hücre
                              DataCell(Text('Toplam Tutar', style: TextStyle(
                                  fontWeight: FontWeight.bold))),
                              // İskonto altına Toplam Tutar
                              DataCell(Text(subtotal.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                              // Toplam Fiyat altına Toplam Tutar değeri
                              DataCell(Text('')),
                              // Düzenle için boş hücre
                            ]),
// KDV Satırı
                            DataRow(cells: [
                              DataCell(Text('')),
                              // Kodu için boş hücre
                              DataCell(Text('')),
                              // Detay için boş hücre
                              DataCell(Text('')),
                              // Adet için boş hücre
                              DataCell(Text('')),
                              // Adet Fiyatı için boş hücre
                              DataCell(Text('KDV %20', style: TextStyle(
                                  fontWeight: FontWeight.bold))),
                              // İskonto altına KDV
                              DataCell(Text(vat.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                              // Toplam Fiyat altına KDV değeri
                              DataCell(Text('')),
                              // Düzenle için boş hücre
                            ]),
// Genel Toplam Satırı
                            DataRow(cells: [
                              DataCell(Text('')),
                              // Kodu için boş hücre
                              DataCell(Text('')),
                              // Detay için boş hücre
                              DataCell(Text('')),
                              // Adet için boş hücre
                              DataCell(Text('')),
                              // Adet Fiyatı için boş hücre
                              DataCell(Text('Genel Toplam', style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red))),
                              // İskonto altına Genel Toplam
                              DataCell(Text(grandTotal.toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      color: Colors.red))),
                              // Toplam Fiyat altına Genel Toplam değeri
                              DataCell(Text('')),
                              // Düzenle için boş hücre
                            ]),
                          ],
                        ),
                      ),
                      // ... Diğer kodlar ...
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(

                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                            onPressed: () async {
                      // Liste boş mu kontrolü
                      final validProducts = scannedProducts
                          .where((p) => p['Kodu'] != null && p['Kodu'].toString().isNotEmpty)
                          .toList();
                      if (validProducts.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Listede geçerli ürün bulunmuyor.')),
                      );
                      return;
                      }

                      // Mevcut "Teklif Oluştur" onayı
                      bool shouldProceed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                      return AlertDialog(
                      title: Text('Teklif Oluştur'),
                      content: Text('Teklif oluşturmak istediğinizden emin misiniz?'),
                      actions: [
                      TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Hayır'),
                      ),
                      TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Evet'),
                      ),
                      ],
                      );
                      },
                      ) ?? false;

                      if (shouldProceed && mounted) {
                      try {
                      // Teklif oluşturma işlemi
                      DocumentReference quoteRef = await generateQuote();

                      // Sayfa verilerini temizle
                      clearScreen();

                      // Sayfa yenilenmeden önce biraz bekleyin (örneğin 1 saniye)
                      await Future.delayed(Duration(seconds: 1));

                      if (mounted) {
                      // Teklif numarasını ve müşteri adını almak için veritabanını kontrol et
                      DocumentSnapshot quoteSnapshot = await quoteRef.get();
                      String quoteNumber = quoteSnapshot['quoteNumber'];
                      String customerName = quoteSnapshot['customerName'];

                      // Bilgi mesajını göster
                      await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                      return AlertDialog(
                      title: Text('Teklif Oluşturuldu'),
                      content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Text('Teklif No: $quoteNumber'),
                      Text('Müşteri: $customerName'),
                      SizedBox(height: 8),
                      Text('Teklifi müşteri detayları veya teklifler sayfasından ulaşabilirsiniz.'),
                      ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // 1) Dialog'u kapat
                            Navigator.of(context).pop(); // 2) ScanScreen'i kapat → header güncellenecek
                          },
                          child: Text('Tamam'),
                      ),
                      ],
                      );
                      },
                      );
                      }
                      } catch (e) {
                      if (mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                      content: Text('Teklif oluşturulurken bir hata oluştu: $e'),
                      duration: Duration(seconds: 5),
                      ),
                      );
                      });
                      }
                      }
                      }
                      },
                        child: Text('Teklif Ver'),
                      ),



                                                SizedBox(height: 100),
                            // _ScanScreenState sınıfındaki build metodunun içindeki butonlar bölümünde:

                            // _ScanScreenState sınıfındaki build metodunun içindeki "Hesaba İşle" butonu:

                            // _ScanScreenState sınıfındaki build metodunun içindeki butonlar bölümü:

                            // _ScanScreenState sınıfındaki build metodunun içindeki "Hesaba İşle" ElevatedButton:

                            // _ScanScreenState sınıfındaki build metodunun içindeki "Hesaba İşle" ElevatedButton:

                            // _ScanScreenState sınıfındaki build metodunun içindeki "Hesaba İşle" ElevatedButton:

                            // _ScanScreenState sınıfındaki build metodunun içindeki "Hesaba İşle" ElevatedButton:
                            ElevatedButton.icon(
                              icon: Icon(Icons.point_of_sale_outlined),
                              label: Text('Hesaba İşle'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                textStyle: TextStyle(fontSize: 13),
                              ),
                              onPressed: () async {
                                if (!_isConnected) {
                                  _showNoConnectionDialog(
                                    'Bağlantı Sorunu',
                                    'İnternet bağlantısı yok, işlem gerçekleştirilemiyor.',
                                  );
                                  return;
                                }

                                if (selectedCustomer == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lütfen bir müşteri seçin.')),
                                  );
                                  return;
                                }

                                // 1) Dialog ile verileri kaydettir
                                bool detailsSaved = await showProcessingDialog();

                                // 2) Kayıt başarılıysa (true dönüyorsa) sadece burada temizlik ve yönlendirme!
                                if (detailsSaved == true) {
                                  // temporarySelections'ı sil
                                  await clearSelections(widget.documentId!);

                                  // UI'ı sıfırla
                                  setState(() {
                                    selectedCustomer = null;
                                    scannedProducts.clear();
                                    originalProducts.clear();
                                    toplamTutar = 0.0;
                                    kdv = 0.0;
                                    genelToplam = 0.0;
                                  });

                                  // Ana ekrana (CustomHeaderScreen) yönlendir
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (context) => CustomHeaderScreen()),
                                  );
                                }
                              },
                            ),













                            ElevatedButton(
                              onPressed: () async {
                                // 1) Ensure you have a selected customer
                                if (selectedCustomer == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lütfen bir müşteri seçin')),
                                  );
                                  return;
                                }

                                // 2) Perform your existing cash‐payment logic
                                await processCashPayment();

                                // 3) Record a new “sales” document for today
                                //    so that CustomHeaderScreen will pick it up
                                final user = FirebaseAuth.instance.currentUser;
                                String userName = 'Unknown';
                                if (user != null) {
                                  final uDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get();
                                  userName = uDoc.data()?['fullName'] ?? userName;
                                }
                                await FirebaseFirestore.instance.collection('sales').add({
                                  'salespersons': [userName],
                                  'date': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                  'customerName': selectedCustomer,
                                  'amount': toplamTutar,
                                  'products': scannedProducts,
                                  'salespersons': [currentUserName],
                                  'type': 'N.Tahsilat',
                                });

                                // 4) Clear out your temp data & navigate home (as you already do)
                                await clearSelections(widget.documentId!);
                                clearScreen();
                              },
                              child: Text('Nakit Tahsilat'),
                            ),

                            ElevatedButton(
                              onPressed: saveAsPDF,
                              child: Text('PDF\'e Dönüştür'),
                            ),
                            // ... diğer butonlarınızın bulunduğu Row içinde, PDF butonunun yanına:
                            ElevatedButton(
                              onPressed: () {
                                final validProducts = scannedProducts
                                    .where((p) => p['Kodu'] != null && p['Kodu'].toString().isNotEmpty)
                                    .toList();
                                if (validProducts.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Listede geçerli ürün bulunmuyor.')),
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExcelExportScreen(
                                      products: validProducts,
                                      customerName: selectedCustomer!,  // Bu “Açıklama” alanı
                                    ),
                                  ),
                                );
                              },
                              child: Text('Excel\'e Dönüştür'),
                            ),




                          ],
                        ),
                      ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
      bottomSheet: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double fontSize = 16.0;
          double screenWidth = constraints.maxWidth;
          double minWidth = screenWidth / 3;

          double calculateTotalTextWidth(double fontSize) {
            return (TextPainter(
                text: TextSpan(text: '1 USD: $dolarKur',
                    style: TextStyle(fontSize: fontSize)),
                maxLines: 1,
                textDirection: ui.TextDirection.ltr)
              ..layout())
                .size
                .width +
                (TextPainter(
                    text: TextSpan(text: currentDate,
                        style: TextStyle(fontSize: fontSize)),
                    maxLines: 1,
                    textDirection: ui.TextDirection.ltr)
                  ..layout())
                    .size
                    .width +
                (TextPainter(
                    text: TextSpan(text: '1 EUR: $euroKur',
                        style: TextStyle(fontSize: fontSize)),
                    maxLines: 1,
                    textDirection: ui.TextDirection.ltr)
                  ..layout())
                    .size
                    .width +
                32.0;
          }

          while (calculateTotalTextWidth(fontSize) > screenWidth &&
              fontSize > 10) {
            fontSize -= 1;
          }

          return Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 USD: $dolarKur',
                    style: TextStyle(fontSize: fontSize, color: Colors.black)),
                Text(currentDate,
                    style: TextStyle(fontSize: fontSize, color: Colors.black)),
                Text('1 EUR: $euroKur',
                    style: TextStyle(fontSize: fontSize, color: Colors.black)),
              ],
            ),
          );
        },
      ),
    );
  }
}