import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'firestore_service.dart';

class ZamGuncelleScreen extends StatefulWidget {
  @override
  _ZamGuncelleScreenState createState() => _ZamGuncelleScreenState();
}

class _ZamGuncelleScreenState extends State<ZamGuncelleScreen> {
  final FirestoreService firestoreService = FirestoreService();
  TextEditingController zamOraniController = TextEditingController();
  List<String> brands = [];
  List<String> selectedBrands = [];
  bool isDropdownOpen = false;
  List<Map<String, dynamic>> zamListesi = [];

  @override
  void initState() {
    super.initState();
    fetchUniqueBrands();
    fetchZamListesi();
  }

  Future<void> fetchUniqueBrands() async {
    var brandList = await firestoreService.fetchUniqueBrands();
    setState(() {
      brands = brandList;
    });
  }

  Future<void> fetchZamListesi() async {
    var zamList = await firestoreService.fetchZamListesi();
    setState(() {
      zamListesi = zamList ?? [];
    });
  }

  void updatePrices() {
    double zamOrani = double.tryParse(zamOraniController.text) ?? 0.0;
    if (selectedBrands.isNotEmpty) {
      _showConfirmationDialog(zamOrani);
    }
  }

  void _showConfirmationDialog(double zamOrani) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Güncelleme Onayı'),
          content: Text('Güncellemek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showFinalConfirmationDialog(zamOrani);
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  void _showFinalConfirmationDialog(double zamOrani) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Zam Onayı'),
          content: Text('${selectedBrands.join(', ')} markalı ürünlere %$zamOrani zam yapılacak. Onaylıyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                firestoreService.updateProductPricesByBrands(selectedBrands, zamOrani);
                _addZamToCollectionAndList(zamOrani);
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  void _addZamToCollectionAndList(double zamOrani) async {
    String tarih = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());
    String markalar = selectedBrands.join(', ');

    await firestoreService.addZamToCollection(markalar, tarih, 'admin', zamOrani);

    setState(() {
      zamListesi.add({
        'tarih': tarih,
        'markalar': markalar,
        'yetkili': 'admin',
        'zam orani': zamOrani
      });
      selectedBrands.clear();
      zamOraniController.clear();
    });
  }

  void _showBrandDetail(String brandDetail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Marka Detayı'),
          content: Text(brandDetail),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Zam Güncelle'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    hint: Text('Marka Seç'),
                    value: null,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      setState(() {
                        if (selectedBrands.contains(newValue)) {
                          selectedBrands.remove(newValue);
                        } else {
                          selectedBrands.add(newValue!);
                        }
                      });
                    },
                    items: brands.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Checkbox(
                              value: selectedBrands.contains(value),
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedBrands.add(value);
                                  } else {
                                    selectedBrands.remove(value);
                                  }
                                });
                              },
                            ),
                            Text(value),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isDropdownOpen = false;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            TextField(
              controller: zamOraniController,
              decoration: InputDecoration(
                labelText: 'Zam Oranı (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: updatePrices,
              child: Text('Fiyatları Güncelle'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,  // Tabloyu yatay yapar
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Tarih')),
                    DataColumn(label: Text('Markalar')),
                    DataColumn(label: Text('Zam Oranı (%)')),
                  ],
                  rows: zamListesi.map((zam) {
                    return DataRow(cells: [
                      DataCell(Text(zam['tarih'] ?? '')),
                      DataCell(
                        GestureDetector(
                          onTap: () => _showBrandDetail(zam['markalar'] ?? ''),
                          child: Text(
                            zam['markalar'] != null && (zam['markalar'] as String).length > 20
                                ? (zam['markalar'] as String).substring(0, 20) + '...'
                                : zam['markalar'] ?? '',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(zam['zam orani']?.toString() ?? '')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
