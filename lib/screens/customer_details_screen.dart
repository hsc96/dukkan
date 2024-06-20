import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'pdf_template.dart';
import 'processed_screen.dart'; // İşlenenler widgetını ekliyoruz.

class CustomerDetailsScreen extends StatefulWidget {
  final String customerName;

  CustomerDetailsScreen({required this.customerName});

  @override
  _CustomerDetailsScreenState createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  List<Map<String, dynamic>> customerProducts = [];
  List<Map<String, dynamic>> quotes = [];
  bool isEditing = false;
  int editingIndex = -1;
  Map<String, dynamic>? originalProductData;
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController explanationController = TextEditingController();
  bool showRadioButtons = false;
  Set<int> selectedIndexes = {};
  List<Map<String, dynamic>> mainKits = [];
  int currentIndex = 0;
  int? currentEditingKitIndex;
  int? currentEditingSubKitIndex;
  List<Map<String, dynamic>> tempProducts = [];
  List<Map<String, dynamic>> originalProducts = [];
  List<int> currentSelectedIndexes = [];
  Set<int> selectedQuoteIndexes = {};
  bool showSelectionButtons = false;
  int? selectedQuoteIndex;

  @override
  void initState() {
    super.initState();
    fetchCustomerProducts();
    fetchKits();
    fetchQuotes();
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

  Future<void> fetchQuotes() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('quotes')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    setState(() {
      quotes = querySnapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'quoteNumber': data['quoteNumber'] ?? '',
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    setState(() {
      if (subKitIndex == null) {
        mainKits[kitIndex]['products'].add({
          'Detay': product['Detay'] ?? '',
          'Kodu': product['Kodu'] ?? '',
          'Adet': '1',
        });
      } else {
        mainKits[kitIndex]['subKits'][subKitIndex]['products'].add({
          'Detay': product['Detay'] ?? '',
          'Kodu': product['Kodu'] ?? '',
          'Adet': '1',
        });
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
      currentSelectedIndexes = selectedIndexes.toList();
      selectedIndexes.clear();
      showRadioButtons = false;
    });
  }

  void createNewSubKit(int kitIndex, String subKitName) {
    setState(() {
      mainKits[kitIndex]['subKits'].add({
        'name': subKitName,
        'products': List.from(currentSelectedIndexes.map((index) {
          debugPrint('Eklenecek Ürün: ${customerProducts[index]}');
          return {
            'Detay': customerProducts[index]['Detay'],
            'Kodu': customerProducts[index]['Kodu'],
            'Adet': customerProducts[index]['Adet'],
          };
        })),
      });
      currentSelectedIndexes.clear();
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
                  debugPrint('Alt Kit İsmi Girildi: ${subKitNameController.text}');
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
          debugPrint('Eklenecek Ürün: ${customerProducts[index]}');
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

  void showEditDialogForQuoteProduct(int quoteIndex, int productIndex) {
    var quoteProduct = quotes[quoteIndex]['products'][productIndex];
    quantityController.text = quoteProduct['Adet']?.toString() ?? '';
    priceController.text = quoteProduct['Adet Fiyatı']?.toString() ?? '';
    originalProductData = Map<String, dynamic>.from(quoteProduct);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ürün Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: InputDecoration(labelText: 'Adet'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    quoteProduct['Adet'] = value;
                  });
                },
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Adet Fiyatı'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    quoteProduct['Adet Fiyatı'] = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  quoteProduct = originalProductData!;
                  originalProductData = null;
                });
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                showExplanationDialogForQuoteProduct(quoteIndex, productIndex);
              },
              child: Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  void showExplanationDialogForQuoteProduct(int quoteIndex, int productIndex) {
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
                    var quoteProduct = quotes[quoteIndex]['products'][productIndex];
                    if (quantityController.text.isNotEmpty) {
                      quoteProduct['Adet Açıklaması'] = explanationController.text;
                      quoteProduct['Eski Adet'] = originalProductData?['Adet']?.toString();
                      quoteProduct['Adet'] = quantityController.text;
                    }
                    if (priceController.text.isNotEmpty) {
                      quoteProduct['Fiyat Açıklaması'] = explanationController.text;
                      quoteProduct['Eski Fiyat'] = originalProductData?['Adet Fiyatı']?.toString();
                      quoteProduct['Adet Fiyatı'] = priceController.text;
                    }
                    updateTotalAndVatForQuote(quoteIndex); // Toplam ve KDV'yi güncelle
                    saveQuoteToDatabase(quoteIndex); // Veritabanına kaydet
                    originalProductData = null;
                  });
                  Navigator.of(context).pop();
                  setState(() {
                    isEditing = false; // Düzenleme modunu kapat
                    editingIndex = -1;
                  });
                }
              },
              child: Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  void updateTotalAndVatForQuote(int quoteIndex) {
    double toplamTutar = 0.0;
    var quoteProducts = quotes[quoteIndex]['products'] as List<Map<String, dynamic>>;

    for (var product in quoteProducts) {
      if (product['Kodu']?.toString() != '' && product['Toplam Fiyat']?.toString() != '') {
        toplamTutar += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      }
    }

    double kdv = toplamTutar * 0.20;
    double genelToplam = toplamTutar + kdv;

    setState(() {
      quoteProducts.removeWhere((product) =>
      product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
          product['Adet Fiyatı']?.toString() == 'KDV %20' ||
          product['Adet Fiyatı']?.toString() == 'Genel Toplam');

      quoteProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Toplam Tutar',
        'Toplam Fiyat': toplamTutar.toStringAsFixed(2),
      });
      quoteProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'KDV %20',
        'Toplam Fiyat': kdv.toStringAsFixed(2),
      });
      quoteProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Genel Toplam',
        'Toplam Fiyat': genelToplam.toStringAsFixed(2),
      });

      quotes[quoteIndex]['products'] = quoteProducts;
    });
  }

  Future<void> saveQuoteToDatabase(int quoteIndex) async {
    var quoteCollection = FirebaseFirestore.instance.collection('quotes');
    var quote = quotes[quoteIndex];
    var docRef = quoteCollection.doc(quote['id']);

    await docRef.update({
      'products': quote['products'],
    });
  }

  void saveQuoteAsPDF(int quoteIndex) async {
    var quote = quotes[quoteIndex];
    var quoteProducts = quote['products'] as List<Map<String, dynamic>>;

    final pdf = await PDFTemplate.generateQuote(
      widget.customerName,
      quoteProducts,
      double.tryParse(quoteProducts.lastWhere((product) => product['Adet Fiyatı'] == 'Toplam Tutar')['Toplam Fiyat']) ?? 0.0,
      double.tryParse(quoteProducts.lastWhere((product) => product['Adet Fiyatı'] == 'KDV %20')['Toplam Fiyat']) ?? 0.0,
      double.tryParse(quoteProducts.lastWhere((product) => product['Adet Fiyatı'] == 'Genel Toplam')['Toplam Fiyat']) ?? 0.0,
      '', // Teslim tarihi
      '', // Teklif süresi
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${widget.customerName}_teklif_${quote['quoteNumber']}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }

  void convertQuoteToOrder(int quoteIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Teklif Siparişe Dönüştür'),
          content: Text('Teklifiniz sipariş olacaktır. Onaylıyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showOrderNumberDialog(quoteIndex);
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  void showOrderNumberDialog(int quoteIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        TextEditingController orderNumberController = TextEditingController();
        return AlertDialog(
          title: Text('Sipariş Numarası Girin'),
          content: TextField(
            controller: orderNumberController,
            decoration: InputDecoration(hintText: 'Sipariş Numarası (Opsiyonel)'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                finalizeOrderConversion(quoteIndex, orderNumberController.text);
              },
              child: Text('Kaydet'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                finalizeOrderConversion(quoteIndex, null);
              },
              child: Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  void finalizeOrderConversion(int quoteIndex, String? orderNumber) {
    setState(() {
      var quoteProducts = quotes[quoteIndex]['products'] as List<Map<String, dynamic>>;
      for (var product in quoteProducts) {
        if (product['Kodu']?.toString() != '') {
          var productCopy = Map<String, dynamic>.from(product);
          productCopy['Teklif Numarası'] = quotes[quoteIndex]['quoteNumber'];
          productCopy['Sipariş Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());
          productCopy['Sipariş Numarası'] = orderNumber ?? 'Sipariş Numarası Girilmedi';
          customerProducts.add(productCopy);
        }
      }
      updateTotalAndVat();
      saveEditsToDatabase(0);
      selectedQuoteIndexes.clear();
      showSelectionButtons = false;
    });
  }

  void toggleSelectAllProducts(int quoteIndex) {
    setState(() {
      var quoteProducts = quotes[quoteIndex]['products'] as List<Map<String, dynamic>>;
      if (selectedQuoteIndexes.length == quoteProducts.length && selectedQuoteIndex == quoteIndex) {
        selectedQuoteIndexes.clear();
      } else {
        selectedQuoteIndexes = Set<int>.from(Iterable<int>.generate(quoteProducts.length));
        selectedQuoteIndex = quoteIndex;
      }
    });
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
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }

  void showProcessDialog() {
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

  Future<void> processSelectedProducts(String processName) async {
    var selectedProducts = selectedIndexes.map((index) => customerProducts[index]).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBar(title: 'Müşteri Detayları - ${widget.customerName}'),
        drawer: CustomDrawer(),
        body: Column(
            children: [
            SizedBox(height: 20),
        ToggleButtons(
          isSelected: [currentIndex == 0, currentIndex == 1, currentIndex == 2, currentIndex == 3], // Yeni butonu ekliyoruz
          onPressed: (int index) {
            setState(() {
              currentIndex = index;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Ürünler'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Kitler'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Teklifler'),
            ),
            Padding( // Yeni buton
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('İşlenenler'),
            ),
          ],
        ),
        if (currentIndex == 0) ...[
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
    IconButton(
    icon: Icon(showRadioButtons ? Icons.remove : Icons.add, color: colorTheme5),
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
    DataCell(
    Row(
    children: [
    if (!isTotalRow && product['siparisTarihi'] != null)
    IconButton(
    icon: Icon(Icons.info, color: Colors.orange),
    onPressed: () {
    showDialog(
    context: context,
    builder: (BuildContext context) {
    return AlertDialog(
    title: Text('Sipariş Bilgisi'),
    content: Text(
    'Sipariş Tarihi: ${product['siparisTarihi']}\n'
    'Kim Aldı: ${product['whoTook'] ?? 'Bilinmiyor'}\n'
    'Alıcı: ${product['recipient'] ?? 'Bilinmiyor'}\n'
    'İletişim Kişisi: ${product['contactPerson'] ?? 'Bilinmiyor'}\n'
    'Sipariş Şekli: ${product['orderMethod'] ?? 'Bilinmiyor'}',
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
    },
    ),
    Text(product['Kodu']?.toString() ?? ''),
    ],
    ),
    ),
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
    ]);
    }).toList()
    ..add(
    DataRow(cells: [
    DataCell(Container()),
    DataCell(Container()),
    DataCell(Container()),
    DataCell(Container()),
    DataCell(Container()),
    DataCell(Container()),
    DataCell(Container()),
    DataCell(
    showRadioButtons
    ? ElevatedButton(
    onPressed: showKitCreationDialog,
    child: Text('Kit Oluştur'),
    )
        : Container(),
    ),
    ]),
    ),
    ),
    ),
    ),
    ),
    ],
    if (currentIndex == 1) Expanded(child: buildKitsList()),
    if (currentIndex == 2)
    Expanded(
    child: ListView.builder(
    itemCount: quotes.length,
    itemBuilder: (context, index) {
    var quote = quotes[index];
    return ExpansionTile(
    title: Text('Teklif No: ${quote['quoteNumber']}'),
    subtitle: Text('Tarih: ${DateFormat('dd MMMM yyyy').format(quote['date'])}'),
    children: [
    SingleChildScrollView(
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
    ],
    rows: (quote['products'] as List<dynamic>).map((product) {
    int productIndex = quote['products'].indexOf(product);
    bool isTotalRow = product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
    product['Adet Fiyatı']?.toString() == 'KDV %20' ||
    product['Adet Fiyatı']?.toString() == 'Genel Toplam';

    return DataRow(cells: [
    DataCell(
    !isTotalRow
    ? Checkbox(
    value: selectedQuoteIndexes.contains(productIndex) && selectedQuoteIndex == index,
    onChanged: (bool? value) {
    setState(() {
    if (value == true) {
    selectedQuoteIndexes.add(productIndex);
    selectedQuoteIndex = index;
    } else {
    selectedQuoteIndexes.remove(productIndex);
    if (selectedQuoteIndexes.isEmpty) {
    selectedQuoteIndex = null;
    }
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
    isEditing && editingIndex == productIndex
    ? Expanded(
    child: TextField(
    controller: quantityController,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
    hintText: 'Adet',
    ),
    onChanged: (value) {
    setState(() {
    product['Adet'] = value;
    });
    },
    onSubmitted: (value) {
    showExplanationDialogForQuoteProduct(index, productIndex);
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
    isEditing && editingIndex == productIndex
    ? Expanded(
    child: TextField(
    controller: priceController,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
    hintText: 'Adet Fiyatı',
    ),
    onChanged: (value) {
    setState(() {
    product['Adet Fiyatı'] = value;
    });
    },
    onSubmitted: (value) {
    showExplanationDialogForQuoteProduct(index, productIndex);
    },
    ),
    )
        : Row(
    children: [
    Text(product['Adet Fiyatı']?.toString() ?? ''),
    if (product['Fiyat Açıklaması'] != null)
    IconButton(
    icon: Icon(Icons.info,                                              color: Colors.blue),
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
        !isTotalRow
            ? IconButton(
          icon: Icon(Icons.edit, color: Colors.blue),
          onPressed: () {
            setState(() {
              isEditing = true;
              editingIndex = productIndex;
              originalProductData = Map<String, dynamic>.from(product);
              quantityController.text = product['Adet']?.toString() ?? '';
              priceController.text = product['Adet Fiyatı']?.toString() ?? '';
            });
          },
        )
            : Container(),
      ),
    ]);
    }).toList(),
    ),
    ),
      Row(
        children: [
          TextButton(
            onPressed: () {
              toggleSelectAllProducts(index);
            },
            child: Text('Hepsini Seç'),
          ),
          Spacer(),
          TextButton(
            onPressed: () => saveQuoteAsPDF(index),
            child: Text('PDF Olarak Kaydet'),
          ),
          TextButton(
            onPressed: () => convertQuoteToOrder(index),
            child: Text('Siparişe Dönüştür'),
          ),
        ],
      )
    ],
    );
    },
    ),
    ),
              if (currentIndex == 3) Expanded(child: ProcessedWidget(customerName: widget.customerName)),
            ],
        ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}

