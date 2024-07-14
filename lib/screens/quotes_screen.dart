import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pdf_template.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';

class QuotesScreen extends StatefulWidget {
  @override
  _QuotesScreenState createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  List<Map<String, dynamic>> quotes = [];
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());
  TextEditingController orderNumberController = TextEditingController();
  Set<int> selectedQuoteIndexes = {};
  int? selectedQuoteIndex;

  @override
  void initState() {
    super.initState();
    fetchQuotes();
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
      }).toList();
    });
  }

  List<Map<String, dynamic>> getQuotesForSelectedMonth() {
    return quotes.where((quote) {
      return DateFormat('MMMM').format(quote['date']) == selectedMonth;
    }).toList();
  }

  void toggleSelectAllProducts(int quoteIndex) {
    setState(() {
      var quoteProducts = quotes[quoteIndex]['products'] as List<Map<String, dynamic>>;
      if (selectedQuoteIndexes.length == quoteProducts.length && selectedQuoteIndex == quoteIndex) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Onaylayın'),
              content: Text('Tüm seçimler kaldırılacak. Onaylıyor musunuz?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('İptal'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedQuoteIndexes.clear();
                      selectedQuoteIndex = null;
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
        selectedQuoteIndexes = Set<int>.from(Iterable<int>.generate(quoteProducts.length));
        selectedQuoteIndex = quoteIndex;
      }
    });
  }

  void saveQuoteAsPDF(int quoteIndex) async {
    var quote = quotes[quoteIndex];
    var quoteProducts = quote['products'] as List<Map<String, dynamic>>;

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

  void convertQuoteToOrder(int quoteIndex) {
    if (selectedQuoteIndexes.isEmpty || selectedQuoteIndex != quoteIndex) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen ürünleri seçin')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Teklif Siparişe Dönüştür'),
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
                  showProductDateSelectionDialog(quoteIndex);
                },
                child: Text('Devam Et'),
              ),
            ],
          ),
        );
      },
    );
  }

  void showProductDateSelectionDialog(int quoteIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DeliveryDateForm(
          quoteProducts: quotes[quoteIndex]['products'].where((product) {
            return product['Adet Fiyatı'] != 'Toplam Tutar' &&
                product['Adet Fiyatı'] != 'KDV %20' &&
                product['Adet Fiyatı'] != 'Genel Toplam';
          }).toList(),
          onSave: (updatedProducts) {
            finalizeOrderConversion(quoteIndex, updatedProducts, orderNumberController.text);
          },
          selectedProductIndexes: selectedQuoteIndexes,
        );
      },
    );
  }

  void finalizeOrderConversion(int quoteIndex, List<Map<String, dynamic>> updatedProducts, String? orderNumber) async {
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

    var quote = quotes[quoteIndex];
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
          'Teklif Tarihi': DateFormat('dd MMMM yyyy').format(quote['date']),
          'Sipariş Numarası': orderNumber ?? 'Sipariş Numarası Girilmedi',
          'Sipariş Tarihi': DateFormat('dd MMMM yyyy').format(DateTime.now()),
          'Beklenen Teklif': true,
          'Ürün Hazır Olma Tarihi': Timestamp.now(),
          'Müşteri': customerName,
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
        selectedQuoteIndexes.clear();
        selectedQuoteIndex = null;
      });

      Navigator.of(context).pop();
      print('Veriler başarıyla kaydedildi');
    } catch (e) {
      Navigator.of(context).pop();
      print('Veri ekleme hatası: $e');
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
              children: List.generate(12, (index) {
                String monthName = DateFormat('MMMM').format(DateTime(0, index + 1));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedMonth = monthName;
                      });
                    },
                    child: Text(monthName),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: getQuotesForSelectedMonth().length,
              itemBuilder: (context, index) {
                var quote = getQuotesForSelectedMonth()[index];
                return ExpansionTile(
                  title: Text('Teklif No: ${quote['quoteNumber']} - ${quote['customerName']}'),
                  subtitle: Text('Tarih: ${DateFormat('dd MMMM yyyy').format(quote['date'])}'),
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
                            DataCell(Text(product['Adet']?.toString() ?? '')),
                            DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                            DataCell(Text(product['İskonto']?.toString() ?? '')),
                            DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
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
                          child: Text(
                            selectedQuoteIndexes.length == quotes[index]['products'].length && selectedQuoteIndex == index
                                ? 'Seçimleri Kaldır'
                                : 'Hepsini Seç',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            convertQuoteToOrder(index);
                          },
                          child: Text('Siparişe Dönüştür'),
                        ),
                        TextButton(
                          onPressed: () {
                            saveQuoteAsPDF(index);
                          },
                          child: Text('PDF\'e Dönüştür'),
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
      bottomNavigationBar: CustomBottomBar(), // Alt navigasyon çubuğunu ekleyelim
    );
  }
}

class DeliveryDateForm extends StatefulWidget {
  final List<Map<String, dynamic>> quoteProducts;
  final Function(List<Map<String, dynamic>>) onSave;
  final Set<int> selectedProductIndexes;

  DeliveryDateForm({required this.quoteProducts, required this.onSave, required this.selectedProductIndexes});

  @override
  _DeliveryDateFormState createState() => _DeliveryDateFormState();
}

class _DeliveryDateFormState extends State<DeliveryDateForm> {
  List<Map<String, dynamic>> updatedProducts = [];

  @override
  void initState() {
    super.initState();
    updatedProducts = widget.quoteProducts.where((product) {
      int productIndex = widget.quoteProducts.indexOf(product);
      return widget.selectedProductIndexes.contains(productIndex);
    }).toList();
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
                              ? 'Delivery Date: ${DateFormat('dd MMMM yyyy').format(deliveryDate)}'
                              : 'Select Delivery Date',
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
                      Text('Is this product in stock?'),
                    ],
                  ),
                  if (product['isStock'] == true)
                    Text('This product is in stock.')
                  else if (deliveryDate != null)
                    Text('Delivery Date: ${DateFormat('dd MMMM yyyy').format(deliveryDate)}'),
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
          child: Text('Save'),
        ),
      ],
    );
  }
}
