import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';
import 'package:intl/intl.dart'; // Tarih formatı için eklendi
import 'package:barcode_scan2/barcode_scan2.dart';
import 'dart:io'; // Dosya işlemleri için
import 'package:path_provider/path_provider.dart'; // Dosya yolları için
import 'package:pdf/widgets.dart' as pw; // PDF işlemleri için
import 'package:open_file/open_file.dart'; // Dosya açma işlemleri için
import 'pdf_template.dart'; // PDF şablonu için

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
        .where('customerName', isEqualTo: widget.customerName) // Yalnızca ilgili müşteri için kitleri getir
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
          'date': data['date'] ?? '',
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

  void handleEdit(int index, String type) {
    if (type == 'Adet') {
      updateQuantity(index, quantityController.text);
    } else if (type == 'Fiyat') {
      updatePrice(index, priceController.text);
    }
    showExplanationDialog(index, type);
  }

  void showExplanationDialog(int index, String type) {
    showDialog(
      context: context,
      barrierDismissible: false, // Dialog ekranı bilgi girilmeden kapanmasın
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$type Değişikliği Açıklaması'),
          content: TextField(
            controller: explanationController,
            decoration: InputDecoration(hintText: '$type değişikliği nedeni'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  customerProducts[index] = originalProductData!;
                  originalProductData = null;
                  isEditing = false;
                  editingIndex = -1;
                });
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (explanationController.text.isNotEmpty) {
                  setState(() {
                    if (type == 'Adet') {
                      customerProducts[index]['Adet Açıklaması'] = explanationController.text;
                      customerProducts[index]['Değiştiren'] = 'admin';
                      customerProducts[index]['Eski Adet'] = originalProductData?['Adet']?.toString();
                      customerProducts[index]['İşlem Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());
                    } else if (type == 'Fiyat') {
                      customerProducts[index]['Fiyat Açıklaması'] = explanationController.text;
                      customerProducts[index]['Değiştiren'] = 'admin';
                      customerProducts[index]['Eski Fiyat'] = originalProductData?['Adet Fiyatı']?.toString();
                      customerProducts[index]['İşlem Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());
                    }
                    saveEditsToDatabase(index);
                    updateTotalAndVat();
                    isEditing = false;
                    editingIndex = -1;
                    originalProductData = null;
                    explanationController.clear(); // Dialog kapandıktan sonra açıklama alanını temizle
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
      if (products.length > 1) {
        showProductSelectionDialog(products, kitIndex, subKitIndex: subKitIndex);
      } else {
        addProductToKit(products.first, kitIndex, subKitIndex: subKitIndex);
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
        // Yeni kit ekle
        var newKitDocRef = kitlerCollection.doc();
        await newKitDocRef.set({
          'name': kit['name'],
          'subKits': kit['subKits'],
          'products': kit['products'],
          'customerName': widget.customerName, // Her kit müşteriye özel olacak
        });
        kit['id'] = newKitDocRef.id; // Yeni kitin ID'sini kaydet
      } else {
        // Mevcut kiti güncelle
        await kitlerCollection.doc(kitId).update({
          'name': kit['name'],
          'subKits': kit['subKits'],
          'products': kit['products'],
          'customerName': widget.customerName, // Her kit müşteriye özel olacak
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
      currentSelectedIndexes = selectedIndexes.toList(); // Mevcut seçili ürünlerin indekslerini kaydet
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
      currentSelectedIndexes.clear(); // Alt kit oluşturulduktan sonra seçili ürünleri temizle
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
      selectedIndexes.clear(); // Alt kit oluşturulduktan sonra seçili ürünleri temizle
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
                readOnly: true,
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Adet Fiyatı'),
                keyboardType: TextInputType.number,
                readOnly: true,
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
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Uyarı'),
                      content: Text('Tekliften gelen ürünlerin adet veya fiyat bilgisi değiştirilemez.'),
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
              child: Text('Sil'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  quoteProduct = originalProductData!;
                  originalProductData = null;
                });
                Navigator.of(context).pop();
              },
              child: Text('Kapat'),
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
          if (selectedQuoteIndexes.contains(quoteProducts.indexOf(product))) {
            var productCopy = Map<String, dynamic>.from(product);
            productCopy['Teklif Numarası'] = quotes[quoteIndex]['quoteNumber'];
            productCopy['Sipariş Tarihi'] = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now());
            productCopy['Sipariş Numarası'] = orderNumber ?? 'Sipariş Numarası Girilmedi';
            customerProducts.add(productCopy);
          }
        }
      }
      updateTotalAndVat();
      saveEditsToDatabase(0); // Veritabanını güncelle
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
          title: Text(kit['name']),
          children: [
            ...kit['subKits'].map<Widget>((subKit) {
              int subKitIndex = kit['subKits'].indexOf(subKit);
              return ExpansionTile(
                title: Text(subKit['name']),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Müşteri Detayları - ${widget.customerName}'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          ToggleButtons(
            isSelected: [currentIndex == 0, currentIndex == 1, currentIndex == 2],
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
                              Text(product['Kodu']?.toString() ?? ''),
                              if (product['Teklif Numarası'] != null)
                                IconButton(
                                  icon: Icon(Icons.info, color: Colors.blue),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Teklif Bilgisi'),
                                          content: Text(
                                              'Teklif Numarası: ${product['Teklif Numarası']}\nSiparişe Çeviren Kişi: ${product['Siparişe Çeviren Kişi'] ?? 'admin'}\nSiparişe Çevrilme Tarihi: ${product['Sipariş Tarihi']}\nSipariş Numarası: ${product['Sipariş Numarası']}'),
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
                        ),
                        DataCell(Text(product['Detay']?.toString() ?? '')),
                        DataCell(
                          isTotalRow
                              ? Text('')
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
                        ),
                        DataCell(
                          isTotalRow
                              ? Text(product['Adet Fiyatı']?.toString() ?? '')
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
                        ),
                        DataCell(Text(product['İskonto']?.toString() ?? '')),
                        DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                        DataCell(
                          isTotalRow
                              ? Container()
                              : Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  if (product['Teklif Numarası'] == null) {
                                    setState(() {
                                      isEditing = true;
                                      editingIndex = index;
                                      originalProductData = Map<String, dynamic>.from(product);
                                      quantityController.text = product['Adet']?.toString() ?? '';
                                      priceController.text = product['Adet Fiyatı']?.toString() ?? '';
                                    });
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Uyarı'),
                                          content: Text('Tekliften gelen ürünlerin adet veya fiyat bilgisi değiştirilemez.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  isEditing = true;
                                                  editingIndex = index;
                                                  originalProductData = Map<String, dynamic>.from(product);
                                                });
                                                Navigator.of(context).pop();
                                              },
                                              child: Text('Tamam'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                              if (isEditing && editingIndex == index)
                                Row(
                                  children: [
                                    if (product['Teklif Numarası'] != null)
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => removeProduct(index),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          customerProducts[index] = originalProductData!;
                                          originalProductData = null;
                                          isEditing = false;
                                          editingIndex = -1;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              if (isEditing && editingIndex == index && product['Teklif Numarası'] == null)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => removeProduct(index),
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
                    subtitle: Text('Tarih: ${DateFormat('dd MMMM yyyy').format(quote['date'].toDate())}'),
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
                                Row(
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
                              ),
                              DataCell(
                                Row(
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
                              ),
                              DataCell(Text(product['İskonto']?.toString() ?? '')),
                              DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                              DataCell(
                                !isTotalRow
                                    ? IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => showEditDialogForQuoteProduct(index, productIndex),
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
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
