import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProcessedWidget extends StatefulWidget {
  final String customerName;

  ProcessedWidget({required this.customerName});

  @override
  _ProcessedWidgetState createState() => _ProcessedWidgetState();
}

class _ProcessedWidgetState extends State<ProcessedWidget> {
  List<Map<String, dynamic>> processedItems = [];
  Set<int> selectedProcessedIndexes = {};
  int? selectedProcessedIndex;

  @override
  void initState() {
    super.initState();
    fetchProcessedItems();
  }

  Future<void> fetchProcessedItems() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('islenenler')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    setState(() {
      processedItems = querySnapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'date': (data['date'] as Timestamp).toDate(),
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
        };
      }).toList();
    });
  }

  void toggleSelectAllProcessed(int processedIndex) {
    setState(() {
      var processedProducts = processedItems[processedIndex]['products'] as List<Map<String, dynamic>>;
      if (selectedProcessedIndexes.length == processedProducts.length && selectedProcessedIndex == processedIndex) {
        selectedProcessedIndexes.clear();
      } else {
        selectedProcessedIndexes = Set<int>.from(Iterable<int>.generate(processedProducts.length));
        selectedProcessedIndex = processedIndex;
      }
    });
  }

  double calculateTotal(List<Map<String, dynamic>> products) {
    return products.fold(0.0, (sum, product) {
      if (product['Toplam Fiyat'] != null) {
        return sum + (double.tryParse(product['Toplam Fiyat'].toString()) ?? 0.0);
      }
      return sum;
    });
  }

  double calculateVAT(double total) {
    return total * 0.20; // %20 KDV
  }

  double calculateGrandTotal(double total, double vat) {
    return total + vat;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: processedItems.length,
      itemBuilder: (context, index) {
        var item = processedItems[index];
        var products = item['products'] as List<Map<String, dynamic>>;
        var total = calculateTotal(products);
        var vat = calculateVAT(total);
        var grandTotal = calculateGrandTotal(total, vat);

        return ExpansionTile(
          title: Text('${item['name']} - ${DateFormat('dd MMMM yyyy').format(item['date'])}'),
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
                  DataColumn(label: Text('Teklif Bilgisi')), // Teklif Bilgisi Kolonu
                ],
                rows: products.map((product) {
                  int productIndex = products.indexOf(product);
                  bool isTotalRow = product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
                      product['Adet Fiyatı']?.toString() == 'KDV %20' ||
                      product['Adet Fiyatı']?.toString() == 'Genel Toplam';

                  return DataRow(cells: [
                    DataCell(
                      !isTotalRow
                          ? Checkbox(
                        value: selectedProcessedIndexes.contains(productIndex) && selectedProcessedIndex == index,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedProcessedIndexes.add(productIndex);
                              selectedProcessedIndex = index;
                            } else {
                              selectedProcessedIndexes.remove(productIndex);
                              if (selectedProcessedIndexes.isEmpty) {
                                selectedProcessedIndex = null;
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
                      product['Teklif Numarası'] != null
                          ? IconButton(
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
                      )
                          : Container(),
                    ),
                  ]);
                }).toList()
                  ..addAll([
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Text('Toplam Tutar')),
                      DataCell(Container()),
                      DataCell(Text(total.toStringAsFixed(2))),
                      DataCell(Container()),
                    ]),
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Text('KDV %20')),
                      DataCell(Container()),
                      DataCell(Text(vat.toStringAsFixed(2))),
                      DataCell(Container()),
                    ]),
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Text('Genel Toplam')),
                      DataCell(Container()),
                      DataCell(Text(grandTotal.toStringAsFixed(2))),
                      DataCell(Container()),
                    ]),
                  ]),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    toggleSelectAllProcessed(index);
                  },
                  child: Text('Hepsini Seç'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
