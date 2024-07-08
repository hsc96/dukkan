import 'dart:convert';
import 'dart:io'; // Dosya işlemleri için
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
import 'package:pdf/widgets.dart' as pw; // PDF işlemleri için
import 'package:open_file/open_file.dart'; // Dosya açma işlemleri için
import 'pdf_template.dart'; // PDF şablonu için
import 'customer_details_screen.dart'; // Müşteri detayları ekranını import et

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

  double toplamTutar = 0.0;
  double kdv = 0.0;
  double genelToplam = 0.0;
  bool isEditing = false;
  int editingIndex = -1;
  Map<String, dynamic>? originalProductData;
  TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchCustomers();
    initializeDovizKur();
  }

  Future<void> initializeDovizKur() async {
    DovizService dovizService = DovizService();
    dovizService.scheduleDailyUpdate();
    var kurlar = await dovizService.getDovizKur();
    setState(() {
      dolarKur = kurlar['dolar']!;
      euroKur = kurlar['euro']!;
    });
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
      productData['Toplam Fiyat'] = (discountedPrice * (double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1)).toStringAsFixed(2);
    } else {
      productData['İskonto'] = '0%';
      productData['Adet Fiyatı'] = priceInTl.toStringAsFixed(2);
      productData['Toplam Fiyat'] = (priceInTl * (double.tryParse(productData['Adet']?.toString() ?? '1') ?? 1)).toStringAsFixed(2);
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
      double adet = double.tryParse(scannedProducts[i]['Adet']?.toString() ?? '1') ?? 1;
      setState(() {
        scannedProducts[i]['Adet Fiyatı'] = productData['Adet Fiyatı'];
        scannedProducts[i]['Toplam Fiyat'] = (adet * (double.tryParse(productData['Adet Fiyatı'] ?? '0') ?? 0)).toStringAsFixed(2);
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
    toplamTutar = 0.0;
    scannedProducts.forEach((product) {
      if (product['Kodu']?.toString() != '' && product['Toplam Fiyat']?.toString() != '') {
        toplamTutar += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      }
    });

    kdv = toplamTutar * 0.20;
    genelToplam = toplamTutar + kdv;

    setState(() {
      scannedProducts.removeWhere((product) =>
      (product['Adet Fiyatı']?.toString().contains('Toplam Tutar') ?? false) ||
          (product['Adet Fiyatı']?.toString().contains('KDV %20') ?? false) ||
          (product['Adet Fiyatı']?.toString().contains('Genel Toplam') ?? false));

      scannedProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Toplam Tutar',
        'Toplam Fiyat': toplamTutar.toStringAsFixed(2),
      });
      scannedProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'KDV %20',
        'Toplam Fiyat': kdv.toStringAsFixed(2),
      });
      scannedProducts.add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Genel Toplam',
        'Toplam Fiyat': genelToplam.toStringAsFixed(2),
      });
    });
  }

  Future<void> saveToCustomerDetails(String whoTook, String? recipient, String? contactPerson, String orderMethod) async {
    if (selectedCustomer == null) return;

    var customerCollection = FirebaseFirestore.instance.collection('customerDetails');
    var querySnapshot = await customerCollection.where('customerName', isEqualTo: selectedCustomer).get();

    var processedProducts = scannedProducts.map((product) {
      return {
        ...product,
        'whoTook': whoTook,
        'recipient': recipient,
        'contactPerson': contactPerson,
        'orderMethod': orderMethod,
        'siparisTarihi': DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now()), // Sipariş Tarihini ekle
      };
    }).toList();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      var existingProducts = List<Map<String, dynamic>>.from(querySnapshot.docs.first['products'] ?? []);

      // Mevcut ürünleri güncelleyerek veya yeni ürünleri ekleyerek
      for (var product in processedProducts) {
        existingProducts.add(product);
      }

      await docRef.update({
        'products': existingProducts,
      });
    } else {
      await customerCollection.add({
        'customerName': selectedCustomer,
        'products': processedProducts,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ürünler başarıyla kaydedildi')),
    );

    // Müşteri detayları ekranına yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsScreen(customerName: selectedCustomer!),
      ),
    );
  }



  Future<void> showProcessingDialog() async {
    String? whoTook;
    String? recipient;
    String? contactPerson;
    String? orderMethod;
    TextEditingController recipientController = TextEditingController();
    TextEditingController contactPersonController = TextEditingController();
    TextEditingController otherMethodController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Sipariş Bilgileri'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Ürünü Kim Aldı:'),
                    RadioListTile<String>(
                      title: Text('Müşterisi'),
                      value: 'Müşterisi',
                      groupValue: whoTook,
                      onChanged: (value) {
                        setState(() {
                          whoTook = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Kendi Firması'),
                      value: 'Kendi Firması',
                      groupValue: whoTook,
                      onChanged: (value) {
                        setState(() {
                          whoTook = value;
                        });
                      },
                    ),
                    if (whoTook == 'Müşterisi')
                      Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(labelText: 'Müşteri İsmi'),
                            controller: recipientController,
                          ),
                          TextField(
                            decoration: InputDecoration(labelText: 'Firmadan Bilgilendirilecek Kişi İsmi'),
                            controller: contactPersonController,
                          ),
                        ],
                      ),
                    if (whoTook == 'Kendi Firması')
                      TextField(
                        decoration: InputDecoration(labelText: 'Teslim Alan Çalışan İsmi'),
                        controller: recipientController,
                      ),
                    SizedBox(height: 20),
                    Text('Sipariş Şekli:'),
                    RadioListTile<String>(
                      title: Text('Mail'),
                      value: 'Mail',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Whatsapp'),
                      value: 'Whatsapp',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Telefon'),
                      value: 'Telefon',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Dükkanda Sipariş'),
                      value: 'Dükkanda Sipariş',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Diğer'),
                      value: 'Diğer',
                      groupValue: orderMethod,
                      onChanged: (value) {
                        setState(() {
                          orderMethod = value;
                        });
                      },
                    ),
                    if (orderMethod == 'Diğer')
                      TextField(
                        controller: otherMethodController,
                        decoration: InputDecoration(labelText: 'Sipariş Şekli (Diğer)'),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('İptal'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Kaydet'),
                  onPressed: () {
                    if (whoTook != null &&
                        recipientController.text.isNotEmpty &&
                        contactPersonController.text.isNotEmpty &&
                        orderMethod != null &&
                        (orderMethod != 'Diğer' || otherMethodController.text.isNotEmpty)) {
                      saveToCustomerDetails(
                        whoTook!,
                        recipientController.text,
                        contactPersonController.text,
                        orderMethod == 'Diğer' ? otherMethodController.text : orderMethod!,
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> saveAsPDF() async {
    // Kullanıcıdan teslim tarihi ve teklif süresi bilgilerini alın
    String teslimTarihi = await _selectDate(context);
    String teklifSuresi = await _selectOfferDuration(context);

    // Teklif numarası ve tarihini belirle
    String quoteNumber = "CSK20240001"; // Bu örnekte sabit bir numara kullanılıyor, dinamik olarak da alınabilir
    DateTime quoteDate = DateTime.now(); // Teklif tarihi şu anki zaman

    final pdf = await PDFTemplate.generateQuote(
      selectedCustomer!,
      scannedProducts.cast<Map<String, dynamic>>(),
      toplamTutar,
      kdv,
      genelToplam,
      teslimTarihi,
      teklifSuresi,
      quoteNumber, // Yeni parametre
      quoteDate, // Yeni parametre
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${selectedCustomer}_fiyat_teklifi.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }


  Future<String> _selectDate(BuildContext context) async {
    DateTime selectedDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      int businessDays = _calculateBusinessDays(selectedDate, picked);
      return '$businessDays iş günü';
    }
    return '0 iş günü';
  }

  Future<String> _selectOfferDuration(BuildContext context) async {
    String offerDuration = '';
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Teklif Süresi (gün)'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              offerDuration = value;
            },
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
    return offerDuration;
  }

  int _calculateBusinessDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = start;
    while (current.isBefore(end)) {
      current = current.add(Duration(days: 1));
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        count++;
      }
    }
    return count;
  }

  Future<void> generateQuote() async {
    if (selectedCustomer == null) return;

    // Teklif numarasını oluştur
    String currentYear = DateFormat('yyyy').format(DateTime.now());
    String prefix = 'CSK$currentYear';
    var querySnapshot = await FirebaseFirestore.instance
        .collection('quotes')
        .where('quoteNumber', isGreaterThanOrEqualTo: prefix)
        .where('quoteNumber', isLessThan: prefix + 'Z')
        .orderBy('quoteNumber', descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (querySnapshot.docs.isNotEmpty) {
      String lastQuoteNumber = querySnapshot.docs.first['quoteNumber'];
      String lastNumberStr = lastQuoteNumber.substring(prefix.length);
      int lastNumber = int.tryParse(lastNumberStr) ?? 0;
      nextNumber = lastNumber + 1;
    }

    String quoteNumber = '$prefix${nextNumber.toString().padLeft(4, '0')}';

    // Teklifi Firestore'a kaydet
    await FirebaseFirestore.instance.collection('quotes').add({
      'customerName': selectedCustomer,
      'quoteNumber': quoteNumber,
      'products': scannedProducts,
      'date': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Teklif başarıyla oluşturuldu')),
    );

    // Müşteri detayları ekranına yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsScreen(customerName: selectedCustomer!),
      ),
    );
  }

  void handleEditSubmit(int index) {
    setState(() {
      isEditing = false;
      editingIndex = -1;
    });
  }

  void handleEditCancel(int index) {
    setState(() {
      scannedProducts[index] = originalProductData!;
      originalProductData = null;
      isEditing = false;
      editingIndex = -1;
    });
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
                    DataColumn(label: Text('Düzenle')),
                  ],
                  rows: scannedProducts.map((product) {
                    int index = scannedProducts.indexOf(product);
                    bool isTotalRow = product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
                        product['Adet Fiyatı']?.toString() == 'KDV %20' ||
                        product['Adet Fiyatı']?.toString() == 'Genel Toplam';

                    return DataRow(cells: [
                      DataCell(Text(product['Kodu']?.toString() ?? '')),
                      DataCell(Text(product['Detay']?.toString() ?? '')),
                      DataCell(
                        isTotalRow
                            ? Text('')
                            : TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            updateQuantity(index, value);
                          },
                          controller: TextEditingController(text: product['Adet']?.toString() ?? ''),
                          onSubmitted: (value) {
                            handleEditSubmit(index);
                          },
                        ),
                      ),
                      DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
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
                                });
                              },
                            ),
                            if (isEditing && editingIndex == index)
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.check, color: Colors.green),
                                    onPressed: () {
                                      handleEditSubmit(index);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => removeProduct(index),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      handleEditCancel(index);
                                    },
                                  ),
                                ],
                              ),
                          ],
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
                  onPressed: generateQuote,
                  child: Text('Teklif Ver'),
                ),
                ElevatedButton(
                  onPressed: showProcessingDialog, // Hesaba işle fonksiyonunu burada tanımladık
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