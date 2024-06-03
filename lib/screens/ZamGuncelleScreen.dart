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
  bool isAscending = true;
  String sortColumn = 'tarih';

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
      sortZamListesi();
    });
  }

  void sortZamListesi() {
    setState(() {
      zamListesi.sort((a, b) {
        int compare;
        if (sortColumn == 'tarih') {
          compare = DateTime.parse(a['tarih']).compareTo(DateTime.parse(b['tarih']));
          if (compare == 0) {
            compare = a['tarih'].compareTo(b['tarih']);
          }
        } else if (sortColumn == 'zam orani') {
          compare = (a['zam orani'] as num).compareTo(b['zam orani']);
        } else {
          compare = (a['markalar'] as String).compareTo(b['markalar'] as String);
        }
        return isAscending ? compare : -compare;
      });
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
      sortZamListesi();
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

  void selectAllKSTSBrands() {
    setState(() {
      if (selectedBrands.any((brand) => brand.startsWith('KSTS'))) {
        selectedBrands.removeWhere((brand) => brand.startsWith('KSTS'));
      } else {
        selectedBrands.addAll(brands.where((brand) => brand.startsWith('KSTS')).toList());
      }
    });
  }

  void onSort(String column) {
    setState(() {
      if (sortColumn == column) {
        isAscending = !isAscending;
      } else {
        sortColumn = column;
        isAscending = true;
      }
      sortZamListesi();
    });
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
            GestureDetector(
              onTap: () {
                setState(() {
                  isDropdownOpen = !isDropdownOpen;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Marka Seç'),
                    Icon(isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            if (isDropdownOpen)
              Container(
                height: 300,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: selectAllKSTSBrands,
                      child: Text('KSTS Tüm Ürünler'),
                    ),
                    Expanded(
                      child: ListView(
                        children: brands.map((String value) {
                          return CheckboxListTile(
                            title: Text(value),
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
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
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
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    sortAscending: isAscending,
                    sortColumnIndex: sortColumn == 'tarih'
                        ? 0
                        : sortColumn == 'markalar'
                        ? 1
                        : 2,
                    columns: [
                      DataColumn(
                        label: Text('Tarih'),
                        onSort: (columnIndex, _) => onSort('tarih'),
                      ),
                      DataColumn(
                        label: Text('Markalar'),
                        onSort: (columnIndex, _) => onSort('markalar'),
                      ),
                      DataColumn(
                        label: Text('Zam Oranı (%)'),
                        onSort: (columnIndex, _) => onSort('zam orani'),
                      ),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
