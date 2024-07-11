import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'processed_pdf.dart'; // PDF oluşturma dosyasını ekliyoruz
import 'processed_excel.dart'; // Excel oluşturma dosyasını ekliyoruz

class ProcessedWidget extends StatefulWidget {
  final String customerName;

  ProcessedWidget({required this.customerName});

  @override
  _ProcessedWidgetState createState() => _ProcessedWidgetState();
}

class _ProcessedWidgetState extends State<ProcessedWidget> {
  List<Map<String, dynamic>> processedItems = [];

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

  void showInfoDialogForQuote(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Onaylanan Ürün Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Teklif No: ${product['Teklif Numarası'] ?? 'N/A'}'),
              Text('Sipariş No: ${product['Sipariş Numarası'] ?? 'N/A'}'),
              Text('Sipariş Tarihi: ${product['Sipariş Tarihi'] ?? 'N/A'}'),
            ],
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
  }

  void showInfoDialogForKit(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Kit Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ana Kit Adı: ${product['Ana Kit Adı'] ?? 'N/A'}'),
              Text('Alt Kit Adı: ${product['Alt Kit Adı'] ?? 'N/A'}'),
              Text('Oluşturan Kişi: ${product['Oluşturan Kişi'] ?? 'Admin'}'),
              Text('Siparişe Dönüştürme Tarihi: ${product['siparisTarihi'] ?? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}'),
            ],
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
  }

  void showInfoDialogForSales(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Satış Bilgisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ürünü Kim Aldı: ${product['whoTook'] ?? 'N/A'}'),
              if (product['whoTook'] == 'Müşterisi') ...[
                Text('Müşteri İsmi: ${product['recipient'] ?? 'N/A'}'),
                Text('Firmadan Bilgilendirilecek Kişi İsmi: ${product['contactPerson'] ?? 'N/A'}'),
              ],
              if (product['whoTook'] == 'Kendi Firması')
                Text('Teslim Alan Çalışan İsmi: ${product['recipient'] ?? 'N/A'}'),
              Text('Sipariş Şekli: ${product['orderMethod'] ?? 'N/A'}'),
              Text('Tarih: ${product['siparisTarihi'] ?? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}'),
            ],
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
  }

  Widget buildInfoButton(Map<String, dynamic> product) {
    bool hasQuoteInfo = product['Teklif Numarası'] != null && product['Teklif Numarası'] != 'N/A';
    bool hasKitInfo = product['Ana Kit Adı'] != null && product['Ana Kit Adı'] != 'N/A';
    bool hasSalesInfo = product['whoTook'] != null && product['whoTook'] != 'N/A';

    if (!hasQuoteInfo && !hasKitInfo && !hasSalesInfo) {
      return Container();
    }

    return Column(
      children: [
        if (hasQuoteInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForQuote(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Teklif'),
          ),
        SizedBox(width: 5),
        if (hasKitInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForKit(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Kit'),
          ),
        SizedBox(width: 5),
        if (hasSalesInfo)
          ElevatedButton(
            onPressed: () => showInfoDialogForSales(product),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text('Satış'),
          ),
      ],
    );
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
                  DataColumn(label: Text('Kodu')),
                  DataColumn(label: Text('Detay')),
                  DataColumn(label: Text('Adet')),
                  DataColumn(label: Text('Adet Fiyatı')),
                  DataColumn(label: Text('İskonto')),
                  DataColumn(label: Text('Toplam Fiyat')),
                  DataColumn(label: Text('Bilgi')),
                ],
                rows: products.map((product) {
                  return DataRow(cells: [
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
                    DataCell(buildInfoButton(product)),
                  ]);
                }).toList()
                  ..addAll([
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Text('Toplam Tutar')),
                      DataCell(Text(total.toStringAsFixed(2))),
                      DataCell(Container()),
                    ]),
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Text('KDV %20')),
                      DataCell(Text(vat.toStringAsFixed(2))),
                      DataCell(Container()),
                    ]),
                    DataRow(cells: [
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Container()),
                      DataCell(Text('Genel Toplam')),
                      DataCell(Text(grandTotal.toStringAsFixed(2))),
                      DataCell(Container()),
                    ]),
                  ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ProcessedPDF.generateProcessedPDF(item['products'], widget.customerName);
                    },
                    child: Text('PDF\'e Çevir'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      ProcessedExcel.generateProcessedExcel(item['products'], widget.customerName);
                    },
                    child: Text('Excel\'e Çevir'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
