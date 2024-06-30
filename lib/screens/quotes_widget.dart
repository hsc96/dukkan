import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pdf_service.dart';
import 'pdf_template.dart';

class QuotesWidget extends StatefulWidget {
  final String customerName;

  QuotesWidget({required this.customerName});

  @override
  _QuotesWidgetState createState() => _QuotesWidgetState();
}

class _QuotesWidgetState extends State<QuotesWidget> {
  List<Map<String, dynamic>> quotes = [];
  bool isEditing = false;
  int editingIndex = -1;
  Map<String, dynamic>? originalProductData;
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController explanationController = TextEditingController();
  Set<int> selectedQuoteIndexes = {};
  int? selectedQuoteIndex;
  TextEditingController orderNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchQuotes();
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

  Future<void> saveEditsToDatabase(int index) async {
    var quoteCollection = FirebaseFirestore.instance.collection('quotes');
    var quote = quotes[index];
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
                    saveEditsToDatabase(quoteIndex); // Veritabanına kaydet
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

  void convertQuoteToOrder(int quoteIndex) {
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

    var customerSnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Açıklama', isEqualTo: widget.customerName)
        .get();

    if (customerSnapshot.docs.isEmpty) {
      Navigator.of(context).pop();
      print('Müşteri bulunamadı');
      return;
    }

    var customerData = customerSnapshot.docs.first.data() as Map<String, dynamic>;
    String uniqueId = customerData['Vergi Kimlik Numarası']?.toString() ?? customerData['T.C. Kimlik Numarası']?.toString() ?? '';

    try {
      for (var product in updatedProducts) {
        var teslimTarihi = product['deliveryDate'];
        if (teslimTarihi is DateTime) {
          teslimTarihi = Timestamp.fromDate(teslimTarihi);
        }

        if (product['Adet Fiyatı'] != 'Toplam Tutar' && product['Adet Fiyatı'] != 'KDV %20' && product['Adet Fiyatı'] != 'Genel Toplam') {
          await FirebaseFirestore.instance.collection('pendingProducts').add({
            'Kodu': product['Kodu'],  // Ürün Kodu eklendi
            'Müşteri Ünvanı': widget.customerName.length > 30 ? widget.customerName.substring(0, 30) : widget.customerName,
            'Teklif No': quotes[quoteIndex]['quoteNumber'],
            'Teklif Tarihi': DateFormat('dd MMMM yyyy').format(quotes[quoteIndex]['date']),
            'Sipariş No': orderNumber ?? 'Sipariş Numarası Girilmedi',
            'Sipariş Tarihi': DateFormat('dd MMMM yyyy').format(DateTime.now()),
            'Adet Fiyatı': product['Adet Fiyatı'],
            'Adet': product['Adet'],
            'Detay': product['Detay'],
            'İşleme Alan': 'admin',
            'deliveryDate': teslimTarihi,
            'Unique ID': uniqueId,
          });
        }
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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
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
                    convertQuoteToOrder(index);
                  },
                  child: Text('Siparişe Dönüştür'),
                ),
              ],
            ),
          ],
        );
      },
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
    updatedProducts = List<Map<String, dynamic>>.from(widget.quoteProducts);
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
