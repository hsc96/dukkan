import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'products_pdf.dart';


class ProductsWidget extends StatefulWidget {
  final String customerName;

  ProductsWidget({required this.customerName});

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



  @override
  void initState() {
    super.initState();
    fetchCustomerProducts();
    fetchKits();
  }


  void generatePDF() {
    List<Map<String, dynamic>> selectedProducts = selectedIndexes.map((index) => customerProducts[index]).toList();
    ProductsPDF.generateProductsPDF(selectedProducts, true);
  }

  Future<void> fetchCustomerProducts() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('customerDetails')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      setState(() {
        customerProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
      });
      updateTotalAndVat();
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
      customerProducts[index]['Adet'] = quantity;
      customerProducts[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);
    });
  }

  void updatePrice(int index, String price) {
    setState(() {
      double adet = double.tryParse(customerProducts[index]['Adet']?.toString() ?? '1') ?? 1;
      double priceValue = double.tryParse(price) ?? 0.0;
      customerProducts[index]['Adet Fiyatı'] = price;
      customerProducts[index]['Toplam Fiyat'] = (adet * priceValue).toStringAsFixed(2);
    });
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
                    saveEditsToDatabase(index);
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

    if (!showInfoButtons || (!hasQuoteInfo && !hasKitInfo && !hasSalesInfo && !hasExpectedInfo)) {
      return Container();
    }

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
              Text('Ürünü Kim Aldı: ${product['whoTook'] ?? 'N/A'}'),
              if (product['whoTook'] == 'Müşterisi') ...[
                Text('Müşteri İsmi: ${product['recipient'] ?? 'N/A'}'),
                Text('Firmadan Bilgilendirilecek Kişi İsmi: ${product['contactPerson'] ?? 'N/A'}'),
              ],
              if (product['whoTook'] == 'Kendi Firması')
                Text('Teslim Alan Çalışan İsmi: ${product['recipient'] ?? 'N/A'}'),
              Text('Sipariş Şekli: ${product['orderMethod'] ?? 'N/A'}'),
              Text('Tarih: ${product['siparisTarihi'] ?? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}'),
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 20),
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
                  onPressed: showProcessDialog,
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
            ],
          ),
        ),
        if (showRadioButtons)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: showKitCreationDialog,
                  child: Text('Kit Oluştur'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: showKitAssignmentDialog,
                  child: Text('Kit Eşleştir'),
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
                  DataColumn(label: Text('')),
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

                  return DataRow(cells: [
                    DataCell(
                      showRadioButtons && !isTotalRow
                          ? Checkbox(
                        value: selectedIndexes.contains(index),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedIndexes.add(index);
                            } else {
                              selectedIndexes.remove(index);
                            }
                          });
                        },
                      )
                          : Container(),
                    ),
                    DataCell(Text(product['Kodu']?.toString() ?? '')),
                    DataCell(Text(product['Detay']?.toString() ?? '')),
                    DataCell(
                      isTotalRow
                          ? Text('')
                          : Row(
                        children: [
                          isEditing && editingIndex == index
                              ? Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Adet',
                              ),
                              onChanged: (value) {
                                updateQuantity(index, value);
                              },
                              onSubmitted: (value) {
                                showExplanationDialog(index, true, false);
                              },
                            ),
                          )
                              : Row(
                            children: [
                              Text(product['Adet']?.toString() ?? ''),
                              if (product['Adet Açıklaması'] != null)
                                IconButton(
                                  icon: Icon(Icons.info, color: Colors.blue),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Adet Değişikliği Bilgisi'),
                                          content: Text(
                                              'Açıklama: ${product['Adet Açıklaması']}\nDeğiştiren: ${product['Değiştiren']}\nEski Adet: ${product['Eski Adet']}\nİşlem Tarihi: ${product['İşlem Tarihi']}'),
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
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      isTotalRow
                          ? Text(product['Adet Fiyatı']?.toString() ?? '')
                          : Row(
                        children: [
                          isEditing && editingIndex == index
                              ? Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Adet Fiyatı',
                              ),
                              onChanged: (value) {
                                updatePrice(index, value);
                              },
                              onSubmitted: (value) {
                                showExplanationDialog(index, false, true);
                              },
                            ),
                          )
                              : Row(
                            children: [
                              Text(product['Adet Fiyatı']?.toString() ?? ''),
                              if (product['Fiyat Açıklaması'] != null)
                                IconButton(
                                  icon: Icon(Icons.info, color: Colors.blue),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Fiyat Değişikliği Bilgisi'),
                                          content: Text(
                                              'Açıklama: ${product['Fiyat Açıklaması']}\nDeğiştiren: ${product['Değiştiren']}\nEski Fiyat: ${product['Eski Fiyat']}\nİşlem Tarihi: ${product['İşlem Tarihi']}'),
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
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(product['İskonto']?.toString() ?? '')),
                    DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                    DataCell(
                      isTotalRow
                          ? Container()
                          : Row(
                        children: [
                          if (isEditing && editingIndex == index)
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.check, color: Colors.green),
                                  onPressed: () {
                                    if (quantityController.text.isNotEmpty || priceController.text.isNotEmpty) {
                                      showExplanationDialog(index, quantityController.text.isNotEmpty, priceController.text.isNotEmpty);
                                    } else {
                                      saveEditsToDatabase(index);
                                      updateTotalAndVat();
                                      originalProductData = null;
                                      setState(() {
                                        isEditing = false;
                                        editingIndex = -1;
                                      });
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      customerProducts[index] = originalProductData!;
                                      originalProductData = null;
                                      isEditing = false;
                                      editingIndex = -1;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => removeProduct(index),
                                ),
                              ],
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                setState(() {
                                  isEditing = true;
                                  editingIndex = index;
                                  originalProductData = Map<String, dynamic>.from(product);
                                  quantityController.text = product['Adet']?.toString() ?? '';
                                  priceController.text = product['Adet Fiyatı']?.toString() ?? '';
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      buildInfoButton(product),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}