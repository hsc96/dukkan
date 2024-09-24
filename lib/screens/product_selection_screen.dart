import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'dart:math'; // Random sayı üretmek için
import 'package:firebase_auth/firebase_auth.dart';

// Custom navigasyon bileşenlerini import ediyoruz
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class ProductSelectionScreen extends StatefulWidget {
  @override
  _ProductSelectionScreenState createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  Map<String, Map<String, dynamic>> productsByBrand = {};

  // Form ile ilgili kontroller ve değişkenler
  final _formKey = GlobalKey<FormState>();
  final TextEditingController anaBirimController = TextEditingController();
  final TextEditingController barkodController = TextEditingController();
  final TextEditingController detayController = TextEditingController();
  final TextEditingController fiyatController = TextEditingController();
  final TextEditingController gercekStokController = TextEditingController();
  final TextEditingController koduController = TextEditingController();
  final TextEditingController supplierController = TextEditingController(); // Kimden alındığı

  String? selectedDoviz; // Döviz için seçilen değer
  String? selectedMarka; // Marka için seçilen değer
  List<String> markaListesi = []; // Veritabanından çekilen marka listesi

  bool isAddingToExistingBox = false;
  bool isAddingToNewBox = false; // Yeni kutuya ekleme seçeneği

  @override
  void initState() {
    super.initState();
    fetchProductsByBrand();
    fetchMarkaListesi(); // Marka listesini çekiyoruz
  }

  Future<void> fetchMarkaListesi() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('urunler').get();
    Set<String> markaSeti = {};
    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['Marka'] != null && data['Marka'].toString().isNotEmpty) {
        markaSeti.add(data['Marka']);
      }
    }
    setState(() {
      markaListesi = markaSeti.toList();
    });
  }

  Future<void> fetchProductsByBrand() async {
    // Önce tüm markaları alıyoruz
    var brandsSnapshot = await FirebaseFirestore.instance.collection('urunler').get();

    Set<String> allBrands = {};
    for (var doc in brandsSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['Marka'] != null && data['Marka'].toString().isNotEmpty) {
        allBrands.add(data['Marka']);
      }
    }

    // Her markadan bir ürünü alıyoruz
    for (String brand in allBrands) {
      var productsSnapshot = await FirebaseFirestore.instance
          .collection('urunler')
          .where('Marka', isEqualTo: brand)
          .limit(1)
          .get();

      if (productsSnapshot.docs.isNotEmpty) {
        var doc = productsSnapshot.docs.first;
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Belge kimliğini ekliyoruz
        productsByBrand[brand] = data;
      }
    }

    setState(() {});
  }

  Widget buildProductList() {
    List<Widget> productTiles = [];

    productsByBrand.forEach((brand, product) {
      productTiles.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(product['Detay'] ?? ''),
              subtitle: Text('Marka: $brand\nKodu: ${product['Kodu']}'),
              onTap: () {
                // Ürün seçildiğinde form alanlarını dolduruyoruz
                setState(() {
                  anaBirimController.text = product['Ana Birim'] ?? '';
                  barkodController.text = ''; // Yeni ürün için barkod alanını boşaltıyoruz
                  detayController.text = product['Detay'] ?? '';
                  selectedDoviz = product['Doviz'] ?? '';
                  fiyatController.text = product['Fiyat'] ?? '';
                  gercekStokController.text = product['Gercek Stok'] ?? '';
                  koduController.text = product['Kodu'] ?? '';
                  selectedMarka = product['Marka'] ?? '';
                  isAddingToExistingBox = false;
                  isAddingToNewBox = false;
                });
              },
            ),
            Divider(),
          ],
        ),
      );
    });

    return ListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: productTiles,
    );
  }

  Future<void> scanBarcodeForExistingBox() async {
    try {
      var result = await BarcodeScanner.scan();
      var barcode = result.rawContent;

      if (barcode.isNotEmpty) {
        setState(() {
          barkodController.text = barcode;
        });
      }
    } catch (e) {
      print('Barkod tarama hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod tarama hatası: $e')),
      );
    }
  }

  Future<void> generateNewBarcode() async {
    String newBarcode;
    bool exists = true;

    do {
      newBarcode = (10000000 + Random().nextInt(90000000)).toString();
      var querySnapshot = await FirebaseFirestore.instance
          .collection('urunler')
          .where('Barkod', isEqualTo: newBarcode)
          .get();
      exists = querySnapshot.docs.isNotEmpty;
    } while (exists);

    setState(() {
      barkodController.text = newBarcode;
    });
  }

  Future<bool> checkIfFieldExists(String fieldName, String value) async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('urunler')
        .where(fieldName, isEqualTo: value)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 'Kodu' ve 'Detay' alanlarının benzersiz olup olmadığını kontrol edelim
    bool koduExists = await checkIfFieldExists('Kodu', koduController.text.trim());
    bool detayExists = await checkIfFieldExists('Detay', detayController.text.trim());

    if (koduExists || detayExists) {
      String existingFields = '';
      if (koduExists) existingFields += "'Kodu'";
      if (detayExists) existingFields += existingFields.isEmpty ? "'Detay'" : " ve 'Detay'";

      // Hata mesajını dialog ile gösterelim
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Hata'),
          content: Text(
              "Kaydettiğiniz ürünün $existingFields kısmı veritabanınızda mevcuttur. Ürün kaydedilemedi."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam'),
            ),
          ],
        ),
      );

      // Kaydetme işlemini durduruyoruz
      return;
    }

    // Ürünü 'urunler' koleksiyonuna ekliyoruz
    await FirebaseFirestore.instance.collection('urunler').add({
      'Ana Birim': anaBirimController.text.trim(),
      'Barkod': barkodController.text.trim(),
      'Detay': detayController.text.trim(),
      'Doviz': selectedDoviz ?? '',
      'Fiyat': fiyatController.text.trim(),
      'Gercek Stok': gercekStokController.text.trim(),
      'Kodu': koduController.text.trim(),
      'Marka': selectedMarka ?? '',
    });

    // Ürünü 'newProducts' koleksiyonuna ekliyoruz (kontrol için)
    await FirebaseFirestore.instance.collection('newProducts').add({
      'Ana Birim': anaBirimController.text.trim(),
      'Barkod': barkodController.text.trim(),
      'Detay': detayController.text.trim(),
      'Doviz': selectedDoviz ?? '',
      'Fiyat': fiyatController.text.trim(),
      'Gercek Stok': gercekStokController.text.trim(),
      'Kodu': koduController.text.trim(),
      'Marka': selectedMarka ?? '',
      'supplier': supplierController.text.trim(), // Kimden alındığı
      'addedBy': FirebaseAuth.instance.currentUser?.uid ?? 'Unknown User',
      'addedDate': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ürün başarıyla eklendi.')),
    );

    // Formu sıfırlıyoruz
    setState(() {
      _formKey.currentState!.reset();
      anaBirimController.clear();
      barkodController.clear();
      detayController.clear();
      fiyatController.clear();
      gercekStokController.clear();
      koduController.clear();
      supplierController.clear();
      selectedDoviz = null;
      selectedMarka = null;
      isAddingToExistingBox = false;
      isAddingToNewBox = false;
    });
  }

  @override
  void dispose() {
    // Bellek sızıntılarını önlemek için kontrolörleri dispose ediyoruz
    anaBirimController.dispose();
    barkodController.dispose();
    detayController.dispose();
    fiyatController.dispose();
    gercekStokController.dispose();
    koduController.dispose();
    supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Ürün Ekle',
      ),
      endDrawer: CustomDrawer(),
      bottomNavigationBar: CustomBottomBar(),
      body: Column(
        children: [
          // Form alanları üstte
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Form alanları
                  TextFormField(
                    controller: anaBirimController,
                    decoration: InputDecoration(labelText: 'Ana Birim'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bu alan boş bırakılamaz';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: barkodController,
                    decoration: InputDecoration(labelText: 'Barkod'),
                    readOnly: true, // Elle girişe tamamen kapatıyoruz
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bu alan boş bırakılamaz';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: detayController,
                    decoration: InputDecoration(labelText: 'Detay'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bu alan boş bırakılamaz';
                      }
                      return null;
                    },
                  ),
                  // Döviz alanını DropdownButtonFormField ile değiştiriyoruz
                  DropdownButtonFormField<String>(
                    value: selectedDoviz,
                    decoration: InputDecoration(labelText: 'Döviz'),
                    items: ['Dolar', 'Euro'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedDoviz = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Lütfen bir döviz seçin' : null,
                  ),
                  TextFormField(
                    controller: fiyatController,
                    decoration: InputDecoration(labelText: 'Fiyat'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextFormField(
                    controller: gercekStokController,
                    decoration: InputDecoration(labelText: 'Gerçek Stok'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: koduController,
                    decoration: InputDecoration(labelText: 'Kodu'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bu alan boş bırakılamaz';
                      }
                      return null;
                    },
                  ),
                  // Marka alanını DropdownButtonFormField ile değiştiriyoruz
                  DropdownButtonFormField<String>(
                    value: selectedMarka,
                    decoration: InputDecoration(labelText: 'Marka'),
                    items: markaListesi.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedMarka = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Lütfen bir marka seçin' : null,
                  ),
                  SizedBox(height: 20),
                  // Mevcut kutuya ekleme seçeneği
                  CheckboxListTile(
                    title: Text('Mevcut kutuya ekle'),
                    value: isAddingToExistingBox,
                    onChanged: (value) {
                      setState(() {
                        isAddingToExistingBox = value ?? false;
                        if (isAddingToExistingBox) {
                          isAddingToNewBox = false; // Yeni kutuya eklemeyi devre dışı bırak
                          scanBarcodeForExistingBox(); // Barkod tarama işlemi
                        } else {
                          barkodController.text = ''; // Barkod alanını temizle
                        }
                      });
                    },
                  ),
                  // Yeni kutuya ekleme seçeneği
                  CheckboxListTile(
                    title: Text('Yeni kutuya ekle'),
                    value: isAddingToNewBox,
                    onChanged: (value) {
                      setState(() {
                        isAddingToNewBox = value ?? false;
                        if (isAddingToNewBox) {
                          isAddingToExistingBox = false; // Mevcut kutuya eklemeyi devre dışı bırak
                          generateNewBarcode(); // Yeni barkod numarası oluştur
                        } else {
                          barkodController.text = ''; // Barkod alanını temizle
                        }
                      });
                    },
                  ),
                  // Kimden alındığı
                  TextFormField(
                    controller: supplierController,
                    decoration: InputDecoration(labelText: 'Kimden Alındı'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saveProduct,
                    child: Text('Kaydet'),
                  ),
                ],
              ),
            ),
          ),
          // Ürün listesi altta
          Expanded(
            child: buildProductList(),
          ),
        ],
      ),
    );
  }
}
