import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';
import 'package:intl/intl.dart'; // Tarih formatı için eklendi
import 'package:barcode_scan2/barcode_scan2.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerName;

  CustomerDetailsScreen({required this.customerName});

  @override
  _CustomerDetailsScreenState createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  List<Map<String, dynamic>> customerProducts = [];
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

  @override
  void initState() {
    super.initState();
    fetchCustomerProducts();
    fetchKits();
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
        await kitlerCollection.add({
          'name': kit['name'],
          'customerName': widget.customerName, // Add the customer name
          'subKits': kit['subKits'],
          'products': kit['products'],
        });
      } else {
        // Mevcut kiti güncelle
        await kitlerCollection.doc(kitId).update({
          'name': kit['name'],
          'customerName': widget.customerName, // Add the customer name
          'subKits': kit['subKits'],
          'products': kit['products'],
        });
      }
    }
  }

  void createNewMainKit(String kitName) {
    setState(() {
      mainKits.add({
        'id': null,
        'name': kitName,
        'customerName': widget.customerName,
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
        'products': List.from(currentSelectedIndexes.map((index) => {
          'Detay': customerProducts[index]['Detay'],
          'Kodu': customerProducts[index]['Kodu'],
          'Adet': customerProducts[index]['Adet'],
        }))
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
                    Navigator.of(context).pop();
                    showSubKitCreationDialog(index);
                  },
                );
              },
            ),
          ),
        );
      },
    );
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
            isSelected: [currentIndex == 0, currentIndex == 1],
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
                        DataCell(Text(product['Kodu']?.toString() ?? '')),
                        DataCell(Text(product['Detay']?.toString() ?? '')),
                        DataCell(
                          isTotalRow
                              ? Text('')
                              : isEditing && editingIndex == index
                              ? TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              quantityController.text = value;
                            },
                            controller: quantityController..text = product['Adet']?.toString() ?? '',
                            onSubmitted: (value) {
                              handleEdit(index, 'Adet');
                            },
                            onEditingComplete: () {
                              handleEdit(index, 'Adet');
                            },
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
                        ),
                        DataCell(
                          isTotalRow
                              ? Text(product['Adet Fiyatı']?.toString() ?? '')
                              : isEditing && editingIndex == index
                              ? TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              priceController.text = value;
                            },
                            controller: priceController..text = product['Adet Fiyatı']?.toString() ?? '',
                            onSubmitted: (value) {
                              handleEdit(index, 'Fiyat');
                            },
                            onEditingComplete: () {
                              handleEdit(index, 'Fiyat');
                            },
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
                                  setState(() {
                                    isEditing = true;
                                    editingIndex = index;
                                    originalProductData = Map<String, dynamic>.from(product);
                                    quantityController.text = product['Adet']?.toString() ?? '';
                                    priceController.text = product['Adet Fiyatı']?.toString() ?? '';
                                  });
                                },
                              ),
                              if (isEditing && editingIndex == index)
                                Row(
                                  children: [
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
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
