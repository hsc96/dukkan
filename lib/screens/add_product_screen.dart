import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_selection_screen.dart';
import 'dart:math'; // Random sayı üretmek için ekledik

class AddProductScreen extends StatefulWidget {
  final bool addByBarcode;

  AddProductScreen({required this.addByBarcode});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  Map<String, dynamic>? existingProductData;
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
    if (widget.addByBarcode) {
      scanBarcodeAndFetchProduct();
    } else {
      // Yakın ürün seçerek ekleme işlemi
      selectSimilarProduct();
    }
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

  Future<void> scanBarcodeAndFetchProduct() async {
    try {
      var result = await BarcodeScanner.scan();
      var barcode = result.rawContent;

      if (barcode.isNotEmpty) {
        var querySnapshot = await FirebaseFirestore.instance
            .collection('urunler')
            .where('Barkod', isEqualTo: barcode)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var productData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            existingProductData = productData;
            // Form kontrollerine verileri dolduruyoruz
            anaBirimController.text = productData['Ana Birim'] ?? '';
            barkodController.text = productData['Barkod'] ?? '';
            detayController.text = productData['Detay'] ?? '';
            selectedDoviz = productData['Doviz'] ?? '';
            fiyatController.text = productData['Fiyat'] ?? '';
            gercekStokController.text = productData['Gercek Stok'] ?? '';
            koduController.text = productData['Kodu'] ?? '';
            selectedMarka = productData['Marka'] ?? '';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ürün bulunamadı.')),
          );
        }
      }
    } catch (e) {
      print('Barkod tarama hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod tarama hatası: $e')),
      );
    }
  }

  Future<void> selectSimilarProduct() async {
    var selectedProduct = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductSelectionScreen(),
      ),
    );

    if (selectedProduct != null) {
      setState(() {
        existingProductData = selectedProduct;
        // Form kontrollerine verileri dolduruyoruz
        anaBirimController.text = selectedProduct['Ana Birim'] ?? '';
        barkodController.text = selectedProduct['Barkod'] ?? '';
        detayController.text = selectedProduct['Detay'] ?? '';
        selectedDoviz = selectedProduct['Doviz'] ?? '';
        fiyatController.text = selectedProduct['Fiyat'] ?? '';
        gercekStokController.text = selectedProduct['Gercek Stok'] ?? '';
        koduController.text = selectedProduct['Kodu'] ?? '';
        selectedMarka = selectedProduct['Marka'] ?? '';
      });
    }
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

      // Uyarı mesajını dialog ile gösterelim
      bool? shouldLoadData = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Ürün Zaten Mevcut'),
          content: Text(
              "Kaydettiğiniz ürünün $existingFields kısmı veritabanınızda mevcuttur!\n\nKayıtlı olan verileri getirmek ister misiniz?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Evet'),
            ),
          ],
        ),
      );

      if (shouldLoadData == true) {
        // Mevcut ürünü veritabanından çekelim
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('urunler');

        if (koduExists) {
          query = query.where('Kodu', isEqualTo: koduController.text.trim());
        } else if (detayExists) {
          query = query.where('Detay', isEqualTo: detayController.text.trim());
        }

        var existingProductSnapshot = await query.get();

        if (existingProductSnapshot.docs.isNotEmpty) {
          var existingProduct = existingProductSnapshot.docs.first.data() as Map<String, dynamic>;

          // Mevcut ürünün verilerini form alanlarına dolduralım
          setState(() {
            existingProductData = existingProduct;
            anaBirimController.text = existingProduct['Ana Birim'] ?? '';
            barkodController.text = existingProduct['Barkod'] ?? '';
            detayController.text = existingProduct['Detay'] ?? '';
            selectedDoviz = existingProduct['Doviz'] ?? '';
            fiyatController.text = existingProduct['Fiyat'] ?? '';
            gercekStokController.text = existingProduct['Gercek Stok'] ?? '';
            koduController.text = existingProduct['Kodu'] ?? '';
            selectedMarka = existingProduct['Marka'] ?? '';
          });
        }
      }

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

    Navigator.of(context).pop();
  }



  Future<bool> checkIfFieldExists(String fieldName, String value) async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('urunler')
        .where(fieldName, isEqualTo: value)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ürün Ekle'),
      ),
      body: SingleChildScrollView(
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
    );
  }
}
