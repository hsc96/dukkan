import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'customer_details_screen.dart';
class ProcessedScreen extends StatefulWidget {
  final String customerName;

  ProcessedScreen({required this.customerName});

  @override
  _ProcessedScreenState createState() => _ProcessedScreenState();
}

class _ProcessedScreenState extends State<ProcessedScreen> {
  List<Map<String, dynamic>> processedItems = [];
  int currentIndex = 3;

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
          'name': data['name'] ?? '',
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
        };
      }).toList();
    });
  }

  void updateTotalAndVat(Map<String, dynamic> item) {
    double toplamTutar = 0.0;
    item['products'].forEach((product) {
      if (product['Kodu']?.toString() != '' && product['Toplam Fiyat']?.toString() != '') {
        toplamTutar += double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;
      }
    });

    double kdv = toplamTutar * 0.20;
    double genelToplam = toplamTutar + kdv;

    setState(() {
      item['products'].removeWhere((product) =>
      product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
          product['Adet Fiyatı']?.toString() == 'KDV %20' ||
          product['Adet Fiyatı']?.toString() == 'Genel Toplam');

      item['products'].add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Toplam Tutar',
        'Toplam Fiyat': toplamTutar.toStringAsFixed(2),
      });
      item['products'].add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'KDV %20',
        'Toplam Fiyat': kdv.toStringAsFixed(2),
      });
      item['products'].add({
        'Kodu': '',
        'Detay': '',
        'Adet': '',
        'Adet Fiyatı': 'Genel Toplam',
        'Toplam Fiyat': genelToplam.toStringAsFixed(2),
      });
    });
  }

  Widget buildProcessedList() {
    return ListView.builder(
      itemCount: processedItems.length,
      itemBuilder: (context, index) {
        var item = processedItems[index];

        updateTotalAndVat(item); // Güncel toplam tutar ve KDV hesaplama

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
                ],
                rows: item['products'].map<DataRow>((product) {
                  bool isTotalRow = product['Adet Fiyatı']?.toString() == 'Toplam Tutar' ||
                      product['Adet Fiyatı']?.toString() == 'KDV %20' ||
                      product['Adet Fiyatı']?.toString() == 'Genel Toplam';

                  return DataRow(cells: [
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'İşlenenler - ${widget.customerName}'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          ToggleButtons(
            isSelected: [currentIndex == 0, currentIndex == 1, currentIndex == 2, currentIndex == 3],
            onPressed: (int index) {
              setState(() {
                if (index == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerDetailsScreen(customerName: widget.customerName),
                    ),
                  );
                } else {
                  currentIndex = index;
                }
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Teklifler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('İşlenenler'),
              ),
            ],
          ),
          Expanded(child: buildProcessedList()),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
