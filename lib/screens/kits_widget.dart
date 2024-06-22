import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:intl/intl.dart';
import 'dovizservice.dart';
import 'firestore_service.dart';

class KitsWidget extends StatefulWidget {
  final String customerName;

  KitsWidget({required this.customerName});

  @override
  _KitsWidgetState createState() => _KitsWidgetState();
}

class _KitsWidgetState extends State<KitsWidget> {
  List<Map<String, dynamic>> mainKits = [];
  int? currentEditingKitIndex;
  int? currentEditingSubKitIndex;
  List<Map<String, dynamic>> tempProducts = [];
  List<Map<String, dynamic>> originalProducts = [];
  String dolarKur = '';
  String euroKur = '';
  final FirestoreService firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    fetchKits();
    fetchDovizKur();
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
                                saveKitsToFirestore();
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
                      onPressed: () => scanBarcodeForKit(currentEditingKitIndex!, subKitIndex: currentEditingSubKitIndex, dialogSetState: setState),
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

  Future<void> scanBarcodeForKit(int kitIndex, {int? subKitIndex, StateSetter? dialogSetState}) async {
    try {
      var result = await BarcodeScanner.scan();
      var barcode = result.rawContent;
      fetchProductDetailsForKit(barcode, kitIndex, subKitIndex: subKitIndex, dialogSetState: dialogSetState);
    } catch (e) {
      setState(() {
        print('Barkod tarama hatası: $e');
      });
    }
  }

  Future<void> fetchProductDetailsForKit(String barcode, int kitIndex, {int? subKitIndex, StateSetter? dialogSetState}) async {
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
        showProductSelectionDialog(uniqueProductList, kitIndex, subKitIndex: subKitIndex, dialogSetState: dialogSetState);
      } else {
        addProductToKit(uniqueProductList.first, kitIndex, subKitIndex: subKitIndex, dialogSetState: dialogSetState);
      }
    } else {
      setState(() {
        print('Ürün bulunamadı.');
      });
    }
  }

  void showProductSelectionDialog(List<Map<String, dynamic>> products, int kitIndex, {int? subKitIndex, StateSetter? dialogSetState}) {
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
                    addProductToKit(products[index], kitIndex, subKitIndex: subKitIndex, dialogSetState: dialogSetState);
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

  void addProductToKit(Map<String, dynamic> product, int kitIndex, {int? subKitIndex, StateSetter? dialogSetState}) {
    if (subKitIndex == null) {
      setState(() {
        mainKits[kitIndex]['products'].add({
          'Detay': product['Detay'] ?? '',
          'Kodu': product['Kodu'] ?? '',
          'Adet': '1',
        });
      });
      print('Product added to main kit: ${product['Kodu']}');
    } else {
      dialogSetState!(() {
        tempProducts.add({
          'Detay': product['Detay'] ?? '',
          'Kodu': product['Kodu'] ?? '',
          'Adet': '1',
        });
      });
      print('Product added to sub kit: ${product['Kodu']}');
    }
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

  Future<void> applyDiscountToProduct(Map<String, dynamic> productData, String brand, String discountLevel) async {
    double priceInTl = 0.0;
    double price = 0.00;
    if (productData['Fiyat'] is String) {
      price = double.tryParse(productData['Fiyat']) ?? 0.0;
    } else if (productData['Fiyat'] is num) {
      price = productData['Fiyat'].toDouble();
    }

    print('Price: $price, Currency: ${productData['Doviz']}');

    String currency = productData['Doviz']?.toString() ?? '';

    if (currency == 'Euro') {
      priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
    } else {
      priceInTl = price;
    }

    productData['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);

    print('Price in TL: $priceInTl');

    if (discountLevel.isNotEmpty) {
      var discountData = await firestoreService.getDiscountRates(discountLevel, brand);
      double discountRate = discountData['rate'] ?? 0.0;
      double discountedPrice = priceInTl * (1 - (discountRate / 100));

      productData['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
      productData['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
      productData['Toplam Fiyat'] = (discountedPrice * (double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1)).toStringAsFixed(2);
    } else {
      productData['İskonto'] = '0%';
      productData['Toplam Fiyat'] = (priceInTl * (double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1)).toStringAsFixed(2);
    }
  }

  Future<void> processKit(int kitIndex, {int? subKitIndex}) async {
    List<Map<String, dynamic>> productsToProcess = [];
    if (subKitIndex == null) {
      productsToProcess = List.from(mainKits[kitIndex]['products']);
      for (var subKit in mainKits[kitIndex]['subKits']) {
        productsToProcess.addAll(List.from(subKit['products']));
      }
    } else {
      productsToProcess = List.from(mainKits[kitIndex]['subKits'][subKitIndex]['products']);
    }

    var customerCollection = FirebaseFirestore.instance.collection('customerDetails');
    var querySnapshot = await customerCollection.where('customerName', isEqualTo: widget.customerName).get();

    var productsCollection = FirebaseFirestore.instance.collection('urunler');

    var customerDiscount = await firestoreService.getCustomerDiscount(widget.customerName);
    String discountLevel = customerDiscount['iskonto'] ?? '';

    List<Map<String, dynamic>> processedProducts = [];

    for (var product in productsToProcess) {
      var productQuerySnapshot = await productsCollection.where('Kodu', isEqualTo: product['Kodu']).get();
      if (productQuerySnapshot.docs.isNotEmpty) {
        var productData = productQuerySnapshot.docs.first.data();

        double priceInTl = 0.0;
        double price = 0.0;
        if (productData['Fiyat'] is String) {
          price = double.tryParse(productData['Fiyat']) ?? 0.0;
        } else if (productData['Fiyat'] is num) {
          price = productData['Fiyat'].toDouble();
        }

        String currency = productData['Doviz']?.toString() ?? '';

        if (currency == 'Euro') {
          priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
        } else if (currency == 'Dolar') {
          priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
        } else {
          priceInTl = price;
        }

        double adet = double.tryParse(product['Adet']?.toString() ?? '1') ?? 1;

        if (discountLevel.isNotEmpty) {
          var discountData = await firestoreService.getDiscountRates(discountLevel, productData['Marka'] ?? '');
          double discountRate = discountData['rate'] ?? 0.0;
          double discountedPrice = priceInTl * (1 - (discountRate / 100));
          product['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
          product['Toplam Fiyat'] = (discountedPrice * adet).toStringAsFixed(2);
          product['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
        } else {
          product['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);
          product['Toplam Fiyat'] = (priceInTl * adet).toStringAsFixed(2);
          product['İskonto'] = '0%';
        }

        processedProducts.add(product);
      }
    }

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      var existingProducts = List<Map<String, dynamic>>.from(querySnapshot.docs.first['products'] ?? []);

      existingProducts.addAll(processedProducts);

      await docRef.update({
        'products': existingProducts,
      });
    } else {
      await customerCollection.add({
        'customerName': widget.customerName,
        'products': processedProducts,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ürünler başarıyla işlendi')),
    );
  }



  Widget buildKitsList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: mainKits.length,
      itemBuilder: (context, index) {
        var kit = mainKits[index];

        return ExpansionTile(
          title: Row(
            children: [
              Text(kit['name']),
            ],
          ),
          children: [
            ...kit['subKits'].map<Widget>((subKit) {
              int subKitIndex = kit['subKits'].indexOf(subKit);

              return ExpansionTile(
                title: Row(
                  children: [
                    Text(subKit['name']),
                  ],
                ),
                children: [
                  ...subKit['products'].map<Widget>((product) {
                    return ListTile(
                      title: Text(product['Detay'] ?? ''),
                      subtitle: Text('Kodu: ${product['Kodu'] ?? ''}, Adet: ${product['Adet'] ?? ''}'),
                    );
                  }).toList(),
                  ListTile(
                    title: ElevatedButton(
                      onPressed: () => showEditSubKitDialog(index, subKitIndex),
                      child: Text('Düzenle'),
                    ),
                  ),
                  ListTile(
                    title: ElevatedButton(
                      onPressed: () => processKit(index, subKitIndex: subKitIndex),
                      child: Text('İşleme Al'),
                    ),
                  ),
                ],
              );
            }).toList(),
            ListTile(
              title: ElevatedButton(
                onPressed: () => processKit(index),
                child: Text('İşleme Al'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildKitsList();
  }
}
