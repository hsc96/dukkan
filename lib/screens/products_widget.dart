import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'products_pdf.dart';
import 'products_excel.dart';
import 'account_tracking_screen.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProductsWidget extends StatefulWidget {
  final String customerName;
  final Function(double) onTotalUpdated; // Yeni eklenen parametre
  final Function(List<int> selectedIndexes, List<Map<String, dynamic>> customerProducts) onProcessSelected;



  ProductsWidget({
    required this.customerName,
    required this.onTotalUpdated,
    required this.onProcessSelected, // Yeni parametre
  });

  @override
  _ProductsWidgetState createState() => _ProductsWidgetState();
}

class _ProductsWidgetState extends State<ProductsWidget> {
  List<Map<String, dynamic>> customerProducts = [];

  bool isEditing = false;
  int editingIndex = -1;
  Map<String, dynamic>? originalProductData;
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController explanationController = TextEditingController();
  Set<int> selectedIndexes = {};
  bool showRadioButtons = false;
  List<Map<String, dynamic>> mainKits = [];
  int? currentEditingKitIndex;
  int? currentEditingSubKitIndex;
  List<Map<String, dynamic>> tempProducts = [];
  List<Map<String, dynamic>> originalProducts = [];
  bool showInfoButtons = false;
  bool _isConnected = true;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  void _checkInitialConnectivity() async {
    try {
      ConnectivityResult result = await _connectivity.checkConnectivity();
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    } catch (e) {
      print("Bağlantı durumu kontrol edilirken hata oluştu: $e");
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override

  @override
  void initState() {
    super.initState();

    // Mevcut internet bağlantısı durumunu kontrol edin
    _checkInitialConnectivity();

    // İnternet bağlantısı değişikliklerini dinleyin
    connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    });

    fetchCustomerProducts();
    fetchKits();
  }

  void generateExcel() {
    List<Map<String, dynamic>> selectedProducts = selectedIndexes.map((index) => customerProducts[index]).toList();
    ProductsExcel.generateProductsExcel(selectedProducts, widget.customerName);
  }



  void generatePDF() {
    List<Map<String, dynamic>> selectedProducts = selectedIndexes.map((index) => customerProducts[index]).toList();
    ProductsPDF.generateProductsPDF(selectedProducts, true);
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> fetchCustomerProducts() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('customerDetails')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      setState(() {
        // Debugging için verileri konsola yazdırın
        print('Fetched Products: ${data['products']}');
        customerProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
      });
      updateTotalAndVat();
    } else {
      print('No products found for customer ${widget.customerName}');
    }
  }



  Future<void> fetchKits() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('kitler')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    setState(() {
      mainKits = querySnapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'subKits': List<Map<String, dynamic>>.from(data['subKits'] ?? []),
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
        };
      }).toList();
    });
  }

  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(customerProducts[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;

      // Eski değerleri saklıyoruz
      customerProducts[index]['Eski Adet'] = customerProducts[index]['Adet'];
      customerProducts[index]['Değiştiren'] = 'admin';  // Burada kullanıcı adı manuel girildi, dinamik yapılabilir
      customerProducts[index]['İşlem Tarihi'] = DateTime.now().toIso8601String();

      customerProducts[index]['Adet'] = quantity;
      customerProducts[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);
    });
  }

  void updatePrice(int index, String price) {
    setState(() {
      double adet = double.tryParse(customerProducts[index]['Adet']?.toString() ?? '1') ?? 1;
      double priceValue = double.tryParse(price) ?? 0.0;

      // Eski fiyat değerini saklıyoruz
      customerProducts[index]['Eski Fiyat'] = customerProducts[index]['Adet Fiyatı'];
      customerProducts[index]['Değiştiren'] = 'admin';  // Burada kullanıcı adı manuel girildi, dinamik yapılabilir
      customerProducts[index]['İşlem Tarihi'] = DateTime.now().toIso8601String();

      customerProducts[index]['Adet Fiyatı'] = price;
      customerProducts[index]['Toplam Fiyat'] = (adet * priceValue).toStringAsFixed(2);
    });
  }

  void showInfoDialogForProduct(Map<String, dynamic> product) {
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
              Text('Fiyat Açıklaması: ${product['Fiyat Açıklaması'] ?? 'N/A'}'),
              Text('İşlem Tarihi: ${product['İşlem Tarihi'] ?? 'N/A'}'),
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


  void showExplanationDialog(int index, bool isQuantityChanged, bool isPriceChanged) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Değişiklik Açıklaması'),
          content: TextField(
            controller: explanationController,
            decoration: InputDecoration(hintText: 'Değişiklik nedeni'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (explanationController.text.isNotEmpty) {
                  setState(() {
                    if (isQuantityChanged) {
                      customerProducts[index]['Adet Açıklaması'] = explanationController.text;
                      customerProducts[index]['Değiştiren'] = 'admin';
                      customerProducts[index]['Eski Adet'] = originalProductData?['Adet']?.toString();
                      customerProducts[index]['Adet'] = quantityController.text;
                    }
                    if (isPriceChanged) {
                      customerProducts[index]['Fiyat Açıklaması'] = explanationController.text;
                      customerProducts[index]['Değiştiren'] = 'admin';
                      customerProducts[index]['Eski Fiyat'] = originalProductData?['Adet Fiyatı']?.toString();
                      customerProducts[index]['Adet Fiyatı'] = priceController.text;
                    }
                    customerProducts[index]['İşlem Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());
                    saveEditsToDatabase(index); // Değişiklikleri veritabanına kaydet
                    updateTotalAndVat();
                    isEditing = false;
                    editingIndex = -1;
                    originalProductData = null;
                    explanationController.clear();
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }



  void updateTotalAndVat() {
    double toplamTutar = 0.0;
    customerProducts.forEach((product) {
      if (product['Kodu']?.toString() != '' && product['Toplam Fiyat']?.toString() != '') {
        toplamTutar += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      }
    });

    double kdv = toplamTutar * 0.20;
    double genelToplam = toplamTutar + kdv;

    setState(() {
      customerProducts.removeWhere((product) =>
      product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
          product['Adet Fiyatı']?.toString() == 'KDV %20' ||
          product['Adet Fiyatı']?.toString() == 'Genel Toplam');

      customerProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Toplam Tutar',
        'Toplam Fiyat': toplamTutar.toStringAsFixed(2),
      });
      customerProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'KDV %20',
        'Toplam Fiyat': kdv.toStringAsFixed(2),
      });
      customerProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Genel Toplam',
        'Toplam Fiyat': genelToplam.toStringAsFixed(2),
      });

      // Firestore'a faturası kesilecek tutar güncelleme
      var customerRef = FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('Açıklama', isEqualTo: widget.customerName)
          .limit(1);

      customerRef.get().then((querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          var docRef = querySnapshot.docs.first.reference;
          docRef.update({
            'Fatura Kesilecek Tutar': genelToplam,
          }).catchError((error) {
            print('Genel Toplam güncellenirken hata oluştu: $error');
          });
        }
      }).catchError((error) {
        print('Müşteri bilgisi alınırken hata oluştu: $error');
      });
    });
  }






  Future<void> saveEditsToDatabase(int index) async {
    var customerCollection = FirebaseFirestore.instance.collection('customerDetails');
    var querySnapshot = await customerCollection.where('customerName', isEqualTo: widget.customerName).get();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      await docRef.update({
        'products': customerProducts,
      });
    }
  }

  void removeProduct(int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürünü Kaldır'),
          content: Text('Bu ürünü kaldırmak istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () async {
                var customerCollection = FirebaseFirestore.instance.collection('customerDetails');
                var querySnapshot = await customerCollection.where('customerName', isEqualTo: widget.customerName).get();

                if (querySnapshot.docs.isNotEmpty) {
                  var docRef = querySnapshot.docs.first.reference;
                  customerProducts.removeAt(index);
                  await docRef.update({
                    'products': customerProducts,
                  });

                  setState(() {
                    updateTotalAndVat();
                    isEditing = false;
                    editingIndex = -1;
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> scanBarcodeForKit(int kitIndex, {int? subKitIndex}) async {
    try {
      var result = await BarcodeScanner.scan();
      var barcode = result.rawContent;
      fetchProductDetailsForKit(barcode, kitIndex, subKitIndex: subKitIndex);
    } catch (e) {
      setState(() {
        print('Barkod tarama hatası: $e');
      });
    }
  }

  Future<void> fetchProductDetailsForKit(String barcode, int kitIndex, {int? subKitIndex}) async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('urunler')
        .where('Barkod', isEqualTo: barcode)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var products = querySnapshot.docs.map((doc) => doc.data()).toList();
      var uniqueProducts = <String, Map<String, dynamic>>{};
      for (var product in products) {
        uniqueProducts[product['Kodu']] = product;
      }
      var uniqueProductList = uniqueProducts.values.toList();

      if (uniqueProductList.length > 1) {
        showProductSelectionDialog(uniqueProductList, kitIndex, subKitIndex: subKitIndex);
      } else {
        addProductToKit(uniqueProductList.first, kitIndex, subKitIndex: subKitIndex);
      }
    } else {
      print('Ürün bulunamadı.');
    }
  }

  void showProductSelectionDialog(List<Map<String, dynamic>> products, int kitIndex, {int? subKitIndex}) {
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
                  onTap: () {
                    addProductToKit(products[index], kitIndex, subKitIndex: subKitIndex);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
  void addProductToKit(Map<String, dynamic> product, int kitIndex, {int? subKitIndex}) {
    var currentDate = DateTime.now().toIso8601String(); // Tarihi ISO formatında kaydediyoruz

    setState(() {
      var newProduct = {
        'Detay': product['Detay'] ?? '',
        'Kodu': product['Kodu'] ?? '',
        'Adet': '1',
        'siparisTarihi': currentDate, // Eklendiği andaki tarih ve saat bilgisi
      };

      if (subKitIndex == null) {
        mainKits[kitIndex]['products'].add(newProduct);
      } else {
        mainKits[kitIndex]['subKits'][subKitIndex]['products'].add(newProduct);
      }
    });
    saveKitsToFirestore();
  }


  Future<void> saveKitsToFirestore() async {
    var kitlerCollection = FirebaseFirestore.instance.collection('kitler');

    for (var kit in mainKits) {
      var kitId = kit['id'];
      if (kitId == null) {
        var newKitDocRef = kitlerCollection.doc();
        await newKitDocRef.set({
          'name': kit['name'],
          'subKits': kit['subKits'],
          'products': kit['products'],
          'customerName': widget.customerName,
        });
        kit['id'] = newKitDocRef.id;
      } else {
        await kitlerCollection.doc(kitId).update({
          'name': kit['name'],
          'subKits': kit['subKits'],
          'products': kit['products'],
          'customerName': widget.customerName,
        });
      }
    }
  }



  void createNewMainKit(String kitName) {
    setState(() {
      mainKits.add({
        'id': null,
        'name': kitName,
        'subKits': [],
        'products': [],
      });
      tempProducts = List.from(selectedIndexes.map((index) => customerProducts[index]));
      selectedIndexes.clear();
      showRadioButtons = false;
    });
  }

  void createNewSubKit(int kitIndex, String subKitName) {
    setState(() {
      mainKits[kitIndex]['subKits'].add({
        'name': subKitName,
        'products': List.from(tempProducts.map((product) {
          return {
            'Detay': product['Detay'],
            'Kodu': product['Kodu'],
            'Adet': product['Adet'],
          };
        })),
      });
      tempProducts.clear();
    });
    saveKitsToFirestore();
  }

  void showKitCreationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        TextEditingController kitNameController = TextEditingController();
        return AlertDialog(
          title: Text('Kit İsmi Girin'),
          content: TextField(
            controller: kitNameController,
            decoration: InputDecoration(hintText: 'Kit İsmi'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (kitNameController.text.isNotEmpty) {
                  createNewMainKit(kitNameController.text);
                  Navigator.of(context).pop();
                  showSubKitCreationDialog(mainKits.length - 1);
                }
              },
              child: Text('Oluştur'),
            ),
          ],
        );
      },
    );
  }

  void showSubKitCreationDialog(int kitIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        TextEditingController subKitNameController = TextEditingController();
        return AlertDialog(
          title: Text('Alt Kit İsmi Girin'),
          content: TextField(
            controller: subKitNameController,
            decoration: InputDecoration(hintText: 'Alt Kit İsmi'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (subKitNameController.text.isNotEmpty) {
                  createNewSubKit(kitIndex, subKitNameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Oluştur'),
            ),
          ],
        );
      },
    );
  }

  void showKitAssignmentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ana Kit Seçin'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mainKits.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(mainKits[index]['name']),
                  onTap: () {
                    debugPrint('Ana Kit Seçildi: ${mainKits[index]['name']}');
                    Navigator.of(context).pop();
                    showSubKitCreationDialogForAssignment(index);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void showSubKitCreationDialogForAssignment(int kitIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        TextEditingController subKitNameController = TextEditingController();
        return AlertDialog(
          title: Text('Alt Kit İsmi Girin'),
          content: TextField(
            controller: subKitNameController,
            decoration: InputDecoration(hintText: 'Alt Kit İsmi'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (subKitNameController.text.isNotEmpty) {
                  createNewSubKitForAssignment(kitIndex, subKitNameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Oluştur'),
            ),
          ],
        );
      },
    );
  }

  void createNewSubKitForAssignment(int kitIndex, String subKitName) {
    setState(() {
      mainKits[kitIndex]['subKits'].add({
        'name': subKitName,
        'products': List.from(selectedIndexes.map((index) {
          return {
            'Detay': customerProducts[index]['Detay'],
            'Kodu': customerProducts[index]['Kodu'],
            'Adet': customerProducts[index]['Adet'],
          };
        })),
      });
      selectedIndexes.clear();
      showRadioButtons = false;
    });
    saveKitsToFirestore();
  }

  void showEditSubKitDialog(int kitIndex, int subKitIndex) {
    setState(() {
      currentEditingKitIndex = kitIndex;
      currentEditingSubKitIndex = subKitIndex;
      tempProducts = List.from(mainKits[kitIndex]['subKits'][subKitIndex]['products']);
      originalProducts = List.from(mainKits[kitIndex]['subKits'][subKitIndex]['products']);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Alt Kiti Düzenle'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: tempProducts.length,
                      itemBuilder: (BuildContext context, int index) {
                        var product = tempProducts[index];
                        return ListTile(
                          title: Text(product['Detay'] ?? ''),
                          subtitle: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Adet',
                            ),
                            onChanged: (value) {
                              setState(() {
                                product['Adet'] = value;
                              });
                            },
                            controller: TextEditingController(text: product['Adet']),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                tempProducts.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    TextButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Barkod ile Ürün Ekle'),
                      onPressed: () => scanBarcodeForKit(currentEditingKitIndex!, subKitIndex: currentEditingSubKitIndex),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      mainKits[currentEditingKitIndex!]['subKits'][currentEditingSubKitIndex!]['products'] = originalProducts;
                      tempProducts = [];
                      originalProducts = [];
                      currentEditingKitIndex = null;
                      currentEditingSubKitIndex = null;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('Vazgeç'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      mainKits[currentEditingKitIndex!]['subKits'][currentEditingSubKitIndex!]['products'] = tempProducts;
                      tempProducts = [];
                      originalProducts = [];
                      currentEditingKitIndex = null;
                      currentEditingSubKitIndex = null;
                    });
                    saveKitsToFirestore();
                    Navigator.of(context).pop();
                  },
                  child: Text('Tamam'),
                ),
              ],
            );
          },
        );
      },
    );
  }





  void showProcessDialog() {
    if (selectedIndexes.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Uyarı'),
            content: Text('Lütfen ürün seçin.'),
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
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          TextEditingController processNameController = TextEditingController();
          return AlertDialog(
            title: Text('İşlem İsmi Girin'),
            content: TextField(
              controller: processNameController,
              decoration: InputDecoration(hintText: 'İşlem İsmi'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (processNameController.text.isNotEmpty) {
                    processSelectedProducts(processNameController.text);
                    Navigator.of(context).pop();
                  }
                },
                child: Text('Kaydet'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('İptal'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> processSelectedProducts(String processName) async {
    var selectedProducts = selectedIndexes.map((index) {
      var product = customerProducts[index];
      // buttonInfo değerini mevcut değeriyle koruyoruz
      return product;
    }).toList();

    var processedData = {
      'name': processName,
      'date': Timestamp.now(),
      'products': selectedProducts,
      'customerName': widget.customerName,
    };

    await FirebaseFirestore.instance.collection('islenenler').add(processedData);

    setState(() {
      customerProducts.removeWhere((product) => selectedIndexes.contains(customerProducts.indexOf(product)));
      selectedIndexes.clear();
      showRadioButtons = false;
    });

    saveEditsToDatabase(0);
  }



  Widget buildInfoButton(Map<String, dynamic> product) {
    bool hasQuoteInfo = product['buttonInfo'] == 'Teklif';
    bool hasKitInfo = product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A';
    bool hasSalesInfo = product['whoTook'] != null && product['whoTook'] != 'N/A';
    bool hasExpectedInfo = product['buttonInfo'] == 'B.sipariş';

    // showInfoButtons kontrolünü kaldırıyoruz, böylece her zaman info butonu görünür
    return Column(
      children: [
        if (hasQuoteInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForQuote(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Teklif'),
          ),
        SizedBox(width: 5),
        if (hasKitInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForKit(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Kit'),
          ),
        SizedBox(width: 5),
        if (hasSalesInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForSales(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text('Satış'),
          ),
        SizedBox(width: 5),
        if (hasExpectedInfo)
          ElevatedButton(
            onPressed: () => showExpectedQuoteInfoDialog(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: Text('B.sipariş'),
          ),
      ],
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


  void showInfoDialogForExpectedQuote(Map<String, dynamic> product) {
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
              Text('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}'),
              Text('Teklif Tarihi: ${product['Teklif Tarihi'] ?? 'N/A'}'),
              Text('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}'),
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


  Future<void> processSelectedProductsToAccountTracking() async {
    if (!_isConnected) {
      // İnternet yoksa uyarı göster
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Bağlantı Sorunu'),
            content: Text('İnternet bağlantısı yok, işlem gerçekleştirilemiyor.'),
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
      return;
    }

    // İnternet varsa işlemlere devam edin
    List<Map<String, dynamic>> selectedProducts = selectedIndexes.map((index) {
      var product = Map<String, dynamic>.from(customerProducts[index]);

      // Tarih bilgisini Timestamp olarak ekle
      product['tarih'] = Timestamp.now();

      return product;
    }).toList();

    try {
      // Müşteriye ait cari hesap belgesini bul
      var querySnapshot = await FirebaseFirestore.instance
          .collection('cariHesaplar')
          .where('customerName', isEqualTo: widget.customerName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Müşteri için bir cari hesap varsa, mevcut ürünleri al
        var docRef = querySnapshot.docs.first.reference;
        var data = querySnapshot.docs.first.data();

        // Mevcut ürünler listesi
        List<dynamic> existingProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);

        // Yeni ürünleri mevcut listeye ekle
        existingProducts.addAll(selectedProducts);

        // Firestore'a güncellenmiş ürün listesini kaydet
        await docRef.update({
          'products': existingProducts,
        });
      } else {
        // Eğer müşteri için cari hesap yoksa, yeni bir cari hesap oluştur
        await FirebaseFirestore.instance.collection('cariHesaplar').add({
          'customerName': widget.customerName,
          'products': selectedProducts,
        });
      }

      setState(() {
        // Sadece seçilen ürünleri customerProducts listesinden sil
        selectedIndexes.forEach((index) {
          customerProducts[index]['processed'] = true;  // Ürün işlenmiş olarak işaretle
        });

        // Filtreleme ile sadece işlenmemiş ürünleri koru
        customerProducts = customerProducts.where((product) => product['processed'] != true).toList();

        // Seçilen ürünleri işledikten sonra seçili dizini temizle
        selectedIndexes.clear();
        showRadioButtons = false;
      });

      // Firestore'daki 'customerDetails' koleksiyonuna güncellemeyi kaydet
      var customerCollection = FirebaseFirestore.instance.collection('customerDetails');
      var customerSnapshot = await customerCollection.where('customerName', isEqualTo: widget.customerName).limit(1).get();

      if (customerSnapshot.docs.isNotEmpty) {
        var docRef = customerSnapshot.docs.first.reference;
        await docRef.update({
          'products': customerProducts,
        });
      }

      // CariHesapTakipScreen widget'ına yönlendir
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CariHesapTakipScreen(
            customerName: widget.customerName,
            products: selectedProducts,
          ),
        ),
      );
    } catch (error) {
      print("Error while processing products to account tracking: $error");
      // Hata durumunda ekranda mesaj gösterebilirsiniz
    }
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
              Text('Ürünü Kim Aldı: ${product['whoTook'] ?? 'N/A'}'),
              if (product['whoTook'] == 'Müşterisi') ...[
                Text('Müşteri İsmi: ${product['recipient'] ?? 'N/A'}'),
                Text('Firmadan Bilgilendirilecek Kişi İsmi: ${product['contactPerson'] ?? 'N/A'}'),
              ],
              if (product['whoTook'] == 'Kendi Firması')
                Text('Teslim Alan Çalışan İsmi: ${product['recipient'] ?? 'N/A'}'),
              Text('Sipariş Şekli: ${product['orderMethod'] ?? 'N/A'}'),
              Text('Tarih: ${product['siparisTarihi'] ?? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}'),
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




  @override
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(showRadioButtons ? Icons.remove : Icons.add, color: Colors.blue),
                onPressed: () {
                  setState(() {
                    showRadioButtons = !showRadioButtons;
                    selectedIndexes.clear();
                  });
                },
              ),
              Text('Ürünleri Seç'),
              if (showRadioButtons)
                ElevatedButton(
                  onPressed: () {
                    if (_isConnected) {
                      showProcessDialog();
                    } else {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Bağlantı Sorunu'),
                            content: Text('İnternet bağlantısı yok, işlem gerçekleştirilemiyor.'),
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
                  },
                  child: Text('İşle'),
                ),



              if (showRadioButtons)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedIndexes.addAll(List.generate(customerProducts.length, (index) => index));
                    });
                  },
                  child: Text('Hepsini Seç'),
                ),
              if (showRadioButtons)
                ElevatedButton(
                  onPressed: () {
                    if (_isConnected) {
                      // İnternet varsa fonksiyonu çağır
                      processSelectedProductsToAccountTracking();
                    } else {
                      // İnternet yoksa uyarı göster
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Bağlantı Sorunu'),
                            content: Text('İnternet bağlantısı yok, işlem gerçekleştirilemiyor.'),
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
                  },
                  child: Text('Cari Hesaba İşle'),
                ),



            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: generatePDF,
                child: Text('PDF Oluştur'),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: generateExcel,
                child: Text('Excel\'e Çevir'),
              ),
            ],
          ),
        ),
        if (showRadioButtons)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (_isConnected) {
                          showKitCreationDialog();
                        } else {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Bağlantı Sorunu'),
                                content: Text('İnternet bağlantısı yok, işlem gerçekleştirilemiyor.'),
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
                      },
                      child: Text('Kit Oluştur'),
                    ),


                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_isConnected) {
                          showKitAssignmentDialog();
                        } else {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Bağlantı Sorunu'),
                                content: Text('İnternet bağlantısı yok, işlem gerçekleştirilemiyor.'),
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
                      },
                      child: Text('Kit Eşleştir'),
                    ),


                  ],
                ),
              ),
              // Diğer butonlarınız...
            ],
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showInfoButtons = !showInfoButtons;
                  });
                },
                child: Text(showInfoButtons ? 'Bilgileri Gizle' : 'Bilgileri Göster +'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  if (showRadioButtons) DataColumn(label: Container()), // Boş başlık sütunu eklendi
                  DataColumn(label: Text('Kodu')),
                  DataColumn(label: Text('Detay')),
                  DataColumn(label: Text('Adet')),
                  DataColumn(label: Text('Adet Fiyatı')),
                  DataColumn(label: Text('İskonto')),
                  DataColumn(label: Text('Toplam Fiyat')),
                  DataColumn(label: Text('Düzenle')),
                  DataColumn(label: Text('Bilgi')),
                ],
                rows: customerProducts.map((product) {
                  int index = customerProducts.indexOf(product);
                  bool isTotalRow = product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
                      product['Adet Fiyatı']?.toString() == 'KDV %20' ||
                      product['Adet Fiyatı']?.toString() == 'Genel Toplam';

                  return DataRow(
                    cells: [
                      if (showRadioButtons)
                        DataCell(
                          Checkbox(
                            value: selectedIndexes.contains(index),
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedIndexes.add(index);
                                } else {
                                  selectedIndexes.remove(index);
                                }
                              });
                            },
                          ),
                        ),
                      DataCell(Text(product['Kodu']?.toString() ?? '')),
                      DataCell(Text(product['Detay']?.toString() ?? '')),

                      // Adet hücresi
                      DataCell(
                        isTotalRow
                            ? Text(product['Adet']?.toString() ?? '') // Toplam satırları kontrol etmek için
                            : Row(
                          children: [
                            isEditing && editingIndex == index
                                ? Expanded(
                              child: TextField(
                                controller: quantityController, // Adet için controller
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Adet',
                                ),
                                onChanged: (value) {
                                  updateQuantity(index, value); // Adet güncellenmesi
                                },
                                onSubmitted: (value) {
                                  showExplanationDialog(index, true, false); // Açıklama girilmesi
                                },
                              ),
                            )
                                : Text(product['Adet']?.toString() ?? ''),
                            if (product['Adet Açıklaması'] != null) // Sadece adet değiştiyse buton göster
                              IconButton(
                                icon: Icon(Icons.info, color: Colors.blue),
                                onPressed: () {
                                  showInfoDialogForProduct(product); // Doğru fonksiyon adı burada çağrılıyor
                                },
                              ),
                          ],
                        ),
                      ),

                      // Adet Fiyatı hücresi
                      DataCell(
                        isTotalRow
                            ? Text(product['Adet Fiyatı']?.toString() ?? '')
                            : Row(
                          children: [
                            isEditing && editingIndex == index
                                ? Expanded(
                              child: TextField(
                                controller: priceController, // Adet Fiyatı için controller
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Adet Fiyatı',
                                ),
                                onChanged: (value) {
                                  updatePrice(index, value); // Adet Fiyatı güncellenmesi
                                },
                                onSubmitted: (value) {
                                  showExplanationDialog(index, false, true); // Açıklama girilmesi
                                },
                              ),
                            )
                                : Text(product['Adet Fiyatı']?.toString() ?? ''),
                            if (product['Fiyat Açıklaması'] != null) // Sadece fiyat değiştiyse buton göster
                              IconButton(
                                icon: Icon(Icons.info, color: Colors.blue),
                                onPressed: () {
                                  showInfoDialogForProduct(product); // Doğru fonksiyon adı burada çağrılıyor
                                },
                              ),
                          ],
                        ),
                      ),

                      DataCell(Text(product['İskonto']?.toString() ?? '')),
                      DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),

                      // Düzenle hücresi
                      DataCell(
                        isTotalRow
                            ? Container()
                            : IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              isEditing = true;
                              editingIndex = index;
                              originalProductData = Map<String, dynamic>.from(product);
                              quantityController.text = product['Adet']?.toString() ?? '';
                              priceController.text = product['Adet Fiyatı']?.toString() ?? ''; // Adet fiyatı için
                            });
                          },
                        ),
                      ),

                      // Bilgi butonlarını kontrol eden hücre
                      DataCell(
                        buildInfoButton(product), // Bilgi butonları sadece değişiklik yapılırsa görünecek
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),

      ],
    );
  }
}