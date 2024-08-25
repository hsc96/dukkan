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
  double grandTotal = 0.0;
  String currentDate = DateFormat('d MMMM y', 'tr_TR').format(
      DateTime.now()); // Tarih formatı ayarlandı.
  final CustomerSelectionService _customerSelectionService = CustomerSelectionService();
  ScrollController _scrollController = ScrollController();

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
    _scrollController = ScrollController();
    fetchCustomers();           // Mevcut müşterileri çek
    initializeDovizKur();       // Döviz kurlarını başlat
    fetchCurrentUser();         // Mevcut kullanıcıyı çek

    // Firestore Stream dinleyici ekleyin
    FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc(widget.documentId) // Use the documentId passed to the widget
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null && mounted) {
          setState(() {
            selectedCustomer = data['customerName'];  // Seçili müşteri bilgilerini güncelle
            scannedProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);  // Ürünleri güncelle
            updateTotalAndVat();  // Toplam ve KDV hesaplamalarını güncelle
          });
        }
      }
    });
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
    await _selectCustomer(customerName);  // Müşteriyi seç ve ilgili bilgileri yükle
    await updateDiscountAndBrandForCustomer();  // İskonto ve marka bilgilerini güncelle

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

  Future<void> processSale() async {
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
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(
          currentUser.uid).get();
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

    var customerCollection = FirebaseFirestore.instance.collection(
        'customerDetails');
    var querySnapshot = await customerCollection.where(
        'customerName', isEqualTo: selectedCustomer).get();

    var processedProducts = scannedProducts.map((product) {
      double unitPrice = double.tryParse(
          product['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      int quantity = int.tryParse(product['Adet']?.toString() ?? '1') ?? 1;
      double totalPrice = unitPrice * quantity;

      return {
        'Kodu': product['Kodu'],
        'Detay': product['Detay'],
        'Adet': quantity.toString(),
        'Adet Fiyatı': unitPrice.toStringAsFixed(2),
        'Toplam Fiyat': totalPrice.toStringAsFixed(2),
        'İskonto': product['İskonto'],
        'whoTook': 'Müşteri',
        'recipient': 'Teslim Alan',
        'contactPerson': 'İlgili Kişi',
        'orderMethod': 'Telefon',
        'siparisTarihi': DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(
            DateTime.now()),
        'islemeAlan': fullName ?? 'Unknown',
      };
    }).toList();

    try {
      if (querySnapshot.docs.isNotEmpty) {
        var docRef = querySnapshot.docs.first.reference;
        var existingProducts = List<Map<String, dynamic>>.from(
            querySnapshot.docs.first['products'] ?? []);
        existingProducts.addAll(processedProducts);
        await docRef.update({'products': existingProducts});
      } else {
        await customerCollection.add({
          'customerName': selectedCustomer,
          'products': processedProducts,
        });
      }

      await FirebaseFirestore.instance.collection('sales').add({
        'userId': currentUser!.uid,
        'date': DateFormat('dd.MM.yyyy').format(DateTime.now()),
        'customerName': selectedCustomer,
        'amount': toplamTutar,
        'products': processedProducts,
      });

      // Clear selections and reset UI only if the widget is still mounted
      if (mounted) {
        await _customerSelectionService.clearTemporaryData();
        setState(() {
          clearScreen(); // This clears the data from the UI
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ürünler başarıyla kaydedildi')),
            );
          }
        });
      }
    } catch (e) {
      print('Hata oluştu: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Veri işlenirken hata oluştu')),
            );
          }
        });
      }
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
  Future<void> addProductToCurrentCustomer(Map<String, dynamic> productData) async {
    if (widget.documentId != null) {
      DocumentReference<Map<String, dynamic>> currentDocRef = FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc(widget.documentId);

      DocumentSnapshot<Map<String, dynamic>> snapshot = await currentDocRef.get();

      if (snapshot.exists) {
        List<dynamic> existingProducts = snapshot.data()?['products'] ?? [];

        // Ürün fiyatını 'urunler' koleksiyonundan çek
        Map<String, dynamic> productDetails = await firestoreService.fetchProductDetails(productData['Kodu']);
        double price = double.tryParse(productDetails['Fiyat']?.toString() ?? '') ?? 0.0;


        // Eğer fiyat 0.0 ise uyarı ver ve işleme almayı durdur
        if (price == 0.0) {
          print("Warning: Price is 0.0 for product code ${productData['Kodu']}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ürün fiyatı eksik veya hatalı! Ürün kodu: ${productData['Kodu']}')),
          );
          return; // Fiyat 0.0 ise işleme devam etmiyoruz
        }

        // Döviz çevirisini yap
        double priceInTl = price;
        String currency = productDetails['Doviz']?.toString() ?? '';

        if (currency == 'Euro') {
          priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
        } else if (currency == 'Dolar') {
          priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
        } else {
          priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
        }

        // İskonto uygulanması
        double discountedPrice = priceInTl;
        double discountRate = 0.0;

        if (selectedCustomer != null) {
          var customerDiscount = await firestoreService.getCustomerDiscount(selectedCustomer!);

          // İskonto seviyesi alma
          String discountLevel = customerDiscount['iskonto'] ?? '';
          print("İskonto seviyesi: $discountLevel");

          if (discountLevel.isNotEmpty) {
            // İlgili marka için iskonto oranını al
            var discountData = await firestoreService.getDiscountRates(discountLevel, productDetails['Marka']?.toString() ?? '');
            discountRate = double.tryParse(discountData['rate']?.toString() ?? '0.0') ?? 0.0;
            discountedPrice = priceInTl * (1 - (discountRate / 100));
          }
        }

        print('Seçilen müşteri: $selectedCustomer');
        print('Uygulanan iskonto oranı: $discountRate');

        // Ürün bilgilerini güncelle
        existingProducts.add({
          'Kodu': productDetails['Kodu'],
          'Detay': productDetails['Detay'],
          'Adet': '1',
          'Adet Fiyatı': discountedPrice.toStringAsFixed(2), // İskonto uygulanmış fiyat
          'Toplam Fiyat': discountedPrice.toStringAsFixed(2),
          'İskonto': discountRate > 0 ? '%$discountRate' : '0%', // İskonto bilgisi
        });

        await currentDocRef.update({'products': existingProducts});
      }
    }
  }



  Future<void> updateProductPricesForCustomer() async {
    if (selectedCustomer == null) return;

    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = scannedProducts[i];

      // Ürünün fiyatını ve diğer bilgileri "urunler" koleksiyonundan çek
      var productDetails = await firestoreService.fetchProductDetails(productData['Kodu']);
      double price = double.tryParse(productDetails['Fiyat']?.toString() ?? '0') ?? 0.0;  // Fiyatı buradan alıyoruz

      if (price == 0.0) {
        print("Warning: Price is 0.0 for product code ${productData['Kodu']}");
        continue;  // Eğer fiyat 0.0 ise işleme devam etmiyoruz
      }

      // İskonto oranını ve fiyatı güncelle
      await applyDiscountToProduct(productData);  // Bu doğru

      double adet = double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1;

      setState(() {
        scannedProducts[i]['Adet Fiyatı'] = productData['Adet Fiyatı'];
        scannedProducts[i]['Toplam Fiyat'] = (adet * (double.tryParse(productData['Adet Fiyatı'] ?? '0') ?? 0)).toStringAsFixed(2);
        scannedProducts[i]['İskonto'] = productData['İskonto'];
      });
    }

    // Güncellenmiş ürünleri Firestore'da güncelleyin
    await FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
      'products': scannedProducts,
    });

    updateTotalAndVat(); // Toplam ve KDV güncellemesi
  }






  void printProductPrices() {
    if (scannedProducts.isNotEmpty) {
      print("Müşteri değiştirildi, mevcut ürünlerin fiyatları:");
      for (var product in scannedProducts) {
        print("Ürün Kodu: ${product['Kodu']}, Adet Fiyatı: ${product['Adet Fiyatı']}, Toplam Fiyat: ${product['Toplam Fiyat']}");
      }
    } else {
      print("Tabloda ürün bulunmuyor.");
    }
  }


  Future<void> updateDiscountAndBrandForCustomer() async {
    if (selectedCustomer == null) return;

    // Müşterinin iskonto bilgilerini al
    var customerDiscount = await firestoreService.getCustomerDiscount(selectedCustomer!);
    String discountLevel = customerDiscount['iskonto'] ?? '';

    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = scannedProducts[i];

      // Her ürün için fiyatı urunler koleksiyonundan tekrar çek
      var productDetails = await firestoreService.fetchProductDetails(productData['Kodu']);
      String brand = productDetails['Marka'] ?? '';
      double price = double.tryParse(productDetails['Fiyat']?.toString() ?? '0.0') ?? 0.0;
      double discountRate = 0.0;

      // Döviz dönüşümünü uygula
      String currency = productDetails['Doviz']?.toString() ?? '';
      double priceInTl = price;

      if (currency == 'Euro') {
        priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
      } else if (currency == 'Dolar') {
        priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
      } else {
        priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
      }

      if (discountLevel.isNotEmpty) {
        var discountData = await firestoreService.getDiscountRates(discountLevel, brand);
        discountRate = double.tryParse(discountData['rate']?.toString() ?? '0.0') ?? 0.0;
      }

      // Hesaplamalar
      double discountedPrice = priceInTl * (1 - (discountRate / 100));
      double adet = double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1;

      // Ürün bilgilerini güncelle
      scannedProducts[i]['Marka'] = brand;
      scannedProducts[i]['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
      scannedProducts[i]['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
      scannedProducts[i]['Toplam Fiyat'] = (adet * discountedPrice).toStringAsFixed(2);
    }

    // Güncellenmiş ürünleri Firestore'daki temporarySelections koleksiyonunda güncelle
    await FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
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

      if (uniqueProducts.length > 1) {
        showProductSelectionDialog(uniqueProducts);
      } else {
        await addProductToCurrentCustomer(uniqueProducts.first);
      }
    } else {
      print("Hata: Ürün verisi bulunamadı.");
    }
  }
  Future<void> applyDiscountToProduct(Map<String, dynamic> productData) async {
    double basePrice = double.tryParse(productData['Fiyat']?.toString() ?? '0') ?? 0.0;
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
    double discountRate = await getDiscountRateForCustomer(productData['Marka']);
    double discountedPrice = priceInTl * (1 - (discountRate / 100));

    print("İskonto Oranı: $discountRate%, İskonto Uygulanmış Fiyat: $discountedPrice TL");

    // Adet ve Toplam Fiyat Hesaplama
    double quantity = double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1.0;
    double totalPrice = discountedPrice * quantity;

    // Ürün Verilerini Güncelleme
    productData['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
    productData['Toplam Fiyat'] = totalPrice.toStringAsFixed(2);
    productData['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
    productData['Fiyat TL'] = priceInTl.toStringAsFixed(2); // Gerekirse ileride kullanmak için
  }





  Future<double> getDiscountRateForCustomer(String brand) async {
    if (selectedCustomer == null) return 0.0;

    var customerDiscount = await firestoreService.getCustomerDiscount(selectedCustomer!);
    String discountLevel = customerDiscount['iskonto'] ?? '';

    if (discountLevel.isEmpty) return 0.0;

    var discountData = await firestoreService.getDiscountRates(discountLevel, brand);
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
                    await addProductToTable(products[index]); // Seçilen ürünü tabloya ekle
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
    var productDetails = await firestoreService.fetchProductDetails(productData['Kodu']);

    double priceInTl = 0.0;
    double price = double.tryParse(productDetails['Fiyat']?.toString() ?? '0') ?? 0.0;
    String currency = productDetails['Doviz']?.toString() ?? '';

    // Döviz kuruna göre fiyatı TL'ye çevir
    if (currency == 'Euro') {
      priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
    } else {
      priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
    }

    productData['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);

    // Müşteri seçilmişse iskonto uygula
    if (selectedCustomer != null) {
      await applyDiscountToProduct(productData);  // Bu doğru
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
      if (product['Kodu']?.toString()?.isEmpty ?? true) continue;

      // Veritabanından ürün detaylarını çek
      var productDetails = await firestoreService.fetchProductDetails(product['Kodu']);
      if (productDetails == null) continue;

      // Ürün verilerini güncelle
      product['Fiyat'] = productDetails['Fiyat'];
      product['Doviz'] = productDetails['Doviz'];
      product['Marka'] = productDetails['Marka'];

      // Fiyat hesaplamasını yap
      await applyDiscountToProduct(product);
    }

    // Firestore'da güncelle
    await FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
      'products': scannedProducts,
    });

    // Toplamları güncelle
    updateTotalAndVat();
  }




















  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(scannedProducts[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      scannedProducts[index]['Adet'] = quantity;
      scannedProducts[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);

      // Güncellenmiş veriyi Firestore'a yazdır
      FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
        'products': scannedProducts,
      });
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
      if (product['Kodu']?.toString()?.isEmpty ?? true) continue;

      double productTotal = double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      subtotal += productTotal;

      print("Ürün Kodu: ${product['Kodu']}, Ürün Toplam Fiyatı: $productTotal TL");
    }

    vat = subtotal * 0.20;
    grandTotal = subtotal + vat;

    print("Ara Toplam: $subtotal TL, KDV: $vat TL, Genel Toplam: $grandTotal TL");

    setState(() {
      // Mevcut scannedProducts listesinde toplam bilgilerini kaldır
      scannedProducts.removeWhere((product) =>
      product['Adet Fiyatı'] == 'Toplam Tutar' ||
          product['Adet Fiyatı'] == 'KDV %20' ||
          product['Adet Fiyatı'] == 'Genel Toplam'
      );

      // Yeni toplamları ekle
      scannedProducts.addAll([
        {
          'Kodu': '',
          'Detay': '',
          'Adet': '',
          'Adet Fiyatı': 'Toplam Tutar',
          'Toplam Fiyat': subtotal.toStringAsFixed(2),
        },
        {
          'Kodu': '',
          'Detay': '',
          'Adet': '',
          'Adet Fiyatı': 'KDV %20',
          'Toplam Fiyat': vat.toStringAsFixed(2),
        },
        {
          'Kodu': '',
          'Detay': '',
          'Adet': '',
          'Adet Fiyatı': 'Genel Toplam',
          'Toplam Fiyat': grandTotal.toStringAsFixed(2),
        },
      ]);
    });

    // Firestore güncellemesi
    updateTotalInFirestore(subtotal, vat, grandTotal);
  }







  void updateTotalInFirestore(double subtotal, double vat, double grandTotal) async {
    await FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
      'subtotal': subtotal,
      'vat': vat,
      'grandTotal': grandTotal,
    });
  }



  Future<void> saveToCustomerDetails(String whoTook, String? recipient,
      String? contactPerson, String orderMethod) async {
    if (selectedCustomer == null) return;

    User? currentUser = FirebaseAuth.instance.currentUser;

    String? fullName;

    // Mevcut kullanıcının tam adını veritabanından çekiyoruz
    if (currentUser != null) {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(
          currentUser.uid).get();
      if (userDoc.exists) {
        fullName = userDoc.data()?['fullName'];
      }
    }

    var customerCollection = FirebaseFirestore.instance.collection(
        'customerDetails');
    var querySnapshot = await customerCollection.where(
        'customerName', isEqualTo: selectedCustomer).get();

    var processedProducts = scannedProducts.map((product) {
      double unitPrice = double.tryParse(
          product['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      int quantity = int.tryParse(product['Adet']?.toString() ?? '1') ?? 1;
      double totalPrice = unitPrice * quantity;

      return {
        'Kodu': product['Kodu'],
        'Detay': product['Detay'],
        'Adet': quantity.toString(),
        'Adet Fiyatı': unitPrice.toStringAsFixed(2),
        'Toplam Fiyat': totalPrice.toStringAsFixed(2),
        'İskonto': product['İskonto'],
        'whoTook': 'Müşteri',
        'recipient': 'Teslim Alan',
        'contactPerson': 'İlgili Kişi',
        'orderMethod': 'Telefon',
        'siparisTarihi': DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(
            DateTime.now()),
        'islemeAlan': fullName ?? 'Unknown',
      };
    }).toList();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      var existingProducts = List<Map<String, dynamic>>.from(
          querySnapshot.docs.first['products'] ?? []);

      // Mevcut ürünleri güncelleyerek veya yeni ürünleri ekleyerek
      for (var product in processedProducts) {
        existingProducts.add(product);
      }

      await docRef.update({
        'products': existingProducts,
      });
    } else {
      await customerCollection.add({
        'customerName': selectedCustomer,
        'products': processedProducts,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ürünler başarıyla kaydedildi')),
    );

    // TemporarySelections içindeki verileri temizle
    await _customerSelectionService.clearTemporaryData();

    // ScanScreen'i sıfırla
    setState(() {
      selectedCustomer = null;
      scannedProducts.clear();
      originalProducts.clear();
      toplamTutar = 0.0;
      kdv = 0.0;
      genelToplam = 0.0;
    });

    // Firestore'daki current document'ı güncelle
    FirebaseFirestore.instance.collection('selectedCustomer')
        .doc('current')
        .set({
      'customerName': '',
      'totalAmount': '0.00',
    });

    // Müşteri detayları ekranına yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanScreen(
          onCustomerProcessed: (data) {},
          documentId: 'your_document_id_here', // Pass the correct document ID here
        ),
      ),

    );
  }

  Future<bool> showProcessingDialog() async {
    String? whoTook;
    String? recipient;
    String? contactPerson;
    String? orderMethod;
    TextEditingController recipientController = TextEditingController();
    TextEditingController contactPersonController = TextEditingController();
    TextEditingController otherMethodController = TextEditingController();

    bool isSaved = false; // Save status

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Sipariş Bilgileri'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Ürünü Kim Aldı:'),
                    RadioListTile<String>(
                      title: Text('Müşterisi'),
                      value: 'Müşterisi',
                      groupValue: whoTook,
                      onChanged: (value) {
                        setState(() {
                          whoTook = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Kendi Firması'),
                      value: 'Kendi Firması',
                      groupValue: whoTook,
                      onChanged: (value) {
                        setState(() {
                          whoTook = value;
                        });
                      },
                    ),
                    if (whoTook == 'Müşterisi')
                      Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                                labelText: 'Müşteri İsmi'),
                            controller: recipientController,
                          ),
                          TextField(
                            decoration: InputDecoration(
                                labelText: 'Firmadan Bilgilendirilecek Kişi İsmi'),
                            controller: contactPersonController,
                          ),
                        ],
                      ),
                    if (whoTook == 'Kendi Firması')
                      TextField(
                        decoration: InputDecoration(
                            labelText: 'Teslim Alan Çalışan İsmi'),
                        controller: recipientController,
                      ),
                    SizedBox(height: 20),
                    Text('Sipariş Şekli:'),
                    RadioListTile<String>(
                      title: Text('Mail'),
                      value: 'Mail',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Whatsapp'),
                      value: 'Whatsapp',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Telefon'),
                      value: 'Telefon',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Dükkanda Sipariş'),
                      value: 'Dükkanda Sipariş',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Diğer'),
                      value: 'Diğer',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    if (orderMethod == 'Diğer')
                      TextField(
                        controller: otherMethodController,
                        decoration: InputDecoration(
                            labelText: 'Sipariş Şekli (Diğer)'),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('İptal'),
                  onPressed: () {
                    isSaved = false; // İptal edildi
                    Navigator.of(context)
                        .pop(); // Sadece ekranı kapatır, başka hiçbir işlem yapmaz
                  },
                ),
                TextButton(
                  child: Text('Kaydet'),
                  onPressed: () {
                    if (whoTook != null &&
                        recipientController.text.isNotEmpty &&
                        contactPersonController.text.isNotEmpty &&
                        orderMethod != null &&
                        (orderMethod != 'Diğer' ||
                            otherMethodController.text.isNotEmpty)) {
                      // Kaydetme işlemini burada yapıyoruz
                      saveToCustomerDetails(
                        whoTook!,
                        recipientController.text,
                        contactPersonController.text,
                        orderMethod == 'Diğer'
                            ? otherMethodController.text
                            : orderMethod!,
                      );
                      isSaved = true; // Kaydedildi
                      Navigator.of(context).pop(); // Ekranı kapatır
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    return isSaved; // Dialog sonucu döndürülüyor
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
    DocumentReference docRef = await FirebaseFirestore.instance.collection('quotes').add({
      'customerName': selectedCustomer,
      'quoteNumber': quoteNumber,
      'products': scannedProducts,
      'date': DateTime.now(),
    });

    return docRef;  // Teklif kaydedilen DocumentReference'ı döndür
  }




  void handleEditSubmit(int index) {
    setState(() {
      isEditing = false;
      editingIndex = -1;

      // Güncellenen ürün bilgisini Firestore'a kaydet
      FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
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

        print("Seçilen müşteri: $customerName, İskonto seviyesi: $iskontoLevel");
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

  void _clearScreen() {
    setState(() {
      scannedProducts.clear();
      selectedCustomer = null;
      _customerSelectionService.clearTemporaryData();
    });
  }


  void handleProcessCompletion() async {
    if (selectedCustomer != null) {
      await FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc('current')
          .set({
        'products': [],
      }, SetOptions(merge: true));

      // Ekranı temizle
      _clearScreen();
    }
  }

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


  Future<void> clearSelections() async {
    try {
      // Firestore'daki temporarySelections koleksiyonunda current alanını temizle
      await FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc('current')
          .delete();

      // Seçimleri yerel olarak temizle
      setState(() {
        selectedCustomer = null;
        scannedProducts.clear();
        originalProducts.clear();
        toplamTutar = 0.0;
        kdv = 0.0;
        genelToplam = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seçimler temizlendi')),
      );
    } catch (e) {
      print('Veri temizlenirken hata oluştu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veri temizlenirken hata oluştu')),
      );
    }
  }
  void clearScreen() {
    // Belirli bir customerName ile eşleşen documentId'yi bulmak için sorgu
    FirebaseFirestore.instance
        .collection('temporarySelections')
        .where('customerName', isEqualTo: selectedCustomer)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        // Belge mevcutsa, documentId'yi al
        String targetDocumentId = querySnapshot.docs.first.id;

        // Belgeyi silme işlemi
        FirebaseFirestore.instance
            .collection('temporarySelections')
            .doc(targetDocumentId)
            .delete()
            .then((_) {
          print("Firestore '$targetDocumentId' verisi başarıyla silindi");

          // Firestore'daki current verisi silindikten sonra diğer verileri güncelle
          if (widget.documentId != null) {
            FirebaseFirestore.instance
                .collection('temporarySelections')
                .doc(widget.documentId)
                .update({
              'customerName': '',
              'products': [],
              'subtotal': 0.0,
              'vat': 0.0,
              'grandTotal': 0.0,
            }).then((_) async {
              print("Firestore temporarySelections güncellendi");

              // UI'ı temizle ve kullanıcıyı CustomHeaderScreen'e yönlendir
              setState(() {
                selectedCustomer = null;
                scannedProducts.clear();
                originalProducts.clear();
                toplamTutar = 0.0;
                kdv = 0.0;
                genelToplam = 0.0;
              });

              // Yönlendirme işlemi
              await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Teklif Oluşturuldu'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Teklif başarıyla oluşturuldu.'),
                        SizedBox(height: 8),
                        Text('Müşteri detayları veya teklifler sayfasına ulaşabilirsiniz.'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();  // Dialog'u kapat
                        },
                        child: Text('Tamam'),
                      ),
                    ],
                  );
                },
              );

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CustomHeaderScreen()),
              );
            }).catchError((error) {
              print('Firestore güncellenirken hata oluştu: $error');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Firestore güncellenirken hata oluştu: $error')),
              );
            });
          } else {
            print("Hata: documentId null");
          }
        }).catchError((error) {
          print('Belge silinirken hata oluştu: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Belge silinirken hata oluştu: $error')),
          );
        });
      } else {
        print("Hata: Belirtilen customerName ile eşleşen belge bulunamadı.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belirtilen müşteri için belge bulunamadı.')),
        );
      }
    }).catchError((error) {
      print('Sorgu yapılırken hata oluştu: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sorgu yapılırken hata oluştu: $error')),
      );
    });
  }














  Future<void> updateDiscountsForAllProducts() async {
    if (selectedCustomer == null) return;

    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = scannedProducts[i];

      // Ürünün fiyatını ve diğer bilgileri "urunler" koleksiyonundan çek
      var productDetails = await firestoreService.fetchProductDetails(productData['Kodu']);

      if (productDetails == null || productDetails.isEmpty) {
        print("Product details not found for code: ${productData['Kodu']}");
        continue;
      }

      double price = double.tryParse(productDetails['Fiyat']?.toString() ?? '0') ?? 0.0;  // Fiyatı buradan alıyoruz

      if (price == 0.0) {
        print("Warning: Price is 0.0 for product code ${productData['Kodu']}");
        continue;  // Eğer fiyat 0.0 ise işleme devam etmiyoruz
      }

      // İskonto oranını ve fiyatı güncelle
      await applyDiscountToProduct(productData);  // Bu doğru

      double adet = double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1;

      setState(() {
        scannedProducts[i]['Adet Fiyatı'] = productData['Adet Fiyatı'];
        scannedProducts[i]['Toplam Fiyat'] = (adet * (double.tryParse(productData['Adet Fiyatı'] ?? '0') ?? 0)).toStringAsFixed(2);
        scannedProducts[i]['İskonto'] = productData['İskonto'];
      });
    }

    // Güncellenmiş ürünleri Firestore'da güncelleyin
    await FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).update({
      'products': scannedProducts,
    });

    updateTotalAndVat(); // Toplam ve KDV güncellemesi
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
              Row(
                children: [
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
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        await _selectCustomer(newValue);
                        await updateDiscountAndBrandForCustomer();
                        setState(() {});
                      }
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
            ],
          ),


          SizedBox(height: 10),
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
          Expanded( // Expanded widget'ı burada kullanılıyor
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('temporarySelections').doc(widget.documentId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text('No data found.'));
                }

                var customerData = snapshot.data!.data() as Map<String, dynamic>?;
                if (customerData != null) {
                  selectedCustomer = customerData['customerName'];
                  scannedProducts = List<Map<String, dynamic>>.from(customerData['products'] ?? []);
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
                            ...scannedProducts.map((product) {
                              int index = scannedProducts.indexOf(product);
                              bool isTotalRow = product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
                                  product['Adet Fiyatı']?.toString() == 'KDV %20' ||
                                  product['Adet Fiyatı']?.toString() == 'Genel Toplam';

                              return DataRow(cells: [
                                DataCell(Text(product['Kodu']?.toString() ?? '')),
                                DataCell(Text(product['Detay']?.toString() ?? '')),
                                DataCell(
                                  TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      scannedProducts[index]['Adet'] = value;
                                    },
                                    onSubmitted: (value) {
                                      updateQuantity(index, value);
                                    },
                                    controller: TextEditingController(
                                        text: scannedProducts[index]['Adet']?.toString() ?? ''
                                    ),
                                  ),
                                ),
                                DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                                DataCell(Text(product['İskonto']?.toString() ?? '')),
                                DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                                DataCell(
                                  isTotalRow
                                      ? Container()
                                      : Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.grey),
                                        onPressed: () {
                                          setState(() {
                                            isEditing = true;
                                            editingIndex = index;
                                            originalProductData = Map<String, dynamic>.from(product);
                                            quantityController.text = product['Adet']?.toString() ?? '';
                                          });
                                        },
                                      ),
                                      if (isEditing && editingIndex == index)
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.check, color: Colors.green),
                                              onPressed: () {
                                                handleEditSubmit(index);
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => removeProduct(index),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close, color: Colors.red),
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
                            // Toplam bilgilerini tabloya ekleyin
                            DataRow(cells: [
                              DataCell(Text('')),
                              DataCell(Text('Toplam Tutar')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text(subtotal.toStringAsFixed(2))),
                              DataCell(Text('')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('')),
                              DataCell(Text('KDV %20')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text(vat.toStringAsFixed(2))),
                              DataCell(Text('')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('')),
                              DataCell(Text('Genel Toplam')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text(grandTotal.toStringAsFixed(2))),
                              DataCell(Text('')),
                            ]),

                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                bool shouldProceed = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Teklif Oluştur'),
                                      content: Text('Teklif oluşturmak istediğinizden emin misiniz?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(false);  // İşlemi iptal et
                                          },
                                          child: Text('Hayır'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(true);  // İşleme devam et
                                          },
                                          child: Text('Evet'),
                                        ),
                                      ],
                                    );
                                  },
                                );

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

                                      // Bilgi mesajını sayfa tamamen yenilendikten sonra göster
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
                                                  Navigator.of(context).pop();  // Dialog'u kapat
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
                            )












                            ,SizedBox(height: 100),
                            ElevatedButton(
                              onPressed: () async {
                                bool shouldProceed = await showProcessingDialog();

                                if (shouldProceed) {
                                  await processSale();
                                  await clearSelections();
                                  clearScreen(); // Ekranı temizle
                                } else {
                                  print('İşlem iptal edildi, veriler silinmedi.');
                                }
                              },
                              child: Text('Hesaba İşle'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await processCashPayment();
                                await clearSelections();
                                clearScreen(); // Ekranı temizle
                              },
                              child: Text('Nakit Tahsilat'),
                            ),
                            ElevatedButton(
                              onPressed: saveAsPDF,
                              child: Text('PDF\'e Dönüştür'),
                            ),
                          ],
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
                text: TextSpan(
                    text: '1 USD: $dolarKur',
                    style: TextStyle(fontSize: fontSize)),
                maxLines: 1,
                textDirection: ui.TextDirection.ltr)
              ..layout())
                .size
                .width +
                (TextPainter(
                    text: TextSpan(
                        text: currentDate,
                        style: TextStyle(fontSize: fontSize)),
                    maxLines: 1,
                    textDirection: ui.TextDirection.ltr)
                  ..layout())
                    .size
                    .width +
                (TextPainter(
                    text: TextSpan(
                        text: '1 EUR: $euroKur',
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