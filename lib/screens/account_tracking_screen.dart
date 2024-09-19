import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'products_widget.dart';
import 'kits_widget.dart';
import 'quotes_widget.dart';
import 'processed_screen.dart';
import 'customer_expected_products_widget.dart';
import 'package:intl/intl.dart';  // Tarih formatlama için gerekli
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async'; // Asenkron işlemler için gerekli

class CariHesapTakipScreen extends StatefulWidget {
  final String customerName;
  final List<Map<String, dynamic>> products;

  CariHesapTakipScreen({required this.customerName, required this.products});

  @override
  _CariHesapTakipScreenState createState() => _CariHesapTakipScreenState();
}

class _CariHesapTakipScreenState extends State<CariHesapTakipScreen> {
  int currentIndex = 5; // Varsayılan olarak Cari Hesap Takip seçili olacak
  double genelToplam = 0.0;

  // Ürünler ve işlemler için ayrı listeler
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> transactions = [];

  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    fetchCariHesaplar();
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
    connectivitySubscription.cancel(); // Aboneliği iptal et
    super.dispose();
  }

  Future<void> fetchCariHesaplar() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('cariHesaplar')
        .where('customerName', isEqualTo: widget.customerName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        var data = querySnapshot.docs.first.data();
        products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        calculateGenelToplam(); // Genel toplamı hesapla
      });
    }
  }

  void calculateGenelToplam() {
    double totalProducts = products.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
    });

    double totalTransactions = transactions.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
    });

    setState(() {
      genelToplam = totalProducts + totalTransactions;
    });
  }

  void addProduct(Map<String, dynamic> newProduct) async {
    var customerRef = FirebaseFirestore.instance
        .collection('cariHesaplar')
        .where('customerName', isEqualTo: widget.customerName)
        .limit(1);

    var querySnapshot = await customerRef.get();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      var data = querySnapshot.docs.first.data();

      List<dynamic> existingProducts = data['products'] ?? [];

      // Her ürün eklemede tarih/saat bilgisini ekliyoruz
      newProduct['tarih'] = Timestamp.now();  // Eklenen ürünlerin tarih bilgisini alır

      existingProducts.add(newProduct);

      await docRef.update({
        'products': existingProducts,
      }).then((_) {
        print('Ürün başarıyla eklendi.');
        fetchCariHesaplar();  // Verileri yeniden yükle ve ekrana yansıt
      }).catchError((error) {
        print('Yeni ürün eklenirken hata oluştu: $error');
      });
    }
  }

  void calculateGenelToplamUpdated() {
    double totalProducts = products.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
    });

    double totalTransactions = transactions.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
    });

    setState(() {
      genelToplam = totalProducts + totalTransactions;
    });
  }

  void processSelectedProductsToAccountTracking(List<int> selectedIndexes, List<Map<String, dynamic>> customerProducts) async {
    List<Map<String, dynamic>> selectedProducts = selectedIndexes.map((index) => customerProducts[index]).toList();

    for (var product in selectedProducts) {
      await FirebaseFirestore.instance.collection('cariHesaplar').add({
        'customerName': widget.customerName,
        'Kodu': product['Kodu'],
        'Detay': product['Detay'],
        'Adet': product['Adet'],
        'Adet Fiyatı': product['Adet Fiyatı'],
        'İskonto': product['İskonto'],
        'Toplam Fiyat': product['Toplam Fiyat'],
        'Genel Toplam': product['Genel Toplam'],
        'İşlem Tipi': 'Satış',
        'tarih': Timestamp.now(),
      });
    }

    setState(() {
      customerProducts.removeWhere((product) => selectedProducts.contains(product));
    });

    fetchCariHesaplar(); // Veritabanından cari hesap verilerini tekrar yükle
  }

  void addOdeme(double amount) async {
    setState(() {
      genelToplam -= amount;

      // Ödeme eklerken tarih/saat bilgisini de ekleyelim
      transactions.add({
        'Kodu': '',
        'Detay': 'Ödeme Eklendi',
        'Adet': '',
        'Adet Fiyatı': '',
        'İskonto': '',
        'Toplam Fiyat': '-$amount',
        'Genel Toplam': genelToplam,
        'İşlem Tipi': 'Ödeme',
        'tarih': Timestamp.now(),  // Ödeme tarihini ekliyoruz
      });
    });

    var customerRef = FirebaseFirestore.instance
        .collection('cariHesaplar')
        .where('customerName', isEqualTo: widget.customerName)
        .limit(1);

    var querySnapshot = await customerRef.get();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      var data = querySnapshot.docs.first.data();

      List<dynamic> existingTransactions = data['transactions'] ?? [];
      existingTransactions.add({
        'Kodu': '',
        'Detay': 'Ödeme Eklendi',
        'Adet': '',
        'Adet Fiyatı': '',
        'İskonto': '',
        'Toplam Fiyat': '-$amount',
        'Genel Toplam': genelToplam,
        'İşlem Tipi': 'Ödeme',
        'tarih': Timestamp.now(),  // Ödeme tarihini ekliyoruz
      });

      await docRef.update({
        'transactions': existingTransactions,
      }).then((_) {
        fetchCariHesaplar(); // Verileri yeniden yükle
      }).catchError((error) {
        print('Ödeme güncellenirken hata oluştu: $error');
      });
    }
  }

  // Cari hesap takip widget'ında bilgi butonlarını oluşturacağız
  Widget buildInfoButton(Map<String, dynamic> product) {
    bool hasQuoteInfo = product['buttonInfo'] == 'Teklif';
    bool hasKitInfo = product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A';
    bool hasSalesInfo = product['whoTook'] != null && product['whoTook'] != 'N/A';
    bool hasExpectedInfo = product['buttonInfo'] == 'B.sipariş';
    bool hasAdetOrFiyatInfo = product['Eski Adet'] != null || product['Eski Fiyat'] != null;

    return Column(
      children: [
        if (hasQuoteInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForQuote(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Teklif'),
          ),
        if (hasKitInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForKit(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Kit'),
          ),
        if (hasSalesInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForSales(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text('Satış'),
          ),
        if (hasExpectedInfo)
          ElevatedButton(
            onPressed: () => showExpectedQuoteInfoDialog(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: Text('B.sipariş'),
          ),
        if (hasAdetOrFiyatInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForChanges(product), // Değişiklik dialogu için fonksiyon
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Bilgi'),
          ),
      ],
    );
  }

  // Değişiklikleri gösterecek olan dialog fonksiyonu
  void showInfoDialogForChanges(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Değişiklik Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Eski Adet: ${product['Eski Adet'] ?? 'N/A'}'),
              Text('Eski Fiyat: ${product['Eski Fiyat'] ?? 'N/A'}'),
              Text('Değiştiren: ${product['Değiştiren'] ?? 'N/A'}'),
              Text('Değişim Tarihi: ${product['İşlem Tarihi'] ?? 'N/A'}'),
            ],
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
  }

  void showAddOdemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController odemeController = TextEditingController();

        return AlertDialog(
          title: Text('Ödeme Ekle'),
          content: TextField(
            controller: odemeController,
            decoration: InputDecoration(hintText: 'Ödeme Tutarı'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (odemeController.text.isNotEmpty) {
                  double amount = double.tryParse(odemeController.text) ?? 0.0;
                  if (amount > 0) {
                    // Ödeme ekleme ve işlemleri burada yapıyoruz
                    addOdeme(amount);

                    // Ödeme eklendikten sonra sayfa güncelleme işlemi
                    fetchCariHesaplar();

                    // Dialog'u kapatma işlemi
                    Navigator.of(context).pop();
                  }
                }
              },
              child: Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  void showInfoDialogForQuote(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Onaylanan Ürün Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Müşteri: ${product['Müşteri'] ?? 'N/A'}'),
              Text('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}'),
              Text('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}'),
              Text('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}'),
              Text('Teklif Tarihi: ${product['Teklif Tarihi'] ?? 'N/A'}'),
              Text('İşleme Alan: ${product['islemeAlan'] ?? 'N/A'}'), // İşleme Alan kullanıcı bilgisi
            ],
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
  }

  void showInfoDialogForKit(Map<String, dynamic> product) {
    DateTime? siparisTarihi;
    if (product['siparisTarihi'] != null) {
      siparisTarihi = DateTime.parse(product['siparisTarihi']);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Kit Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ana Kit Adı: ${product['Ana Kit Adı'] ?? 'N/A'}'),
              Text('Alt Kit Adı: ${product['Alt Kit Adı'] ?? 'N/A'}'),
              Text('Oluşturan Kişi: ${product['Oluşturan Kişi'] ?? 'Admin'}'),
              Text('İşleme Alma Tarihi: ${product['işleme Alma Tarihi'] != null ? DateFormat('dd MMMM yyyy, HH:mm').format(product['işleme Alma Tarihi'].toDate()) : 'N/A'}'),
            ],
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
  }

  void showInfoDialogForSales(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Satış Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ürünü Alan: ${product['whoTook'] ?? 'N/A'}'),
              Text('İşleyen: ${product['islemeAlan'] ?? 'N/A'}'),
              Text('Sipariş Yöntemi: ${product['orderMethod'] ?? 'N/A'}'),
              Text('Teslim Alan: ${product['recipient'] ?? 'N/A'}'),
              Text('Sipariş Tarihi: ${product['siparisTarihi'] ?? 'N/A'}'),
            ],
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
  }

  void showExpectedQuoteInfoDialog(Map<String, dynamic> product) {
    DateTime? readyDate;
    if (product['Ürün Hazır Olma Tarihi'] != null) {
      readyDate = (product['Ürün Hazır Olma Tarihi'] as Timestamp).toDate();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Beklenen Teklif Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Müşteri: ${product['Müşteri'] ?? 'N/A'}'),
              Text('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}'),
              Text('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}'),
              Text('Teklif Tarihi: ${product['Teklif Tarihi'] ?? 'N/A'}'),
              Text('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}'),
              Text('Ürün Hazır Olma Tarihi: ${readyDate != null ? DateFormat('dd MMMM yyyy, HH:mm').format(readyDate) : 'N/A'}'),
            ],
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
  }

  Future<bool> showDeleteConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürünü Sil'),
          content: Text('Bu ürünü silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // İptal
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Onay
              },
              child: Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeProduct(int index) async {
    bool shouldDelete = await showDeleteConfirmationDialog();
    if (shouldDelete) {
      var customerRef = FirebaseFirestore.instance
          .collection('cariHesaplar')
          .where('customerName', isEqualTo: widget.customerName)
          .limit(1);

      var querySnapshot = await customerRef.get();
      if (querySnapshot.docs.isNotEmpty) {
        var docRef = querySnapshot.docs.first.reference;
        products.removeAt(index); // Ürünü listeden sil

        await docRef.update({
          'products': products,
        }).then((_) {
          fetchCariHesaplar(); // Verileri yeniden yükle
        }).catchError((error) {
          print('Ürün silinirken hata oluştu: $error');
        });
      }
    }
  }

  void showEditDialog(int index) {
    TextEditingController quantityController = TextEditingController();
    TextEditingController priceController = TextEditingController();

    // Ürünün mevcut değerlerini al
    quantityController.text = products[index]['Adet']?.toString() ?? '';
    priceController.text = products[index]['Adet Fiyatı']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürünü Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: InputDecoration(labelText: 'Adet'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Adet Fiyatı'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
                if (_isConnected) { // İnternet bağlantısı kontrolü
                  // Eski değerleri bul
                  double eskiAdet = double.tryParse(products[index]['Adet']?.toString() ?? '1') ?? 1;
                  double eskiFiyat = double.tryParse(products[index]['Adet Fiyatı']?.toString() ?? '0.0') ?? 0.0;
                  double eskiToplam = eskiAdet * eskiFiyat;

                  // Yeni değerleri al
                  double yeniAdet = double.tryParse(quantityController.text) ?? eskiAdet;
                  double yeniFiyat = double.tryParse(priceController.text) ?? eskiFiyat;
                  double yeniToplam = yeniAdet * yeniFiyat;

                  setState(() {
                    // Eski değerleri kaydet
                    products[index]['Eski Adet'] = eskiAdet.toString();
                    products[index]['Eski Fiyat'] = eskiFiyat.toString();
                    products[index]['Değiştiren'] = 'Admin'; // Kullanıcı bilgisi
                    products[index]['İşlem Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());

                    // Yeni değerleri güncelle
                    products[index]['Adet'] = yeniAdet.toString();
                    products[index]['Adet Fiyatı'] = yeniFiyat.toString();
                    products[index]['Toplam Fiyat'] = yeniToplam.toStringAsFixed(2);
                  });

                  // Firestore'da güncelle
                  var customerRef = FirebaseFirestore.instance
                      .collection('cariHesaplar')
                      .where('customerName', isEqualTo: widget.customerName)
                      .limit(1);

                  var querySnapshot = await customerRef.get();
                  if (querySnapshot.docs.isNotEmpty) {
                    var docRef = querySnapshot.docs.first.reference;
                    await docRef.update({
                      'products': products,
                    }).then((_) {
                      // Tablodaki toplam ve verileri güncelle
                      fetchCariHesaplar();
                      // Genel toplamı yeniden hesapla
                      calculateGenelToplam();
                    }).catchError((error) {
                      print('Ürün güncellenirken hata oluştu: $error');
                    });
                  }

                  Navigator.of(context).pop(); // Dialog'u kapat
                } else {
                  _showNoConnectionDialog(
                    'Bağlantı Sorunu',
                    'İnternet bağlantısı yok, ürün düzenleme işlemi gerçekleştirilemiyor.',
                  );
                }
              },
              child: Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Cari Hesap Takip - ${widget.customerName}'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          ToggleButtons(
            isSelected: [
              currentIndex == 0,
              currentIndex == 1,
              currentIndex == 2,
              currentIndex == 3,
              currentIndex == 4,
              currentIndex == 5, // Cari Hesap Takip seçili olacak
            ],
            onPressed: (int index) {
              setState(() {
                currentIndex = index;
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Ürünler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Kitler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Teklifler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('İşlenenler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Beklenen Ürünler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Cari Hesap Takip'),
              ),
            ],
          ),
          if (currentIndex == 0)
            Expanded(
              child: ProductsWidget(
                customerName: widget.customerName,
                onTotalUpdated: (total) => setState(() {
                  genelToplam = total;
                }),
                onProcessSelected: processSelectedProductsToAccountTracking,
              ),
            ),
          if (currentIndex == 1) Expanded(child: KitsWidget(customerName: widget.customerName)),
          if (currentIndex == 2) Expanded(child: QuotesWidget(customerName: widget.customerName)),
          if (currentIndex == 3) Expanded(child: ProcessedWidget(customerName: widget.customerName)),
          if (currentIndex == 4) Expanded(child: CustomerExpectedProductsWidget(customerName: widget.customerName)),
          if (currentIndex == 5)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('İşlem Tipi')),
                      DataColumn(label: Text('Kodu')),
                      DataColumn(label: Text('Detay')),
                      DataColumn(label: Text('Adet')),
                      DataColumn(label: Text('Adet Fiyatı')),
                      DataColumn(label: Text('İskonto')),
                      DataColumn(label: Text('Toplam Fiyat')),
                      DataColumn(label: Text('Genel Toplam')),
                      DataColumn(label: Text('Tarih')),
                      DataColumn(label: Text('Aksiyonlar')), // Bilgi butonları için yeni sütun
                      DataColumn(label: Text('Düzenle')), // Sadece Düzenle butonu için sütun
                    ],
                    rows: [
                      // Ürünler Listesi
                      ...products.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> product = entry.value;

                        // Toplam fiyat hesaplama
                        double totalUpToThisRow = products.sublist(0, index + 1).fold(0.0, (sum, item) {
                          return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
                        });

                        // Tarih formatlama
                        String formattedDate = product['tarih'] != null
                            ? DateFormat('dd MMM yyyy, HH:mm').format((product['tarih'] as Timestamp).toDate())
                            : 'N/A'; // Eğer tarih yoksa 'N/A' yazılacak

                        return DataRow(cells: [
                          DataCell(Text(product['İşlem Tipi']?.toString() ?? '')),
                          DataCell(Text(product['Kodu']?.toString() ?? '')),
                          DataCell(Text(product['Detay']?.toString() ?? '')),
                          DataCell(Text(product['Adet']?.toString() ?? '')),
                          DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                          DataCell(Text(product['İskonto']?.toString() ?? '')),
                          DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                          DataCell(Text(totalUpToThisRow.toStringAsFixed(2))), // Genel Toplam
                          DataCell(Text(formattedDate)), // Tarih bilgisi
                          DataCell(buildInfoButton(product)), // Bilgi butonu
                          DataCell(
                            ElevatedButton(
                              onPressed: () => showEditDialog(index),
                              child: Text('Düzenle'),
                            ),
                          ),
                        ]);
                      }).toList(),
                      // İşlemler Listesi
                      ...transactions.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> transaction = entry.value;

                        // Toplam fiyat hesaplama
                        double totalUpToThisRow = products.fold(0.0, (sum, item) {
                          return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
                        }) + transactions.sublist(0, index + 1).fold(0.0, (sum, item) {
                          return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
                        });

                        // Tarih formatlama
                        String formattedDate = transaction['tarih'] != null
                            ? DateFormat('dd MMM yyyy, HH:mm').format((transaction['tarih'] as Timestamp).toDate())
                            : 'N/A'; // Eğer tarih yoksa 'N/A' yazılacak

                        return DataRow(cells: [
                          DataCell(Text(transaction['İşlem Tipi']?.toString() ?? '')),
                          DataCell(Text(transaction['Kodu']?.toString() ?? '')),
                          DataCell(Text(transaction['Detay']?.toString() ?? '')),
                          DataCell(Text(transaction['Adet']?.toString() ?? '')),
                          DataCell(Text(transaction['Adet Fiyatı']?.toString() ?? '')),
                          DataCell(Text(transaction['İskonto']?.toString() ?? '')),
                          DataCell(Text(transaction['Toplam Fiyat']?.toString() ?? '')),
                          DataCell(Text(totalUpToThisRow.toStringAsFixed(2))),
                          DataCell(Text(formattedDate)),
                          DataCell(buildInfoButton(transaction)), // Bilgi butonu
                          DataCell(SizedBox()), // İşlemler için "Düzenle" butonu yok
                        ]);
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

          if (currentIndex == 5)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_isConnected) {
                        showAddOdemeDialog();
                      } else {
                        _showNoConnectionDialog(
                          'Bağlantı Sorunu',
                          'İnternet bağlantısı yok, ödeme ekleme işlemi gerçekleştirilemiyor.',
                        );
                      }
                    },
                    child: Text('Ödeme Ekle'),
                  ),
                  Text(
                    'Genel Toplam: ${genelToplam.toStringAsFixed(2)} TL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }

// Diğer fonksiyonlar ve dialoglar burada...
}
