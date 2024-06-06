import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'dovizservice.dart';
import 'firestore_service.dart';
import 'package:intl/intl.dart'; // Tarih formatı için eklenmiştir.
import 'package:path_provider/path_provider.dart'; // Dosya yolları için
import 'dart:io'; // Dosya işlemleri için
import 'package:pdf/widgets.dart' as pw; // PDF işlemleri için
import 'package:open_file/open_file.dart'; // Dosya açma işlemleri için
import 'pdf_template.dart'; // PDF şablonu için

class ScanScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  TextEditingController searchController = TextEditingController();
  List<String> customers = [];
  List<String> filteredCustomers = [];
  String? selectedCustomer;
  String barcodeResult = "";
  String dolarKur = "";
  String euroKur = "";
  String currentDate = DateFormat('d MMMM y', 'tr_TR').format(DateTime.now()); // Tarih formatı ayarlandı.

  List<Map<String, dynamic>> scannedProducts = [];
  List<Map<String, dynamic>> originalProducts = []; // Orijinal ürün verileri listesi
  final FirestoreService firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    fetchCustomers();
    fetchDovizKur();
  }

  void filterCustomers(String query) {
    setState(() {
      filteredCustomers = customers
          .where((customer) => customer.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (!filteredCustomers.contains(selectedCustomer)) {
        selectedCustomer = null;
      }
    });
  }

  Future<void> fetchCustomers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('veritabanideneme').get();
    var docs = querySnapshot.docs;
    var descriptions = docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['Açıklama'] ?? 'Açıklama bilgisi yok';
    }).cast<String>().toList();

    setState(() {
      customers = descriptions;
      filteredCustomers = descriptions;
    });
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

  Future<void> scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      setState(() {
        barcodeResult = result.rawContent;
      });
      fetchProductDetails(barcodeResult);
    } catch (e) {
      setState(() {
        barcodeResult = 'Hata: $e';
      });
    }
  }

  Future<void> fetchProductDetails(String barcode) async {
    var products = await firestoreService.fetchProductsByBarcode(barcode);
    if (products.isNotEmpty) {
      var uniqueProducts = <Map<String, dynamic>>[];
      for (var product in products) {
        if (!uniqueProducts.any((p) => p['Kodu'] == product['Kodu'])) {
          uniqueProducts.add(product);
        }
      }

      if (uniqueProducts.length > 1) {
        showProductSelectionDialog(uniqueProducts);
      } else {
        await addProductToTable(uniqueProducts.first);
      }
    }
  }

  Future<void> applyDiscountToProduct(Map<String, dynamic> productData, String brand) async {
    if (selectedCustomer == null) return;

    var customerDiscount = await firestoreService.getCustomerDiscount(selectedCustomer!);
    String discountLevel = customerDiscount['iskonto'] ?? '';

    double priceInTl = 0.0;
    double price = double.tryParse(productData['Fiyat']?.toString() ?? '0') ?? 0.0;
    String currency = productData['Doviz']?.toString() ?? '';

    if (currency == 'Euro') {
      priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
    } else {
      priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
    }

    if (discountLevel.isNotEmpty) {
      var discountData = await firestoreService.getDiscountRates(discountLevel, brand);
      double discountRate = discountData['rate'] ?? 0.0;
      double discountedPrice = priceInTl * (1 - (discountRate / 100));

      productData['İskonto'] = '%${discountRate.toStringAsFixed(2)}';
      productData['Adet Fiyatı'] = discountedPrice.toStringAsFixed(2);
      productData['Toplam Fiyat'] = (discountedPrice * 1).toStringAsFixed(2);
    } else {
      productData['İskonto'] = '0%';
      productData['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);
      productData['Toplam Fiyat'] = (priceInTl * 1).toStringAsFixed(2);
    }
  }

  void showProductSelectionDialog(List<Map<String, dynamic>> products) {
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
                  onTap: () async {
                    await addProductToTable(products[index]);
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

  Future<void> addProductToTable(Map<String, dynamic> productData) async {
    double priceInTl = 0.0;
    double price = double.tryParse(productData['Fiyat']?.toString() ?? '0') ?? 0.0;
    String currency = productData['Doviz']?.toString() ?? '';

    if (currency == 'Euro') {
      priceInTl = price * (double.tryParse(euroKur.replaceAll(',', '.')) ?? 0.0);
    } else if (currency == 'Dolar') {
      priceInTl = price * (double.tryParse(dolarKur.replaceAll(',', '.')) ?? 0.0);
    } else {
      priceInTl = price; // Eğer döviz bilgisi yoksa, doğrudan fiyatı kullan
    }

    productData['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);

    // Müşteri seçilmişse iskonto uygula
    if (selectedCustomer != null) {
      await applyDiscountToProduct(productData, productData['Marka']?.toString() ?? '');
    } else {
      productData['Toplam Fiyat'] = (priceInTl * 1).toStringAsFixed(2);
    }

    setState(() {
      scannedProducts.add({
        'Kodu': productData['Kodu']?.toString() ?? '',
        'Detay': productData['Detay']?.toString() ?? '',
        'Adet': '1',
        'Adet Fiyatı': productData['Adet Fiyatı']?.toString(),
        'Toplam Fiyat': productData['Toplam Fiyat']?.toString(),
        'İskonto': productData['İskonto']?.toString() ?? ''
      });
      originalProducts.add({
        ...productData,
        'Original Fiyat': productData['Fiyat']?.toString() ?? '0',
      });
      updateTotalAndVat();
    });
  }

  Future<void> updateProductsForCustomer() async {
    for (var i = 0; i < scannedProducts.length; i++) {
      var productData = originalProducts[i];
      await applyDiscountToProduct(productData, productData['Marka']);
      setState(() {
        scannedProducts[i]['Adet Fiyatı'] = productData['Adet Fiyatı'];
        scannedProducts[i]['Toplam Fiyat'] = productData['Toplam Fiyat'];
        scannedProducts[i]['İskonto'] = productData['İskonto'];
      });
    }
    updateTotalAndVat(); // Toplam ve KDV güncellemesi
  }

  void updateQuantity(int index, String quantity) {
    setState(() {
      double adet = double.tryParse(quantity) ?? 1;
      double price = double.tryParse(scannedProducts[index]['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
      scannedProducts[index]['Adet'] = quantity;
      scannedProducts[index]['Toplam Fiyat'] = (adet * price).toStringAsFixed(2);
      updateTotalAndVat();
    });
  }

  void removeProduct(int index) {
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
              onPressed: () {
                setState(() {
                  scannedProducts.removeAt(index);
                  originalProducts.removeAt(index);
                  updateTotalAndVat();
                });
                Navigator.of(context).pop();
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  void updateTotalAndVat() {
    double total = 0.0;
    scannedProducts.forEach((product) {
      if (product['Kodu']?.toString() != '' && product['Toplam Fiyat']?.toString() != '') {
        total += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      }
    });

    double vat = total * 0.20;
    double grandTotal = total + vat;

    setState(() {
      scannedProducts.removeWhere((product) =>
      product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
          product['Adet Fiyatı']?.toString() == 'KDV %20' ||
          product['Adet Fiyatı']?.toString() == 'Genel Toplam');

      scannedProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Toplam Tutar',
        'Toplam Fiyat': total.toStringAsFixed(2),
      });
      scannedProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'KDV %20',
        'Toplam Fiyat': vat.toStringAsFixed(2),
      });
      scannedProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Genel Toplam',
        'Toplam Fiyat': grandTotal.toStringAsFixed(2),
      });
    });
  }

  Future<void> saveAsPDF() async {
    final pdf = PDFTemplate.generateQuote(selectedCustomer!, scannedProducts);

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${selectedCustomer}_fiyat_teklifi.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Ürün Tara'),
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.barcode, size: 24, color: colorTheme5),
                onPressed: scanBarcode,
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    hint: Text('MÜŞTERİ SEÇ'),
                    value: selectedCustomer,
                    icon: Icon(Icons.arrow_downward),
                    iconSize: 24,
                    elevation: 16,
                    style: TextStyle(color: Colors.black),
                    underline: Container(
                      height: 2,
                      color: Colors.grey,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != selectedCustomer) {
                        if (scannedProducts.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Müşteri Değiştir'),
                                content: Text('Müşteriyi değiştirmek istediğinizden emin misiniz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Hayır'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedCustomer = newValue;
                                        updateProductsForCustomer();
                                      });
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Evet'),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          setState(() {
                            selectedCustomer = newValue;
                          });
                        }
                      }
                    },
                    items: filteredCustomers.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) => filterCustomers(query),
                    decoration: InputDecoration(
                      hintText: 'Müşteri ara...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey,
                        ),
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: colorTheme5),
                  onPressed: () {
                    updateProductsForCustomer();
                    updateTotalAndVat();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Kodu')),
                    DataColumn(label: Text('Detay')),
                    DataColumn(label: Text('Adet')),
                    DataColumn(label: Text('Adet Fiyatı')),
                    DataColumn(label: Text('İskonto')),
                    DataColumn(label: Text('Toplam Fiyat')),
                    DataColumn(label: Text('Sil')),
                  ],
                  rows: scannedProducts.map((product) {
                    int index = scannedProducts.indexOf(product);
                    return DataRow(cells: [
                      DataCell(Text(product['Kodu']?.toString() ?? '')),
                      DataCell(Text(product['Detay']?.toString() ?? '')),
                      DataCell(
                        (product['Adet Fiyatı']?.toString().contains('Toplam Tutar') ?? false) ||
                            (product['Adet Fiyatı']?.toString().contains('KDV %20') ?? false) ||
                            (product['Adet Fiyatı']?.toString().contains('Genel Toplam') ?? false)
                            ? Text('')
                            : TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => updateQuantity(index, value),
                          controller: TextEditingController()..text = product['Adet']?.toString() ?? '',
                        ),
                      ),
                      DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                      DataCell(Text(product['İskonto']?.toString() ?? '')),
                      DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                      DataCell(
                        (product['Adet Fiyatı']?.toString().contains('Toplam Tutar') ?? false) ||
                            (product['Adet Fiyatı']?.toString().contains('KDV %20') ?? false) ||
                            (product['Adet Fiyatı']?.toString().contains('Genel Toplam') ?? false)
                            ? Text('')
                            : IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeProduct(index),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    saveAsPDF();
                  },
                  child: Text('Teklif Ver'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Satış yap fonksiyonu burada
                  },
                  child: Text('Satış Yap'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Hesaba işle fonksiyonu burada
                  },
                  child: Text('Hesaba İşle'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
      bottomSheet: Container(
        padding: EdgeInsets.all(8),
        color: Colors.grey[200],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 USD: $dolarKur', style: TextStyle(fontSize: 16, color: Colors.black)),
            Text(currentDate, style: TextStyle(fontSize: 16, color: Colors.black)), // Tarih eklendi
            Text('1 EUR: $euroKur', style: TextStyle(fontSize: 16, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
