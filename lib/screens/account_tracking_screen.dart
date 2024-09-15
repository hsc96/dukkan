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
import 'products_widget.dart';

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

  @override
  void initState() {
    super.initState();
    fetchCariHesaplar();
    if (widget.products.isNotEmpty) {
      calculateGenelToplam();
    }
  }

  void fetchCariHesaplar() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('cariHesaplar')
        .where('customerName', isEqualTo: widget.customerName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        widget.products.clear(); // Mevcut ürünleri temizle
        // Products ve transactions alanlarını birleştir
        var data = querySnapshot.docs.first.data();
        widget.products.addAll(List<Map<String, dynamic>>.from(data['products'] ?? []));

        List<Map<String, dynamic>> transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        widget.products.addAll(transactions);

        calculateGenelToplam(); // Genel toplamı hesapla
      });
    }
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


  void calculateGenelToplam() {
    double total = widget.products.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
    });

    setState(() {
      genelToplam = total;
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
      widget.products.add({
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
  Widget buildInfoButtonForAccount(Map<String, dynamic> product) {
    bool hasQuoteInfo = product['buttonInfo'] == 'Teklif';
    bool hasKitInfo = product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A';
    bool hasSalesInfo = product['whoTook'] != null && product['whoTook'] != 'N/A';
    bool hasExpectedInfo = product['buttonInfo'] == 'B.sipariş';
    bool hasAdetOrFiyatInfo = product['Eski Adet'] != null || product['Eski Fiyat'] != null;

    return Column(
      children: [
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
              Text('İşleme Alma Tarihi: ${product['işleme Alma Tarihi'] != null ? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(product['işleme Alma Tarihi'].toDate()) : 'N/A'}'),
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
              Text('Ürün Hazır Olma Tarihi: ${readyDate != null ? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(readyDate) : 'N/A'}'),
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




  Widget buildInfoButton(Map<String, dynamic> product) {
    bool hasQuoteInfo = product['buttonInfo'] == 'Teklif';
    bool hasKitInfo = product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A';
    bool hasSalesInfo = product['whoTook'] != null && product['whoTook'] != 'N/A';
    bool hasExpectedInfo = product['buttonInfo'] == 'B.sipariş';

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
      ],
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
        widget.products.removeAt(index); // Ürünü listeden sil

        await docRef.update({
          'products': widget.products,
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

    quantityController.text = widget.products[index]['Adet']?.toString() ?? '';
    priceController.text = widget.products[index]['Adet Fiyatı']?.toString() ?? '';

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
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  // Eski adet ve fiyat bilgilerini kaydet
                  widget.products[index]['Eski Adet'] = widget.products[index]['Adet'];
                  widget.products[index]['Eski Fiyat'] = widget.products[index]['Adet Fiyatı'];
                  widget.products[index]['Değiştiren'] = 'Admin'; // Kullanıcı bilgisi
                  widget.products[index]['İşlem Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());

                  // Yeni adet ve fiyat bilgilerini güncelle
                  widget.products[index]['Adet'] = quantityController.text;
                  widget.products[index]['Adet Fiyatı'] = priceController.text;

                  // Yeni toplam fiyatı hesapla
                  double adet = double.tryParse(quantityController.text) ?? 1;
                  double fiyat = double.tryParse(priceController.text) ?? 0;
                  widget.products[index]['Toplam Fiyat'] = (adet * fiyat).toStringAsFixed(2);
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
                    'products': widget.products,
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('cariHesaplar')
                    .where('customerName', isEqualTo: widget.customerName) // Query using where clause
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator()); // Loading indicator
                  }

                  var docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    print("No document found for customer: ${widget.customerName}");
                    return Center(child: Text('Cari Hesap Takip için veri yok.'));
                  }

                  var data = docs.first.data() as Map<String, dynamic>?; // Get the first document

                  if (data == null) {
                    print("Data is null for customer: ${widget.customerName}");
                    return Center(child: Text('Cari Hesap Takip için veri yok.'));
                  }

                  // Extract products and transactions
                  var products = List<Map<String, dynamic>>.from(data['products'] ?? []);
                  var transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);

                  if (products.isEmpty && transactions.isEmpty) {
                    return Center(child: Text('Cari Hesap Takip için veri yok.'));
                  }

                  var combinedEntries = [...products, ...transactions];

                  // Tarih sıralaması ekliyoruz
                  combinedEntries.sort((a, b) {
                    var aDate = (a['tarih'] != null) ? (a['tarih'] as Timestamp).toDate() : DateTime(1900);
                    var bDate = (b['tarih'] != null) ? (b['tarih'] as Timestamp).toDate() : DateTime(1900);
                    return aDate.compareTo(bDate); // İlk veri üstte olacak şekilde sıralama
                  });


                  return SingleChildScrollView(
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
                          DataColumn(label: Text('Düzenle')), // Yeni Düzenle butonu sütunu ekliyoruz.
                        ],
                        rows: combinedEntries.asMap().entries.map((entry) {
                          int productIndex = entry.key;
                          Map<String, dynamic> product = entry.value;

                          // Toplam fiyat hesaplama
                          double totalUpToThisRow = combinedEntries.sublist(0, productIndex + 1).fold(0.0, (sum, item) {
                            return sum + (double.tryParse(item['Toplam Fiyat']?.toString() ?? '0.0') ?? 0.0);
                          });

                          // Tarih formatlama
                          String formattedDate = product['tarih'] != null
                              ? DateFormat('dd MMM yyyy, HH:mm').format((product['tarih'] as Timestamp).toDate())
                              : 'N/A'; // Eğer tarih yoksa 'N/A' yazılacak

                          return  DataRow(cells: [
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

                            // Düzenle butonunu ekliyoruz
                            DataCell(
                              ElevatedButton(
                                onPressed: () => showEditDialog(productIndex), // İlgili satır için düzenleme dialogu
                                child: Text('Düzenle'),
                              ),
                            ),
                          ]);

                        }).toList(),
                      ),
                    ),
                  );


                },
              ),
            ),

          if (currentIndex == 5)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: showAddOdemeDialog,
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


}
