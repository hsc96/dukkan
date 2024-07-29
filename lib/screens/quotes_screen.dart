import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pdf_template.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuotesScreen extends StatefulWidget {
  @override
  _QuotesScreenState createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  List<Map<String, dynamic>> quotes = [];
  String selectedMonth = DateFormat('MMMM', 'tr_TR').format(DateTime.now());
  int selectedYear = DateTime.now().year;
  TextEditingController orderNumberController = TextEditingController();
  Set<int> selectedProductIndexes = {};
  int? selectedQuoteIndex;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? currentUser;
  String? fullName;

  @override
  void initState() {
    super.initState();
    fetchQuotes();
    fetchCurrentUser();
  }


  Future<void> fetchCurrentUser() async {
    currentUser = _auth.currentUser;
    if (currentUser != null) {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        setState(() {
          fullName = userDoc.data()?['fullName'];
        });
      }
    }
  }

  Future<void> fetchQuotes() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('quotes').get();

    setState(() {
      quotes = querySnapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'customerName': data['customerName'] ?? '',
          'quoteNumber': data['quoteNumber'] ?? '',
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).where((quote) => quote['quoteNumber'] != '').toList();
    });
  }

  List<Map<String, dynamic>> getQuotesForSelectedMonth() {
    return quotes.where((quote) {
      return DateFormat('MMMM', 'tr_TR').format(quote['date']) == selectedMonth && quote['date'].year == selectedYear;
    }).toList();
  }

  void toggleSelectAllProducts(int quoteIndex) {
    setState(() {
      var quoteProducts = quotes[quoteIndex]['products'] as List<Map<String, dynamic>>;
      if (selectedProductIndexes.length == quoteProducts.length && selectedQuoteIndex == quoteIndex) {
        selectedProductIndexes.clear();
        selectedQuoteIndex = null;
      } else {
        selectedProductIndexes = Set<int>.from(Iterable<int>.generate(quoteProducts.length));
        selectedQuoteIndex = quoteIndex;
      }
    });
  }

  void saveQuoteAsPDF(Map<String, dynamic> quote) async {
    if (selectedProductIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen ürün seçin')),
      );
      return;
    }

    var quoteProducts = (quote['products'] as List<Map<String, dynamic>>)
        .asMap()
        .entries
        .where((entry) => selectedProductIndexes.contains(entry.key))
        .map((entry) => entry.value)
        .toList();

    double total = quoteProducts.fold(0, (sum, item) => sum + (double.tryParse(item['Toplam Fiyat'].toString()) ?? 0.0));
    double vat = total * 0.20;
    double grandTotal = total + vat;

    DateTime quoteDate;
    if (quote['date'] is Timestamp) {
      quoteDate = (quote['date'] as Timestamp).toDate();
    } else if (quote['date'] is DateTime) {
      quoteDate = quote['date'];
    } else {
      quoteDate = DateTime.now();
    }

    final pdf = await PDFTemplate.generateQuote(
      quote['customerName'],
      quoteProducts,
      total,
      vat,
      grandTotal,
      '', // Teslim tarihi
      '', // Teklif süresi
      quote['quoteNumber'], // Yeni parametreler
      quoteDate, // Yeni parametreler
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${quote['customerName']}_teklif_${quote['quoteNumber']}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }
  void convertQuoteToOrder(Map<String, dynamic> quote) {
    if (selectedProductIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen ürün seçin')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Teklifi Siparişe Dönüştür'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: orderNumberController,
                decoration: InputDecoration(hintText: 'Sipariş Numarası'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showProductDateSelectionDialog(quote);
                },
                child: Text('Devam Et'),
              ),
            ],
          ),
        );
      },
    );
  }

  void showProductDateSelectionDialog(Map<String, dynamic> quote) {
    var selectedProducts = (quote['products'] as List<Map<String, dynamic>>)
        .asMap()
        .entries
        .where((entry) => selectedProductIndexes.contains(entry.key))
        .map((entry) => entry.value)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DeliveryDateForm(
          quoteProducts: selectedProducts,
          onSave: (updatedProducts) {
            finalizeOrderConversion(quote, updatedProducts, orderNumberController.text);
          },
        );
      },
    );
  }

  void finalizeOrderConversion(Map<String, dynamic> quote, List<Map<String, dynamic>> updatedProducts, String? orderNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Siparişe Dönüştürülüyor...'),
          content: CircularProgressIndicator(),
        );
      },
    );

    var customerName = quote['customerName'];

    var customerSnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Açıklama', isEqualTo: customerName)
        .get();

    if (customerSnapshot.docs.isEmpty) {
      Navigator.of(context).pop();
      print('Müşteri bulunamadı');
      return;
    }

    var customerData = customerSnapshot.docs.first.data() as Map<String, dynamic>;
    String uniqueId = customerData['Vergi Kimlik Numarası']?.toString() ?? customerData['T.C. Kimlik Numarası']?.toString() ?? '';

    try {
      var customerProductsCollection = FirebaseFirestore.instance.collection('customerDetails');
      var customerSnapshot = await customerProductsCollection.where('customerName', isEqualTo: customerName).get();
      var existingProducts = <Map<String, dynamic>>[];

      if (customerSnapshot.docs.isNotEmpty) {
        existingProducts = List<Map<String, dynamic>>.from(customerSnapshot.docs.first.data()['products'] ?? []);
      }

      for (var i = 0; i < updatedProducts.length; i++) {
        var product = updatedProducts[i];

        var teslimTarihi = product['deliveryDate'];
        if (teslimTarihi is DateTime) {
          teslimTarihi = Timestamp.fromDate(teslimTarihi);
        }

        var productData = {
          'Kodu': product['Kodu'],
          'Detay': product['Detay'],
          'Adet': product['Adet'],
          'Adet Fiyatı': product['Adet Fiyatı'],
          'Toplam Fiyat': (double.tryParse(product['Adet']?.toString() ?? '0') ?? 0) *
              (double.tryParse(product['Adet Fiyatı']?.toString() ?? '0') ?? 0),
          'Teklif Numarası': quote['quoteNumber'],
          'Teklif Tarihi': DateFormat('dd MMMM yyyy', 'tr_TR').format(quote['date']),
          'Sipariş Numarası': orderNumber ?? 'Sipariş Numarası Girilmedi',
          'Sipariş Tarihi': DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now()),
          'Beklenen Teklif': true,
          'Ürün Hazır Olma Tarihi': Timestamp.now(),
          'Müşteri': customerName,
          'islemeAlan': fullName ?? 'Unknown', // İşleme Alan kullanıcı bilgisi
        };

        if (product['isStock'] == true) {
          productData['buttonInfo'] = 'Teklif';
          existingProducts.add(productData);
        } else {
          productData['Unique ID'] = uniqueId;
          productData['deliveryDate'] = teslimTarihi;
          productData['buttonInfo'] = 'B.sipariş';
          await FirebaseFirestore.instance.collection('pendingProducts').add(productData);
        }
      }

      if (customerSnapshot.docs.isNotEmpty) {
        var docRef = customerSnapshot.docs.first.reference;
        await docRef.update({'products': existingProducts});
      } else {
        await customerProductsCollection.add({
          'customerName': customerName,
          'products': existingProducts,
        });
      }

      setState(() {
        selectedProductIndexes.clear();
        selectedQuoteIndex = null;
      });

      Navigator.of(context).pop();
      print('Veriler başarıyla kaydedildi');
    } catch (e) {
      Navigator.of(context).pop();
      print('Veri ekleme hatası: $e');
    }
  }

  Future<void> selectYear(BuildContext context) async {
    int? selectedYear = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Yıl Seçin'),
          content: Container(
            height: 300,
            width: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(DateTime.now().year + 1),
              initialDate: DateTime(this.selectedYear),
              selectedDate: DateTime(this.selectedYear),
              onChanged: (DateTime dateTime) {
                Navigator.pop(context, dateTime.year);
              },
            ),
          ),
        );
      },
    );

    if (selectedYear != null) {
      setState(() {
        this.selectedYear = selectedYear;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Tüm Teklifler'),
      body: Column(
        children: [
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(12, (index) {
                  String monthName = DateFormat('MMMM', 'tr_TR').format(DateTime(0, index + 1));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedMonth = monthName;
                        });
                      },
                      child: Text(
                        selectedYear == DateTime.now().year ? monthName : '$monthName $selectedYear',
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      selectYear(context);
                    },
                    child: Text('Yıl Seç'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: getQuotesForSelectedMonth().length,
              itemBuilder: (context, index) {
                var quote = getQuotesForSelectedMonth()[index];
                return ExpansionTile(
                  title: Text('Teklif No: ${quote['quoteNumber']} - ${quote['customerName']}'),
                  subtitle: Text('Tarih: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(quote['date'])}'),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Seç')),
                          DataColumn(label: Text('Kodu')),
                          DataColumn(label: Text('Detay')),
                          DataColumn(label: Text('Adet')),
                          DataColumn(label: Text('Adet Fiyatı')),
                          DataColumn(label: Text('İskonto')),
                          DataColumn(label: Text('Toplam Fiyat')),
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
                                value: selectedProductIndexes.contains(productIndex) && selectedQuoteIndex == index,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedProductIndexes.add(productIndex);
                                      selectedQuoteIndex = index;
                                    } else {
                                      selectedProductIndexes.remove(productIndex);
                                      if (selectedProductIndexes.isEmpty) {
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
                            DataCell(Text(product['Adet']?.toString() ?? '')),
                            DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                            DataCell(Text(product['İskonto']?.toString() ?? '')),
                            DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                          ]);
                        }).toList(),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            saveQuoteAsPDF(quote);
                          },
                          child: Text('PDF\'ye Dönüştür'),
                        ),
                        TextButton(
                          onPressed: () {
                            convertQuoteToOrder(quote);
                          },
                          child: Text('Siparişe Dönüştür'),
                        ),
                        TextButton(
                          onPressed: () {
                            toggleSelectAllProducts(index);
                          },
                          child: Text(
                            selectedProductIndexes.length == (quote['products'] as List).length && selectedQuoteIndex == index
                                ? 'Seçimleri Kaldır'
                                : 'Hepsini Seç',
                          ),
                        ),
                      ],
                    ),
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

class DeliveryDateForm extends StatefulWidget {
  final List<Map<String, dynamic>> quoteProducts;
  final Function(List<Map<String, dynamic>>) onSave;

  DeliveryDateForm({required this.quoteProducts, required this.onSave});

  @override
  _DeliveryDateFormState createState() => _DeliveryDateFormState();
}

class _DeliveryDateFormState extends State<DeliveryDateForm> {
  List<Map<String, dynamic>> updatedProducts = [];

  @override
  void initState() {
    super.initState();
    updatedProducts = widget.quoteProducts;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Teslim Tarihi Seçin'),
      content: SingleChildScrollView(
        child: Column(
          children: updatedProducts.map((product) {
            int productIndex = updatedProducts.indexOf(product);
            DateTime? deliveryDate = product['deliveryDate'] is Timestamp
                ? (product['deliveryDate'] as Timestamp).toDate()
                : (product['deliveryDate'] as DateTime?);

            return ListTile(
              title: Text(product['Detay'] ?? 'Detay yok'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: product['isStock'] == true
                            ? null
                            : () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: deliveryDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              updatedProducts[productIndex]['deliveryDate'] = pickedDate;
                            });
                          }
                        },
                        child: Text(
                          deliveryDate != null
                              ? 'Teslim Tarihi: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(deliveryDate)}'
                              : 'Teslim Tarihi Seç',
                        ),
                      ),
                      Checkbox(
                        value: product['isStock'] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            updatedProducts[productIndex]['isStock'] = value;
                            if (value == true) {
                              updatedProducts[productIndex].remove('deliveryDate');
                            }
                          });
                        },
                      ),
                      Text('Bu ürün stokta mı?'),
                    ],
                  ),
                  if (product['isStock'] == true)
                    Text('Bu ürün stokta.')
                  else if (deliveryDate != null)
                    Text('Teslim Tarihi: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(deliveryDate)}'),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onSave(updatedProducts);
            Navigator.of(context).pop(); // Dialog'u kapatma
          },
          child: Text('Kaydet'),
        ),
      ],
    );
  }
}
