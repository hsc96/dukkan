import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Dosya işlemleri için
import 'dart:ui' as ui; // Use ui for TextDirection

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatı için eklenmiştir.
import 'package:open_file/open_file.dart'; // Dosya açma işlemleri için
import 'package:path_provider/path_provider.dart'; // Dosya yolları için
import 'package:pdf/widgets.dart' as pw; // PDF işlemleri için

// Yerel Proje Dosyaları (Yolların doğru olduğundan emin olun)
import '../utils/colors.dart'; // Renk paleti
import 'account_tracking_screen.dart';
import 'blinking_circle.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'custom_header_screen.dart';
import 'customer_details_screen.dart';
import 'customer_selection_service.dart';
import 'dovizservice.dart'; // Döviz kurları servisi
import 'firestore_service.dart'; // Firestore işlemleri servisi
import 'pdf_sales_template.dart'; // PDF şablonu

// --- Sabit Değerler ---
const double kKdvOrani = 0.20; // KDV Oranı
const String kUsersCollection = 'users';
const String kUrunlerCollection = 'urunler';
const String kVeritabaniDenemeCollection = 'veritabanideneme'; // Müşteri bilgileri için? İsim daha açıklayıcı olabilir.
const String kTemporarySelectionsCollection = 'temporarySelections';
const String kCustomerDetailsCollection = 'customerDetails';
const String kSalesCollection = 'sales';
const String kQuotesCollection = 'quotes';
const String kCashPaymentsCollection = 'cashPayments';
const String kLowStockRequestsCollection = 'lowStockRequests';
const String kStoktaUrunlerCollection = 'stoktaUrunler';
const String kCustomerSelectionsCollection = 'customerSelections'; // onCustomerSelected içinde kullanılıyor
const String kSelectedCustomerDoc = 'current'; // Müşteri seçimi için kullanılan doküman ID'si?

// --- Ana Widget ---
class ScanScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onCustomerProcessed;
  final String? documentId; // Null olabilir, geçici sepet doküman ID'si

  ScanScreen({
    required this.onCustomerProcessed,
    this.documentId, // documentId artık opsiyonel
    Key? key, // Key eklendi
  }) : super(key: key);

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

// --- State Sınıfı ---
class _ScanScreenState extends State<ScanScreen> {
  // --- Servisler ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final DovizService _dovizService = DovizService();
  final CustomerSelectionService _customerSelectionService = CustomerSelectionService();
  final Connectivity _connectivity = Connectivity();

  // --- Controller'lar ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _quantityController = TextEditingController(); // Düzenleme için

  // --- State Değişkenleri ---
  List<String> _customers = []; // Tüm müşteriler
  List<String> _filteredCustomers = []; // Arama filtresine göre müşteriler
  String? _selectedCustomer; // Seçili müşteri adı
  List<Map<String, dynamic>> _scannedProducts = []; // Sepetteki ürünler
  // List<Map<String, dynamic>> _originalProducts = []; // Orijinal ürün verileri (kullanımı gözden geçirilebilir)

  String _barcodeResult = ""; // Son okunan barkod
  String _dolarKur = ""; // Dolar kuru
  String _euroKur = ""; // Euro kuru
  double _subtotal = 0.0; // Ara toplam
  double _vat = 0.0; // KDV tutarı
  double _grandTotal = 0.0; // Genel toplam

  bool _isConnected = true; // İnternet bağlantı durumu
  StreamSubscription<ConnectivityResult>? _connectivitySubscription; // Bağlantı dinleyicisi

  User? _currentUser; // Mevcut Firebase kullanıcısı
  String _currentUserFullName = 'Bilinmeyen Kullanıcı'; // Mevcut kullanıcının adı

  bool _isEditing = false; // Tabloda düzenleme modu aktif mi?
  int _editingIndex = -1; // Düzenlenen satırın indeksi
  Map<String, dynamic>? _originalProductDataBeforeEdit; // Düzenleme iptali için orijinal veri

  String get _currentDateFormatted => DateFormat('d MMMM y', 'tr_TR').format(DateTime.now());

  // --- Lifecycle Metotları ---
  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    // Controller'ları ve abonelikleri temizle
    _connectivitySubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // --- Başlatma Fonksiyonları ---
  Future<void> _initializeScreen() async {
    // Önce bağlantıyı kontrol et
    await _checkInitialConnectivity();

    // Kullanıcı ve kur bilgilerini eş zamanlı çekmeye başla
    final Future<void> userFuture = _fetchCurrentUserAndName();
    final Future<void> dovizFuture = _initializeDovizKur();
    final Future<void> customersFuture = _fetchCustomers();

    // Hepsinin bitmesini bekle
    await Future.wait([userFuture, dovizFuture, customersFuture]);

    // Bağlantı değişikliklerini dinlemeye başla
    _listenToConnectivity();

    // Geçici sepet verilerini dinlemeye başla (documentId varsa)
    if (widget.documentId != null) {
      _listenToTemporarySelections();
    } else {
      // documentId yoksa, hata durumu veya başlangıç durumu yönetilmeli
      print("Uyarı: Geçici sepet için documentId sağlanmadı.");
      // Belki yeni bir documentId oluşturulabilir veya kullanıcı uyarılabilir.
    }

    // Gerekirse başlangıç verilerini yükle (kullanımı net değil, şimdilik yorumda)
    // await _loadInitialData();
  }

  Future<void> _fetchCurrentUserAndName() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      try {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
            .collection(kUsersCollection)
            .doc(_currentUser!.uid)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _currentUserFullName = userDoc.data()?['fullName'] ?? 'İsimsiz Kullanıcı';
          });
        } else {
          _currentUserFullName = 'Kullanıcı Bulunamadı';
        }
      } catch (e) {
        print("Kullanıcı adı alınırken hata: $e");
        _currentUserFullName = 'Hata Oluştu';
        if (mounted) setState(() {}); // Hata durumunu UI'a yansıt
      }
    }
  }

  Future<void> _initializeDovizKur() async {
    try {
      // scheduleDailyUpdate çağrısı burada gerekli mi? Servis içinde yönetilebilir.
      // _dovizService.scheduleDailyUpdate();
      var kurlar = await _dovizService.getDovizKur();
      if (mounted) {
        setState(() {
          _dolarKur = kurlar['dolar'] ?? 'Alınamadı';
          _euroKur = kurlar['euro'] ?? 'Alınamadı';
        });
      }
    } catch (e) {
      print("Döviz kuru alınırken hata: $e");
      if (mounted) {
        setState(() {
          _dolarKur = 'Hata';
          _euroKur = 'Hata';
        });
      }
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      var querySnapshot = await _firestore.collection(kVeritabaniDenemeCollection).get();
      var descriptions = querySnapshot.docs
          .map((doc) => (doc.data())['Açıklama'] as String? ?? 'İsimsiz Müşteri')
          .toList();

      if (mounted) {
        setState(() {
          _customers = descriptions;
          _filteredCustomers = descriptions;
        });
      }
    } catch (e) {
      print("Müşteriler çekilirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Müşteri listesi alınamadı: $e')),
        );
      }
    }
  }

  // --- Bağlantı Yönetimi ---
  Future<void> _checkInitialConnectivity() async {
    try {
      ConnectivityResult result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print("Başlangıç bağlantı kontrolü hatası: $e");
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final bool wasConnected = _isConnected;
    final bool isNowConnected = result != ConnectivityResult.none;

    if (mounted) {
      setState(() {
        _isConnected = isNowConnected;
      });
    }
    print('Bağlantı Durumu Değişti: $_isConnected');

    // Bağlantı GELDİĞİNDE yapılacak işlemler (örneğin, bekleyen işlemleri tetikleme)
    if (!wasConnected && isNowConnected) {
      print("Bağlantı geri geldi, bekleyen işlemler kontrol edilebilir.");
      // Örneğin, döviz kurunu tekrar çekebilir veya senkronizasyon başlatılabilir.
      _initializeDovizKur(); // Kurları güncelle
    }

    // Bağlantı GİTTİĞİNDE yapılacak işlemler (örneğin, kullanıcıyı bilgilendirme)
    if (wasConnected && !isNowConnected) {
      _showNoConnectionDialog('Bağlantı Kesildi', 'İnternet bağlantınız yok. Bazı işlemler yapılamayabilir.');
      // ÖNEMLİ: Bağlantı yokken Firestore'a bağlı updateProductsForCustomer çağrılmamalı.
      // Bu kısım kaldırıldı.
    }
  }

  Future<bool> _checkConnectionAndNotify() async {
    if (!_isConnected) {
      // Fonksiyon void döndürdüğü için await sonrası değer beklenmiyor.
      _showNoConnectionDialog('Bağlantı Sorunu', 'Bu işlem için internet bağlantısı gerekli.');
      return false;
    }
    return true;
  }

  // --- Firestore Dinleyicisi ---
  void _listenToTemporarySelections() {
    _firestore
        .collection(kTemporarySelectionsCollection)
        .doc(widget.documentId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        var data = snapshot.data();
        if (data != null) {
          setState(() {
            // Müşteri değiştiyse ve yeni müşteri null değilse güncelle
            // Bu, başka bir yerden müşteri seçimi yapıldığında burayı da günceller.
            final newCustomer = data['customerName'] as String?;
            if (_selectedCustomer != newCustomer) {
              _selectedCustomer = newCustomer;
              // Müşteri değiştiğinde arama filtresini de sıfırlayabiliriz
              _searchController.clear();
              _filterCustomers('');
            }

            _scannedProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
            // Toplamları doğrudan Firestore'dan okuyabiliriz veya burada hesaplayabiliriz.
            // Firestore'dan okumak daha tutarlı olabilir.
            _subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
            _vat = (data['vat'] as num?)?.toDouble() ?? 0.0;
            _grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
            // Alternatif: _updateTotalAndVat(); // Her dinlemede yeniden hesaplar
          });
        }
      } else if (mounted) {
        // Doküman silinmiş veya yoksa, ekranı temizle
        print("Geçici sepet dokümanı bulunamadı veya silindi: ${widget.documentId}");
        // _clearScreenLocally(); // Ekrani temizle
      }
    }, onError: (error) {
      print("Geçici sepet dinlenirken hata: $error");
      // Hata durumunda kullanıcıya bilgi verilebilir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sepet verileri alınırken hata oluştu.')),
        );
      }
    });
  }

  // --- Müşteri İşlemleri ---
  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = _customers
          .where((customer) =>
          customer.toLowerCase().contains(query.toLowerCase()))
          .toList();
      // Eğer seçili müşteri filtrelenen listede yoksa seçimi kaldırma (opsiyonel)
      // if (_selectedCustomer != null && !_filteredCustomers.contains(_selectedCustomer)) {
      //   _selectedCustomer = null;
      // }
    });
  }

  Future<void> _onCustomerSelectedFromDropdown(String? customerName) async {
    if (customerName == null) return;
    if (!await _checkConnectionAndNotify()) return; // Bağlantıyı kontrol et

    // 1. Müşteri bilgilerini ve iskontosunu Firestore'a (temporarySelections) kaydet
    await _selectCustomerAndUpdateTemporary(customerName);

    // 2. Mevcut ürünlerin fiyatlarını yeni müşterinin iskontosuna göre güncelle
    await _updateDiscountAndBrandForCustomer(); // Bu fonksiyon içinde toplamlar güncelleniyor

    // 3. UI'ı güncelle (setState zaten _selectCustomerAndUpdateTemporary içinde çağrılıyor)
    // Not: onCustomerSelected fonksiyonundaki customerSelections koleksiyonuna yazma
    //      mantığı buraya taşınabilir veya ayrı bir yerde tutulabilir. Şimdilik kaldırıldı.
  }

  Future<void> _selectCustomerAndUpdateTemporary(String customerName) async {
    if (widget.documentId == null) {
      print("Hata: Geçici sepet documentId null.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Müşteri seçimi için sepet ID bulunamadı.')),
      );
      return;
    }

    try {
      // Müşterinin iskonto seviyesini al (veritabanideneme'den)
      var customerDoc = await _firestore
          .collection(kVeritabaniDenemeCollection)
          .where('Açıklama', isEqualTo: customerName)
          .limit(1) // Tek bir müşteri bekliyoruz
          .get();

      String iskontoLevel = '';
      if (customerDoc.docs.isNotEmpty) {
        iskontoLevel = customerDoc.docs.first.data()['iskonto'] ?? '';
      } else {
        print("Uyarı: Müşteri '$customerName' için detaylar bulunamadı.");
        // İskonto seviyesi olmadan devam edilebilir veya hata verilebilir.
      }

      // temporarySelections'ı güncelle
      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .update({
        'customerName': customerName,
        'iskonto': iskontoLevel, // İskonto seviyesini de kaydet
        // 'products': _scannedProducts, // Ürünler zaten Stream ile güncelleniyor, burada tekrar yazmaya gerek yok
      });

      print("Seçilen müşteri: $customerName, İskonto seviyesi: $iskontoLevel");

      // UI'da seçili müşteriyi güncelle (Stream dinleyicisi de yapabilir ama anında yansıtmak için)
      if(mounted){
        setState(() {
          _selectedCustomer = customerName;
        });
      }

    } catch (e) {
      print("Müşteri seçimi güncellenirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Müşteri seçimi güncellenemedi: $e')),
        );
      }
    }
  }

  // --- Barkod ve Ürün İşlemleri ---
  Future<void> scanBarcode() async {
    if (!await _checkConnectionAndNotify()) return;

    try {
      var result = await BarcodeScanner.scan();
      if (mounted) {
        setState(() {
          _barcodeResult = result.rawContent;
        });
      }
      if (_barcodeResult.isNotEmpty) {
        await _fetchProductDetailsAndAdd(_barcodeResult);
      }
    } on Exception catch (e) { // Daha spesifik hatalar yakalanabilir
      print('Barkod okuma hatası: $e');
      if (mounted) {
        setState(() {
          _barcodeResult = 'Hata: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barkod okunamadı: $e')),
        );
      }
    }
  }

  Future<void> _fetchProductDetailsAndAdd(String barcode) async {
    try {
      var products = await _firestoreService.fetchProductsByBarcode(barcode);
      if (products.isEmpty) {
        print("Hata: Barkod '$barcode' ile eşleşen ürün bulunamadı.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bu barkoda ait ürün bulunamadı.')),
          );
        }
        return;
      }

      print("Barkod '$barcode' için ${products.length} ürün bulundu.");

      // Aynı koda sahip ürünleri tekilleştir (gerekliyse)
      var uniqueProducts = <Map<String, dynamic>>[];
      var seenCodes = <String>{};
      for (var product in products) {
        if (product['Kodu'] != null && seenCodes.add(product['Kodu'])) {
          uniqueProducts.add(product);
        }
      }

      if (uniqueProducts.length > 1) {
        // Birden fazla ürün varsa seçim dialogu göster
        _showProductSelectionDialog(uniqueProducts);
      } else if (uniqueProducts.isNotEmpty) {
        // Tek ürün varsa doğrudan ekle
        await _addProductToTemporarySelection(uniqueProducts.first);
      } else {
        print("Hata: Geçerli ürün kodu bulunamadı.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ürün bilgisi alınamadı.')),
          );
        }
      }
    } catch (e) {
      print("Ürün detayı alınırken veya eklenirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün detayı alınamadı: $e')),
        );
      }
    }
  }

  void _showProductSelectionDialog(List<Map<String, dynamic>> products) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Birden Fazla Ürün Bulundu'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (BuildContext context, int index) {
                final product = products[index];
                return ListTile(
                  title: Text(product['Detay'] ?? 'İsimsiz Ürün'),
                  subtitle: Text(product['Kodu'] ?? 'Kod Yok'),
                  onTap: () async {
                    Navigator.of(context).pop(); // Dialogu kapat
                    await _addProductToTemporarySelection(product);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addProductToTemporarySelection(Map<String, dynamic> productData) async {
    if (widget.documentId == null) {
      print("Hata: Ürün eklemek için sepet ID'si yok.");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktif sepet bulunamadı.')));
      return;
    }
    if (productData['Kodu'] == null) {
      print("Hata: Ürün kodu eksik.");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Geçersiz ürün verisi.')));
      return;
    }

    try {
      // 1. Ürün detaylarını (fiyat, döviz vb.) 'urunler' koleksiyonundan AL
      // Not: productData zaten fetchProductsByBarcode'dan geliyor, tekrar çekmeye gerek olmayabilir.
      // Ancak verinin güncelliği önemliyse tekrar çekilebilir. Şimdilik gelen veriyi kullanalım.
      Map<String, dynamic> productDetails = productData; // veya await _firestoreService.fetchProductDetails(productData['Kodu']);

      double price = double.tryParse(productDetails['Fiyat']?.toString() ?? '0.0') ?? 0.0;
      String currency = productDetails['Doviz']?.toString() ?? '';
      String brand = productDetails['Marka']?.toString() ?? '';

      if (price <= 0.0) {
        print("Uyarı: Ürün fiyatı 0 veya negatif: ${productDetails['Kodu']}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ürün fiyatı geçersiz: ${productDetails['Kodu']}')),
          );
        }
        return; // Fiyat geçersizse ekleme
      }

      // 2. Adet ve stok durumu için dialog göster
      Map<String, dynamic>? dialogResult = await _showQuantityInputDialog(productDetails['Kodu']);
      if (dialogResult == null) return; // Kullanıcı iptal etti

      int quantity = dialogResult['quantity'] as int? ?? 1;
      bool isLowStock = dialogResult['isLowStock'] as bool? ?? false;
      int? orderQuantity = dialogResult['orderQuantity'] as int?;
      String? description = dialogResult['description'] as String?;

      // 3. Fiyatı TL'ye çevir ve iskontoyu uygula
      double priceInTl = _calculatePriceInTl(price, currency);
      double discountRate = await _getDiscountRateForCustomer(brand); // Müşteri seçiliyse iskontoyu al
      double discountedPrice = priceInTl * (1 - (discountRate / 100));
      double totalPrice = discountedPrice * quantity;

      // 4. Eklenecek ürün bilgisini oluştur
      Map<String, dynamic> productInfo = {
        'Kodu': productDetails['Kodu'],
        'Detay': productDetails['Detay'] ?? '',
        'Adet': quantity.toString(),
        'Adet Fiyatı': discountedPrice.toStringAsFixed(2), // İskontolu TL fiyat
        'Toplam Fiyat': totalPrice.toStringAsFixed(2),
        'İskonto': '%${discountRate.toStringAsFixed(2)}', // Yüzde olarak
        'addedBy': _currentUserFullName, // Ekleyen kullanıcı
        // Orijinal verileri de saklamak faydalı olabilir (müşteri değişince tekrar hesaplamak için)
        'Original Fiyat': price,
        'Original Doviz': currency,
        'Marka': brand,
      };

      // 5. Ürünü Firestore'daki temporarySelections'a ekle
      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .update({
        'products': FieldValue.arrayUnion([productInfo]) // arrayUnion kullanmak daha verimli
      });

      // 6. Stok durumu düşükse ilgili koleksiyona ekle
      if (isLowStock) {
        await _addProductToLowStockRequests(
          productDetails, // Ham ürün verisi
          _currentUserFullName,
          orderQuantity,
          description,
        );
      }

      // 7. Toplamları güncelle (StreamBuilder zaten yapacak ama anında yansıma için çağrılabilir)
      // _updateTotalAndVat(); // Bu fonksiyon Firestore'a yazıyor, Stream varken gereksiz olabilir.

      // 8. Başarı mesajı ve kaydırma
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${productDetails['Kodu']} eklendi.')));
        // Sayfayı aşağı kaydır
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

    } catch (e) {
      print("Ürün eklenirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün eklenemedi: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showQuantityInputDialog(String productCode) async {
    // --- Bu fonksiyon öncekiyle büyük ölçüde aynı, iyileştirmeler eklenebilir ---
    // Örneğin: Stok kontrolü için Firestore okumasını optimize etmek,
    // UI'ı daha kullanıcı dostu yapmak.
    // Mevcut haliyle bırakıyorum, ana mantık doğru görünüyor.

    TextEditingController quantityControllerLocal = TextEditingController(text: '1');
    TextEditingController orderQuantityController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    bool isLowStock = false;
    bool isInStock = false; // Stok durumu
    bool showAddToStockButton = false; // "Ürünü stoğa ekle" butonunu göstermek için
    bool isLoadingStock = true; // Stok durumu yükleniyor mu?

    // Stok durumunu asenkron olarak kontrol et
    Future<void> checkStockStatus() async {
      try {
        DocumentSnapshot<Map<String, dynamic>> productSnapshot = await _firestore
            .collection(kStoktaUrunlerCollection)
            .doc(productCode)
            .get();
        isInStock = productSnapshot.exists;
      } catch (e) {
        print("Stok durumu kontrol edilirken hata oluştu: $e");
        isInStock = false; // Hata durumunda stokta yok varsayalım
      } finally {
        showAddToStockButton = !isInStock;
        isLoadingStock = false;
        // Dialog içindeki state'i güncellemek için setState gerekecek (StatefulBuilder ile)
      }
    }

    // Dialog ekranı açılıyor
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        // Stok durumunu dialog açıldığında kontrol etmeye başla
        checkStockStatus();

        return StatefulBuilder( // Dialog içeriğini güncelleyebilmek için
          builder: (context, setStateDialog) {
            // Stok durumu kontrolü bittiğinde UI'ı güncellemek için
            if (!isLoadingStock && (showAddToStockButton != !isInStock)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setStateDialog(() {
                  showAddToStockButton = !isInStock;
                });
              });
            }

            return AlertDialog(
              title: Text('Adet ve Stok Durumu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Adet girişi
                    TextField(
                      controller: quantityControllerLocal,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Adet'),
                      autofocus: true, // Otomatik odaklanma
                    ),
                    SizedBox(height: 15),
                    // Stok durumu düşük checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: isLowStock,
                          onChanged: (value) {
                            setStateDialog(() { // Dialog state'ini güncelle
                              isLowStock = value ?? false;
                            });
                          },
                        ),
                        Text('Stok Durumu Düşük'),
                      ],
                    ),
                    // Stok durumu düşükse ek alanlar
                    if (isLowStock) ...[
                      TextField(
                        controller: orderQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Sipariş Geçilecek Adet'),
                      ),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(labelText: 'Açıklama (Opsiyonel)'),
                      ),
                    ],
                    SizedBox(height: 20),
                    // Stok durumu bilgisi veya stoğa ekle butonu
                    if (isLoadingStock)
                      Center(child: CircularProgressIndicator(strokeWidth: 2))
                    else if (isInStock)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Ürün Stokta Mevcut', style: TextStyle(color: Colors.green)),
                          SizedBox(width: 8),
                          BlinkingCircle(), // Yanıp sönen daire
                        ],
                      )
                    else // Stokta yoksa veya kontrol edilemediyse
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Stoğa ekleme onayı
                          bool confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Stoğa Ekle Onayı'),
                              content: Text('$productCode kodlu ürünü stoğa eklemek istiyor musunuz?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Hayır')),
                                TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Evet')),
                              ],
                            ),
                          ) ?? false;

                          if (confirm) {
                            try {
                              // Stoğa ekle (stoktaUrunler koleksiyonuna ekle)
                              // Gerekli diğer ürün bilgileri de buraya eklenmeli (Detay, Fiyat vb.)
                              // Bu bilgiler productDetails'ten alınabilir.
                              await _firestore.collection(kStoktaUrunlerCollection).doc(productCode).set({
                                'Kodu': productCode,
                                // 'Detay': productDetails['Detay'] ?? 'Bilinmiyor',
                                // 'Marka': productDetails['Marka'] ?? 'Bilinmiyor',
                                'eklenmeTarihi': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              setStateDialog(() { // Dialog state'ini güncelle
                                isInStock = true;
                                showAddToStockButton = false;
                              });
                              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ürün stoğa eklendi.')));

                            } catch (e) {
                              print("Stoğa ekleme hatası: $e");
                              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stoğa ekleme başarısız: $e')));
                            }
                          }
                        },
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Ürünü Stoğa Ekle'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('İptal'),
                  onPressed: () => Navigator.of(context).pop(), // null döner
                ),
                TextButton(
                  child: Text('Tamam'),
                  onPressed: () {
                    final int quantity = int.tryParse(quantityControllerLocal.text) ?? 1;
                    final int? orderQty = isLowStock ? (int.tryParse(orderQuantityController.text) ?? null) : null;
                    final String description = descriptionController.text;

                    Navigator.of(context).pop({
                      'quantity': quantity > 0 ? quantity : 1, // Negatif veya 0 olmasın
                      'isLowStock': isLowStock,
                      'orderQuantity': orderQty,
                      'description': description,
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addProductToLowStockRequests(
      Map<String, dynamic> productDetails,
      String? currentUserFullName,
      int? orderQuantity,
      String? description) async {
    try {
      await _firestore.collection(kLowStockRequestsCollection).add({
        'Kodu': productDetails['Kodu'],
        'Detay': productDetails['Detay'],
        'orderQuantity': orderQuantity, // İstenen sipariş adedi
        'description': description, // Açıklama
        'requestedBy': currentUserFullName ?? 'Bilinmeyen Kullanıcı',
        'requestDate': FieldValue.serverTimestamp(), // Sunucu zamanı
        'status': 'pending', // Başlangıç durumu
      });
      print('Ürün (${productDetails['Kodu']}) düşük stok taleplerine eklendi.');
    } catch (e) {
      print('Düşük stok talebi eklenirken hata: $e');
      // Kullanıcıya hata mesajı gösterilebilir.
    }
  }

  // --- Fiyat ve İskonto Hesaplamaları ---
  double _calculatePriceInTl(double price, String currency) {
    if (currency == 'Euro') {
      return price * (double.tryParse(_euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      return price * (double.tryParse(_dolarKur.replaceAll(',', '.')) ?? 0.0);
    } else {
      return price; // TL veya bilinmeyen kur ise doğrudan fiyatı kullan
    }
  }

  Future<double> _getDiscountRateForCustomer(String brand) async {
    if (_selectedCustomer == null) return 0.0;

    try {
      // Müşterinin iskonto seviyesini al (veritabanideneme'den)
      // Bu bilgi _selectCustomerAndUpdateTemporary içinde zaten alınıp temporarySelections'a yazılıyor.
      // Oradan okumak daha verimli olabilir.
      DocumentSnapshot<Map<String, dynamic>> tempDoc = await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .get();

      String discountLevel = '';
      if (tempDoc.exists) {
        discountLevel = tempDoc.data()?['iskonto'] ?? '';
      } else {
        // Alternatif: Müşteri detaylarından tekrar çek
        var customerDiscount = await _firestoreService.getCustomerDiscount(_selectedCustomer!);
        discountLevel = customerDiscount['iskonto'] ?? '';
      }


      if (discountLevel.isEmpty) return 0.0;

      // İskonto seviyesine ve markaya göre oranı al
      var discountData = await _firestoreService.getDiscountRates(discountLevel, brand);
      return double.tryParse(discountData['rate']?.toString() ?? '0.0') ?? 0.0;
    } catch (e) {
      print("İskonto oranı alınırken hata: $e");
      return 0.0; // Hata durumunda iskonto yok
    }
  }

  Future<void> _updateDiscountAndBrandForCustomer() async {
    if (_selectedCustomer == null || widget.documentId == null) return;
    if (!await _checkConnectionAndNotify()) return;

    print("Müşteri değişti, ürün fiyatları güncelleniyor: $_selectedCustomer");

    try {
      List<Map<String, dynamic>> updatedProducts = [];
      bool needsUpdate = false;

      // Mevcut ürün listesini al (doğrudan state'den değil, Firestore'dan okumak daha güvenli olabilir)
      DocumentSnapshot<Map<String, dynamic>> tempDoc = await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .get();

      if (!tempDoc.exists) return; // Sepet yoksa çık

      List<dynamic> currentProducts = tempDoc.data()?['products'] ?? [];


      for (var productDataDyn in currentProducts) {
        Map<String, dynamic> productData = Map<String, dynamic>.from(productDataDyn);
        String productCode = productData['Kodu']?.toString() ?? '';
        if (productCode.isEmpty) continue;

        // Orijinal fiyat ve kur bilgilerini üründen al (eğer saklandıysa)
        double originalPrice = (productData['Original Fiyat'] as num?)?.toDouble() ?? 0.0;
        String currency = productData['Original Doviz']?.toString() ?? '';
        String brand = productData['Marka']?.toString() ?? '';
        int quantity = int.tryParse(productData['Adet']?.toString() ?? '1') ?? 1;

        // Eğer orijinal fiyat bilgisi yoksa, ürünü tekrar çek (eski veri uyumluluğu için)
        if (originalPrice <= 0.0) {
          print("Uyarı: Orijinal fiyat bilgisi eksik, ${productCode} için Firestore'dan çekiliyor.");
          var productDetails = await _firestoreService.fetchProductDetails(productCode);
          originalPrice = double.tryParse(productDetails['Fiyat']?.toString() ?? '0.0') ?? 0.0;
          currency = productDetails['Doviz']?.toString() ?? '';
          brand = productDetails['Marka']?.toString() ?? '';
          // Eksik bilgileri ürüne ekleyebiliriz (opsiyonel)
          productData['Original Fiyat'] = originalPrice;
          productData['Original Doviz'] = currency;
          productData['Marka'] = brand;
        }

        if (originalPrice <= 0.0) {
          print("Hata: ${productCode} için geçerli fiyat bulunamadı.");
          updatedProducts.add(productData); // Hatalı da olsa listeyi koru
          continue;
        }

        // Fiyatı TL'ye çevir ve yeni iskontoyu uygula
        double priceInTl = _calculatePriceInTl(originalPrice, currency);
        double discountRate = await _getDiscountRateForCustomer(brand); // Yeni müşteri için iskontoyu al
        double discountedPrice = priceInTl * (1 - (discountRate / 100));
        double totalPrice = discountedPrice * quantity;

        // Ürün bilgilerini güncelle
        productData['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
        productData['Toplam Fiyat'] = totalPrice.toStringAsFixed(2);
        productData['İskonto'] = '%${discountRate.toStringAsFixed(2)}';

        updatedProducts.add(productData);
        needsUpdate = true; // En az bir ürün güncellendi
      }

      // Eğer güncelleme yapıldıysa Firestore'u güncelle
      if (needsUpdate) {
        // Toplamları da yeniden hesapla ve Firestore'a yaz
        double newSubtotal = 0.0;
        for (var p in updatedProducts) {
          newSubtotal += double.tryParse(p['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0;
        }
        double newVat = newSubtotal * kKdvOrani;
        double newGrandTotal = newSubtotal + newVat;

        await _firestore
            .collection(kTemporarySelectionsCollection)
            .doc(widget.documentId)
            .update({
          'products': updatedProducts,
          'subtotal': newSubtotal,
          'vat': newVat,
          'grandTotal': newGrandTotal,
        });
        print("Ürün fiyatları ve toplamlar Firestore'da güncellendi.");
      }

      // UI zaten StreamBuilder ile güncellenecek.
      // setState(() {}); // Gerekli değil

    } catch (e) {
      print("Müşteri değişimi sonrası fiyat güncelleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fiyatlar güncellenirken hata oluştu: $e')),
        );
      }
    }
  }

  // --- Tablo İşlemleri (Adet Güncelleme, Silme, Düzenleme) ---
  void _updateQuantity(int index, String quantityStr) async {
    if (widget.documentId == null) return;
    if (!await _checkConnectionAndNotify()) return; // Bağlantı gerekebilir

    int quantity = int.tryParse(quantityStr) ?? 1;
    if (quantity <= 0) quantity = 1; // Minimum 1 adet

    try {
      // Güncellenecek ürünün mevcut verisini al (doğrudan state yerine Firestore'dan okumak daha güvenli)
      DocumentSnapshot<Map<String, dynamic>> tempDoc = await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .get();
      if (!tempDoc.exists) return;

      List<dynamic> currentProductsDyn = tempDoc.data()?['products'] ?? [];
      List<Map<String, dynamic>> currentProducts = List<Map<String, dynamic>>.from(currentProductsDyn);

      if (index < 0 || index >= currentProducts.length) return; // Geçersiz index

      Map<String, dynamic> productToUpdate = currentProducts[index];

      double unitPrice = double.tryParse(productToUpdate['Adet Fiyatı']?.toString() ?? '0.0') ?? 0.0;
      double newTotalPrice = unitPrice * quantity;

      // Ürün bilgisini güncelle
      productToUpdate['Adet'] = quantity.toString();
      productToUpdate['Toplam Fiyat'] = newTotalPrice.toStringAsFixed(2);

      // Tüm listeyi Firestore'a yaz (veya sadece ilgili elemanı güncellemenin bir yolunu bul)
      // Toplamları da yeniden hesapla
      double newSubtotal = 0.0;
      for (var p in currentProducts) {
        newSubtotal += double.tryParse(p['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0;
      }
      double newVat = newSubtotal * kKdvOrani;
      double newGrandTotal = newSubtotal + newVat;

      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .update({
        'products': currentProducts,
        'subtotal': newSubtotal,
        'vat': newVat,
        'grandTotal': newGrandTotal,
      });

      // UI zaten StreamBuilder ile güncellenecek.
      // setState(() {}); // Gerekli değil

    } catch (e) {
      print("Adet güncellenirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adet güncellenemedi: $e')),
        );
      }
    }
  }

  void _removeProduct(int index) async {
    if (widget.documentId == null) return;
    if (!await _checkConnectionAndNotify()) return;

    // Onay dialogu
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ürünü Kaldır'),
        content: Text('Bu ürünü sepetten kaldırmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Hayır')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Evet')),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // Silinecek ürünün bilgisini al (arrayRemove için gerekli)
      DocumentSnapshot<Map<String, dynamic>> tempDoc = await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .get();
      if (!tempDoc.exists) return;

      List<dynamic> currentProductsDyn = tempDoc.data()?['products'] ?? [];
      if (index < 0 || index >= currentProductsDyn.length) return; // Geçersiz index

      Map<String, dynamic> productToRemove = Map<String, dynamic>.from(currentProductsDyn[index]);

      // Ürünü Firestore'dan kaldır
      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .update({
        'products': FieldValue.arrayRemove([productToRemove]),
      });

      // Toplamları yeniden hesapla ve güncelle (arrayRemove sonrası toplamları manuel güncellemek gerekir)
      List<Map<String, dynamic>> remainingProducts = List<Map<String, dynamic>>.from(currentProductsDyn);
      remainingProducts.removeAt(index); // Yerel kopyadan da kaldır

      double newSubtotal = 0.0;
      for (var p in remainingProducts) {
        newSubtotal += double.tryParse(p['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0;
      }
      double newVat = newSubtotal * kKdvOrani;
      double newGrandTotal = newSubtotal + newVat;

      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .update({
        'subtotal': newSubtotal,
        'vat': newVat,
        'grandTotal': newGrandTotal,
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün kaldırıldı.')),
        );
      }
      // UI zaten StreamBuilder ile güncellenecek.
      // setState(() {}); // Gerekli değil

    } catch (e) {
      print("Ürün kaldırılırken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ürün kaldırılamadı: $e')),
        );
      }
    }
  }

  void _startEditing(int index) {
    if (!_isConnected) {
      _showNoConnectionDialog('Bağlantı Sorunu', 'Düzenleme yapmak için internet bağlantısı gerekli.');
      return;
    }
    if (index >= 0 && index < _scannedProducts.length) {
      setState(() {
        _isEditing = true;
        _editingIndex = index;
        _originalProductDataBeforeEdit = Map<String, dynamic>.from(_scannedProducts[index]); // Orijinal veriyi kopyala
        _quantityController.text = _scannedProducts[index]['Adet']?.toString() ?? '1';
      });
    }
  }

  void _handleEditSubmit(int index) {
    if (!_isConnected) {
      _showNoConnectionDialog('Bağlantı Sorunu', 'Kaydetmek için internet bağlantısı gerekli.');
      return;
    }
    final newQuantity = _quantityController.text;
    setState(() {
      _isEditing = false;
      _editingIndex = -1;
      _originalProductDataBeforeEdit = null; // Orijinal veriyi temizle
    });
    _updateQuantity(index, newQuantity); // Firestore'u ve toplamları güncelle
  }

  void _handleEditCancel(int index) {
    setState(() {
      // Değişiklikleri geri al (eğer _scannedProducts state'i doğrudan değiştirildiyse)
      // StreamBuilder kullanıldığı için bu genellikle gerekli olmaz,
      // ama düzenleme sırasında UI'da anlık değişiklik yapıldıysa geri almak gerekebilir.
      // if (_originalProductDataBeforeEdit != null) {
      //   _scannedProducts[index] = _originalProductDataBeforeEdit!;
      // }
      _isEditing = false;
      _editingIndex = -1;
      _originalProductDataBeforeEdit = null;
    });
  }

  // --- Toplam Hesaplama ve Güncelleme ---
  // Not: StreamBuilder Firestore'dan okuduğu için bu fonksiyonun sürekli çağrılmasına gerek olmayabilir.
  // Sadece Firestore'a yazarken kullanılabilir.
  void _updateTotalAndVat() {
    double currentSubtotal = 0.0;
    for (var product in _scannedProducts) {
      // Kodu olmayan veya boş olan satırları atla (varsa)
      if (product['Kodu']?.toString().isEmpty ?? true) continue;
      currentSubtotal += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0;
    }

    final currentVat = currentSubtotal * kKdvOrani;
    final currentGrandTotal = currentSubtotal + currentVat;

    // UI'ı güncellemek için setState (Eğer StreamBuilder kullanılmıyorsa)
    // if (mounted) {
    //   setState(() {
    //     _subtotal = currentSubtotal;
    //     _vat = currentVat;
    //     _grandTotal = currentGrandTotal;
    //   });
    // }

    // Değişiklikleri Firestore'a yaz (Gerekliyse)
    // _updateTotalsInFirestore(currentSubtotal, currentVat, currentGrandTotal);
  }

  // Bu fonksiyon artık doğrudan StreamBuilder'dan gelen veriyi kullanıyor veya
  // _updateDiscountAndBrandForCustomer, _updateQuantity, _removeProduct içinde
  // toplamlar hesaplanıp Firestore'a yazılıyor.
  /*
  Future<void> _updateTotalsInFirestore(double sub, double vatAmount, double grand) async {
    if (widget.documentId == null) return;
    try {
      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .update({
        'subtotal': sub,
        'vat': vatAmount,
        'grandTotal': grand,
      });
    } catch (e) {
      print("Firestore'da toplamlar güncellenirken hata: $e");
      // Hata yönetimi
    }
  }
  */


  // --- İşlem Sonlandırma Fonksiyonları ---

  // Hesaba İşle Butonu Akışı:
  // 1. Butona basılır.
  // 2. _showProcessingDialog çağrılır.
  // 3. Dialog, kullanıcıya son kontrol için sepeti gösterir (opsiyonel olarak ek bilgiler sorar).
  // 4. Dialog'daki "Kaydet" butonu Navigator.pop(true) yapar. "İptal" Navigator.pop(false) yapar.
  // 5. Dialog kapanınca dönen değere göre _processSale çağrılır.
  Future<void> _onProcessToAccountPressed() async {
    if (_selectedCustomer == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lütfen bir müşteri seçin.')));
      return;
    }
    if (_scannedProducts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sepette ürün bulunmuyor.')));
      return;
    }
    if (!await _checkConnectionAndNotify()) return;

    // Son kontrol ve onay dialogu
    bool? shouldProceed = await _showProcessingDialog();

    if (shouldProceed == true) {
      // Kullanıcı onayladı, satışı işle
      await _processSale();
      // Başarılı olursa ekran temizlenir ve yönlendirme yapılır (_processSale içinde)
    } else {
      // Kullanıcı iptal etti
      print('Hesaba işleme iptal edildi.');
    }
  }

  Future<bool?> _showProcessingDialog() async {
    // Bu dialog, siparişle ilgili ek bilgileri (teslim alan vb.) sormak için kullanılabilir.
    // Şimdilik sadece onay amaçlı kullanılıyor ve sepeti tekrar gösteriyor.
    // Önceki kodda bulunan whoTook, recipient gibi alanlar kaldırıldı, gerekirse eklenebilir.

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
      builder: (BuildContext context) {
        // Dialog içeriği için ayrı bir state tutmaya gerek yoksa StatelessWidget olabilir.
        return AlertDialog(
          title: Text('Siparişi Onayla'),
          content: SingleChildScrollView( // İçerik taşabilir
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Müşteri: $_selectedCustomer'),
                SizedBox(height: 10),
                Text('Aşağıdaki ürünler hesaba işlenecektir:'),
                SizedBox(height: 10),
                // Sepeti tekrar göstermek yerine sadece toplamları göstermek daha sade olabilir.
                // Şimdilik tabloyu bırakıyorum.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox( // Tablonun genişliğini sınırla
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    child: DataTable(
                      // Kompakt görünüm için
                      columnSpacing: 10,
                      horizontalMargin: 5,
                      headingRowHeight: 30,
                      dataRowHeight: 35,
                      columns: [
                        DataColumn(label: Text('Kodu', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Detay', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Adet', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Toplam', style: TextStyle(fontSize: 12))),
                      ],
                      rows: [
                        // Ürün satırları
                        ..._scannedProducts.map((product) {
                          return DataRow(cells: [
                            DataCell(Text(product['Kodu']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                            DataCell(Text(product['Detay']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                            DataCell(Text(product['Adet']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                            DataCell(Text(product['Toplam Fiyat']?.toString() ?? '', style: TextStyle(fontSize: 11))),
                          ]);
                        }).toList(),
                        // Toplam satırları
                        DataRow(cells: [
                          DataCell(Text('')),
                          DataCell(Text('Ara Toplam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataCell(Text('')),
                          DataCell(Text(_subtotal.toStringAsFixed(2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('')),
                          DataCell(Text('KDV (%${(kKdvOrani * 100).toInt()})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataCell(Text('')),
                          DataCell(Text(_vat.toStringAsFixed(2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('')),
                          DataCell(Text('Genel Toplam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataCell(Text('')),
                          DataCell(Text(_grandTotal.toStringAsFixed(2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop(false); // Onaylanmadı
              },
            ),
            ElevatedButton( // Onay butonu daha belirgin olabilir
              child: Text('Onayla ve Kaydet'),
              onPressed: () {
                // Gerekirse burada ek kontroller yapılabilir.
                Navigator.of(context).pop(true); // Onaylandı
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _processSale() async {
    // Bu fonksiyon, onay alındıktan sonra çağrılır.
    // Önceki koddaki mantık büyük ölçüde korunuyor.
    // Gerekli kontroller (müşteri, ürün) zaten _onProcessToAccountPressed içinde yapıldı.

    if (widget.documentId == null) {
      print("Hata: Satış işlenemedi, sepet ID'si yok.");
      return;
    }

    // 1. Gerekli verileri topla (kullanıcı adı, ürünler, toplamlar)
    final String processedBy = _currentUserFullName;
    final List<Map<String, dynamic>> productsToSave = List.from(_scannedProducts); // Kopyasını al
    final double finalGrandTotal = _grandTotal; // Toplamı al

    // Satışa katkıda bulunanları topla (gerekirse)
    final Set<String> salespersons = productsToSave.map<String>((p) => p['addedBy'] as String? ?? 'Bilinmeyen').toSet();

    try {
      // 2. Satış numarasını belirle (customerDetails'dan)
      var customerCollection = _firestore.collection(kCustomerDetailsCollection);
      var querySnapshot = await customerCollection.where('customerName', isEqualTo: _selectedCustomer).limit(1).get();

      int saleNumber = 1;
      DocumentReference? customerDocRef;

      if (querySnapshot.docs.isNotEmpty) {
        customerDocRef = querySnapshot.docs.first.reference;
        var customerData = querySnapshot.docs.first.data();
        saleNumber = (customerData['saleCount'] as int? ?? 0) + 1;
      }

      // 3. Ürün listesine satış numarasını ve diğer detayları ekle
      var processedProducts = productsToSave.map((product) {
        // Gerekirse burada ek alanlar eklenebilir (whoTook, recipient vb.)
        return {
          ...product, // Mevcut ürün verileri
          'saleNumber': saleNumber,
          'siparisTarihi': FieldValue.serverTimestamp(), // Sipariş zamanı
          'islemeAlan': processedBy, // İşleyen kişi
          // 'whoTook': 'Müşteri', // Bu bilgiler dialogdan alınabilir
          // 'recipient': 'Teslim Alan',
          // 'contactPerson': 'İlgili Kişi',
          // 'orderMethod': 'Telefon',
        };
      }).toList();

      // 4. customerDetails koleksiyonunu güncelle veya oluştur
      if (customerDocRef != null) {
        // Mevcut müşteriye ürünleri ekle ve sayacı artır
        await customerDocRef.update({
          'products': FieldValue.arrayUnion(processedProducts), // arrayUnion ile ekle
          'saleCount': saleNumber,
        });
      } else {
        // Yeni müşteri için kayıt oluştur
        await customerCollection.add({
          'customerName': _selectedCustomer,
          'products': processedProducts,
          'saleCount': saleNumber,
          'firstSaleDate': FieldValue.serverTimestamp(),
        });
      }

      // 5. sales koleksiyonuna satış kaydını ekle
      await _firestore.collection(kSalesCollection).add({
        'customerName': _selectedCustomer,
        'saleNumber': saleNumber,
        'amount': finalGrandTotal, // Genel Toplamı kaydet
        'date': FieldValue.serverTimestamp(), // Satış tarihi
        'processedBy': processedBy,
        'salespersons': salespersons.toList(), // Katkıda bulunanlar
        'products': processedProducts, // Satılan ürünlerin detaylı listesi
      });

      // 6. İşlem başarılıysa geçici sepeti sil
      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .delete();

      // 7. Başarı mesajı göster ve yönlendir
      if (mounted) {
        // Önce state'i temizle (opsiyonel, yönlendirme sonrası gerek kalmayabilir)
        // _clearScreenLocally();

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Satış Başarılı'),
            content: Text('Satış başarıyla kaydedildi. Ana sayfaya yönlendiriliyorsunuz.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Tamam'))],
          ),
        );

        // Ana ekrana yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CustomHeaderScreen()), // Hedef ekranı kontrol edin
        );
      }

    } catch (e) {
      print('Satış işlenirken hata oluştu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satış kaydedilemedi: $e')),
        );
        // Hata durumunda geçici sepet SİLİNMEZ, kullanıcı tekrar deneyebilir.
      }
    }
  }

  Future<void> _onGenerateQuotePressed() async {
    if (_selectedCustomer == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lütfen bir müşteri seçin.')));
      return;
    }
    if (_scannedProducts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Teklif için ürün bulunmuyor.')));
      return;
    }
    if (!await _checkConnectionAndNotify()) return;

    try {
      // Teklif numarasını oluştur
      String currentYear = DateFormat('yyyy').format(DateTime.now());
      String prefix = 'CSK$currentYear-'; // Ayraç eklendi
      var querySnapshot = await _firestore
          .collection(kQuotesCollection)
          .where('quoteNumber', isGreaterThanOrEqualTo: prefix)
          .where('quoteNumber', isLessThan: prefix + 'Z') // String karşılaştırması için
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
      await _firestore.collection(kQuotesCollection).add({
        'customerName': _selectedCustomer,
        'quoteNumber': quoteNumber,
        'products': _scannedProducts, // Mevcut sepet ürünleri
        'subtotal': _subtotal,
        'vat': _vat,
        'grandTotal': _grandTotal,
        'date': FieldValue.serverTimestamp(),
        'createdBy': _currentUserFullName,
        'status': 'pending', // Teklif durumu
      });

      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teklif ($quoteNumber) başarıyla oluşturuldu.')),
        );
      }

      // Geçici sepeti temizle ve ekranı sıfırla
      await _clearTemporarySelectionAndResetUI();

    } catch (e) {
      print('Teklif oluşturulurken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teklif oluşturulamadı: $e')),
        );
      }
    }
  }

  Future<void> _onCashPaymentPressed() async {
    if (_selectedCustomer == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lütfen bir müşteri seçin.')));
      return;
    }
    if (_scannedProducts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tahsilat için ürün bulunmuyor.')));
      return;
    }
    if (!await _checkConnectionAndNotify()) return;

    // Nakit tahsilat onayı (opsiyonel)
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nakit Tahsilat Onayı'),
        content: Text('$_selectedCustomer için ${_grandTotal.toStringAsFixed(2)} TL nakit tahsilat yapılacak. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Onayla')),
        ],
      ),
    ) ?? false;

    if (!confirm) return;


    try {
      // Nakit tahsilat işlemini kaydet
      await _firestore.collection(kCashPaymentsCollection).add({
        'customerName': _selectedCustomer,
        'amount': _grandTotal, // Genel toplamı kaydet
        'date': FieldValue.serverTimestamp(),
        'receivedBy': _currentUserFullName,
        'products': _scannedProducts, // Hangi ürünler için tahsilat yapıldığı bilgisi
        'documentIdRef': widget.documentId, // Hangi sepetten geldiği (opsiyonel)
      });

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nakit tahsilat başarıyla kaydedildi.')),
        );
      }

      // Geçici sepeti temizle ve ekranı sıfırla
      await _clearTemporarySelectionAndResetUI();

    } catch (e) {
      print('Nakit tahsilat hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nakit tahsilat kaydedilemedi: $e')),
        );
      }
    }
  }

  Future<void> _onSaveAsPDFPressed() async {
    if (_selectedCustomer == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF oluşturmak için müşteri seçin.')));
      return;
    }
    if (_scannedProducts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF oluşturmak için ürün ekleyin.')));
      return;
    }

    try {
      // PDF oluşturma fonksiyonunu çağır
      // Hatalı parametreler kaldırıldı.
      await PDFSalesTemplate.generateSalesPDF(
        _scannedProducts,
        _selectedCustomer!,
        false, // isQuote = false (veya duruma göre ayarla)
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF oluşturuldu ve kaydedildi.')));
      }
    } catch (e) {
      print("PDF oluşturma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF oluşturulamadı: $e')));
      }
    }
  }

  // --- Ekran Temizleme ve Sıfırlama ---
  Future<void> _clearTemporarySelectionAndResetUI() async {
    if (widget.documentId == null) return;

    try {
      // Firestore'daki geçici sepeti sil
      await _firestore
          .collection(kTemporarySelectionsCollection)
          .doc(widget.documentId)
          .delete();

      // Lokal state'i temizle (UI'ı sıfırlamak için)
      // _clearScreenLocally(); // Yönlendirme yapılmayacaksa gerekli

      print("Geçici sepet (${widget.documentId}) temizlendi.");

      // İsteğe bağlı: Başka bir ekrana yönlendir veya UI'ı sıfırla
      // Navigator.pushReplacement( ... );

    } catch (e) {
      print("Geçici sepet temizlenirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler temizlenirken hata oluştu: $e')),
        );
      }
    }
  }

  // Sadece lokal state'i temizler (Firestore'a dokunmaz)
  void _clearScreenLocally() {
    if (mounted) {
      setState(() {
        _selectedCustomer = null;
        _scannedProducts.clear();
        _subtotal = 0.0;
        _vat = 0.0;
        _grandTotal = 0.0;
        _isEditing = false;
        _editingIndex = -1;
        _searchController.clear();
        _filterCustomers(''); // Filtreyi temizle
      });
    }
  }

  // --- Yardımcı Fonksiyonlar ---
  void _showNoConnectionDialog(String title, String content) {
    // Eğer zaten bir dialog açıksa gösterme (opsiyonel)
    // if (ModalRoute.of(context)?.isCurrent ?? false) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  // --- Build Metodu ---
  @override
  Widget build(BuildContext context) {
    // Öneri: State management kütüphanesi (Provider, Riverpod) kullanarak
    // build metodunu daha sade hale getirin ve iş mantığını ayırın.
    return Scaffold(
      appBar: CustomAppBar(title: 'Ürün Tara / Sepet'), // Başlık güncellendi
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          // --- Üst Kontroller (Barkod, Müşteri Seçimi, Arama) ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Barkod Okutma Butonu
                IconButton(
                  icon: Icon(CupertinoIcons.barcode_viewfinder, size: 30, color: colorTheme5), // İkon güncellendi
                  tooltip: 'Barkod Tara',
                  onPressed: scanBarcode, // Bağlantı kontrolü içinde yapılıyor
                ),
                SizedBox(width: 10),
                // Müşteri Seçim Dropdown
                Expanded(
                  child: DropdownButtonHideUnderline( // Alt çizgiyi kaldır
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        hint: Text('MÜŞTERİ SEÇİN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        value: _selectedCustomer,
                        isExpanded: true, // Genişliği doldur
                        icon: Icon(Icons.arrow_drop_down, color: Colors.black54),
                        elevation: 16,
                        style: TextStyle(color: Colors.black, fontSize: 14),
                        onChanged: _onCustomerSelectedFromDropdown, // Bağlantı kontrolü içinde yapılıyor
                        items: _filteredCustomers.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Müşteri Arama
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCustomers,
              decoration: InputDecoration(
                hintText: 'Müşteri ara...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder( // Odaklanınca kenarlık
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorTheme5, width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12), // İç boşluk
                isDense: true, // Daha kompakt
                // Arama alanını temizleme butonu (opsiyonel)
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _filterCustomers('');
                  },
                )
                    : null,
              ),
            ),
          ),

          Divider(height: 20, thickness: 1),

          // --- Ürün Tablosu ---
          Expanded(
            // StreamBuilder yerine doğrudan _scannedProducts listesini kullanmak
            // state management ile daha iyi yönetilebilir. Şimdilik StreamBuilder kalıyor.
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection(kTemporarySelectionsCollection)
                  .doc(widget.documentId)
                  .snapshots(),
              builder: (context, snapshot) {
                // Yükleniyor durumu
                if (snapshot.connectionState == ConnectionState.waiting && _scannedProducts.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }
                // Hata durumu
                if (snapshot.hasError) {
                  print("StreamBuilder Hatası: ${snapshot.error}");
                  return Center(child: Text('Veri yüklenirken hata oluştu.', style: TextStyle(color: Colors.red)));
                }
                // Veri yok veya doküman yok durumu
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  // Eğer lokalde ürün varsa (henüz silinmediyse) onu gösterelim
                  if (_scannedProducts.isNotEmpty) {
                    // Bu durum, doküman silindikten sonra anlık olarak yaşanabilir.
                    // return _buildProductTable(); // Lokal veriyi göster
                  }
                  return Center(child: Text('Sepet boş veya bulunamadı.'));
                }

                // Veri geldi, state'i güncelle (Stream listener zaten yapıyor ama burada da yapılabilir)
                // var customerData = snapshot.data!.data() as Map<String, dynamic>?;
                // _selectedCustomer = customerData?['customerName'];
                // _scannedProducts = List<Map<String, dynamic>>.from(customerData?['products'] ?? []);
                // _subtotal = (customerData?['subtotal'] as num?)?.toDouble() ?? 0.0;
                // _vat = (customerData?['vat'] as num?)?.toDouble() ?? 0.0;
                // _grandTotal = (customerData?['grandTotal'] as num?)?.toDouble() ?? 0.0;

                // Ürün tablosunu oluştur
                return _buildProductTable();
              },
            ),
          ),

          // --- Alt Butonlar ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: Wrap( // Ekran küçülünce alt alta gelmesi için Wrap
              spacing: 8.0, // Yatay boşluk
              runSpacing: 8.0, // Dikey boşluk
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.request_quote_outlined, size: 18),
                  label: Text('Teklif Ver'),
                  onPressed: _onGenerateQuotePressed,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: Text('Hesaba İşle'),
                  onPressed: _onProcessToAccountPressed,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.payments_outlined, size: 18),
                  label: Text('Nakit Tahsilat'),
                  onPressed: _onCashPaymentPressed,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text('PDF Oluştur'),
                  onPressed: _onSaveAsPDFPressed,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ],
            ),
          ),
        ],
      ),

      // --- Alt Navigasyon ve Bilgi Çubuğu ---
      bottomNavigationBar: Column( // BottomBar ve BottomSheet'i birleştirmek için
        mainAxisSize: MainAxisSize.min,
        children: [
          // Döviz Kuru ve Tarih Bilgisi
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 USD: $_dolarKur', style: TextStyle(fontSize: 11, color: Colors.black87)),
                Text(_currentDateFormatted, style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
                Text('1 EUR: $_euroKur', style: TextStyle(fontSize: 11, color: Colors.black87)),
              ],
            ),
          ),
          // Alt Navigasyon Barı
          CustomBottomBar(),
        ],
      ),
    );
  }

  // Ürün tablosunu oluşturan yardımcı fonksiyon
  Widget _buildProductTable() {
    if (_scannedProducts.isEmpty) {
      return Center(child: Text('Sepete ürün eklemek için barkod okutun.'));
    }
    return SingleChildScrollView( // Dikey kaydırma
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 10), // Alt boşluk
      child: SingleChildScrollView( // Yatay kaydırma
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox( // Minimum genişlik sağla
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            columnSpacing: 15.0, // Sütun aralığı
            horizontalMargin: 10.0, // Kenar boşlukları
            headingRowHeight: 35.0, // Başlık satırı yüksekliği
            dataRowHeight: 45.0, // Veri satırı yüksekliği
            headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
            dataTextStyle: TextStyle(fontSize: 12, color: Colors.black),
            columns: const [
              DataColumn(label: Text('Kodu')),
              DataColumn(label: Text('Detay')),
              DataColumn(label: Text('Adet')),
              DataColumn(label: Text('Birim Fiyat (TL)')), // Adet Fiyatı -> Birim Fiyat
              DataColumn(label: Text('İskonto')),
              DataColumn(label: Text('Toplam (TL)')), // Toplam Fiyat -> Toplam
              DataColumn(label: Text('İşlem')), // Düzenle -> İşlem
            ],
            rows: [
              // Ürün satırları
              ..._scannedProducts.asMap().entries.map((entry) { // index'i almak için asMap kullan
                int index = entry.key;
                Map<String, dynamic> product = entry.value;
                bool isCurrentlyEditing = _isEditing && _editingIndex == index;

                return DataRow(
                  color: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                      // Düzenlenen satırı vurgula (opsiyonel)
                      if (isCurrentlyEditing) return Colors.yellow.withOpacity(0.15);
                      return index.isEven ? Colors.grey.withOpacity(0.05) : null; // Zebra deseni
                    },
                  ),
                  cells: [
                    DataCell(Text(product['Kodu']?.toString() ?? '')),
                    DataCell(SizedBox(width: 150, child: Text(product['Detay']?.toString() ?? '', overflow: TextOverflow.ellipsis))), // Genişlik ve taşma kontrolü
                    // Adet hücresi (Düzenleme modu)
                    DataCell(
                      isCurrentlyEditing
                          ? SizedBox( // TextField boyutunu ayarla
                        width: 50,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            isDense: true,
                          ),
                          autofocus: true,
                          onSubmitted: (_) => _handleEditSubmit(index), // Enter ile kaydet
                        ),
                      )
                          : Text(product['Adet']?.toString() ?? '1'), // Normal görünüm
                      showEditIcon: !isCurrentlyEditing && _isConnected, // Bağlıyken düzenleme ikonu göster
                      onTap: !isCurrentlyEditing && _isConnected ? () => _startEditing(index) : null, // Tıklayınca düzenlemeyi başlat
                    ),
                    DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                    DataCell(Text(product['İskonto']?.toString() ?? '')),
                    DataCell(Text(product['Toplam Fiyat']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w500))),
                    // İşlem hücresi (Düzenleme butonları veya Sil butonu)
                    DataCell(
                      isCurrentlyEditing
                          ? Row( // Düzenleme modunda Onay/İptal butonları
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check_circle, color: Colors.green, size: 20),
                            tooltip: 'Kaydet',
                            onPressed: () => _handleEditSubmit(index),
                            padding: EdgeInsets.zero, constraints: BoxConstraints(), // Buton boşluklarını azalt
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel, color: Colors.red, size: 20),
                            tooltip: 'İptal',
                            onPressed: () => _handleEditCancel(index),
                            padding: EdgeInsets.zero, constraints: BoxConstraints(),
                          ),
                        ],
                      )
                          : IconButton( // Normal modda Sil butonu
                        icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Ürünü Kaldır',
                        onPressed: () => _removeProduct(index), // Bağlantı kontrolü içinde yapılıyor
                        padding: EdgeInsets.zero, constraints: BoxConstraints(),
                      ),
                    ),
                  ],
                );
              }).toList(), // map sonrası toList() unutulmamalı

              // --- Toplam Satırları ---
              _buildTotalRow('Ara Toplam', _subtotal),
              _buildTotalRow('KDV (%${(kKdvOrani * 100).toInt()})', _vat),
              _buildTotalRow('Genel Toplam', _grandTotal, isGrandTotal: true),
            ],
          ),
        ),
      ),
    );
  }

  // Toplam satırlarını oluşturan yardımcı fonksiyon
  DataRow _buildTotalRow(String label, double value, {bool isGrandTotal = false}) {
    final style = TextStyle(
      fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
      fontSize: isGrandTotal ? 13 : 12,
      color: isGrandTotal ? colorTheme5 : Colors.black87,
    );
    return DataRow(
      cells: [
        DataCell(Text('')), // Boş hücreler
        DataCell(Text('')),
        DataCell(Text('')),
        DataCell(Text('')),
        DataCell(Text(label, style: style, textAlign: TextAlign.right)), // Sağa yaslı etiket
        DataCell(Text(value.toStringAsFixed(2), style: style)), // Değer
        DataCell(Text('')), // Boş işlem hücresi
      ],
    );
  }
}

