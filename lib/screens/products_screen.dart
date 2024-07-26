import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'purchase_history_screen.dart';
class ProductsScreen extends StatefulWidget {
  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> products = [];
  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  bool hasMore = true;
  String searchQuery = '';
  List<String> selectedDoviz = [];
  List<String> selectedMarka = [];

  @override
  void initState() {
    super.initState();
    fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        fetchProducts();
      }
    });
  }

  Future<void> fetchProducts() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('urunler')
        .orderBy('Kodu')
        .limit(50);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }

    try {
      var querySnapshot = await query.get();
      print('Fetched ${querySnapshot.docs.length} documents');

      var filteredDocs = querySnapshot.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        bool matchesDoviz = selectedDoviz.isEmpty || selectedDoviz.contains(data['Doviz']);
        bool matchesMarka = selectedMarka.isEmpty || selectedMarka.contains(data['Marka']);
        return matchesDoviz && matchesMarka;
      }).toList();

      print('Filtered ${filteredDocs.length} documents based on selectedDoviz and selectedMarka');

      if (filteredDocs.isNotEmpty) {
        lastDocument = filteredDocs.last;

        var newProducts = filteredDocs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'Ana Birim': data['Ana Birim'] ?? '',
            'Barkod': data['Barkod'] ?? '',
            'Detay': data['Detay'] ?? '',
            'Doviz': data['Doviz'] ?? '',
            'Fiyat': data['Fiyat'] ?? '',
            'Kodu': data['Kodu'] ?? '',
            'Marka': data['Marka'] ?? '',
          };
        }).toList();

        // Mükerrer kontrolü
        var existingKoduSet = products.map((product) => product['Kodu']).toSet();
        var filteredProducts = newProducts.where((product) => !existingKoduSet.contains(product['Kodu'])).toList();

        print('Adding ${filteredProducts.length} new products to the list');

        setState(() {
          products.addAll(filteredProducts);
        });

        if (filteredProducts.isEmpty) {
          setState(() {
            hasMore = false;
          });
        }
      } else {
        setState(() {
          hasMore = false;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void searchProducts(String query) {
    setState(() {
      searchQuery = query;
      products.clear();
      lastDocument = null;
      hasMore = true;
    });

    if (selectedDoviz.isNotEmpty || selectedMarka.isNotEmpty) {
      fetchProducts();
    } else {
      // Eğer filtreleme yapılmamışsa, doğrudan veritabanında arama yap
      Query koduQuery = FirebaseFirestore.instance
          .collection('urunler')
          .where('Kodu', isGreaterThanOrEqualTo: searchQuery)
          .where('Kodu', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(50);

      Query detayQuery = FirebaseFirestore.instance
          .collection('urunler')
          .where('Detay', isGreaterThanOrEqualTo: searchQuery)
          .where('Detay', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(50);

      Future.wait([koduQuery.get(), detayQuery.get()]).then((results) {
        var allDocs = [...results[0].docs, ...results[1].docs];
        print('Search returned ${allDocs.length} documents');

        var uniqueDocs = allDocs.toSet().toList();
        print('Unique documents count: ${uniqueDocs.length}');

        if (uniqueDocs.isNotEmpty) {
          lastDocument = uniqueDocs.last;

          var newProducts = uniqueDocs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return {
              'Ana Birim': data['Ana Birim'] ?? '',
              'Barkod': data['Barkod'] ?? '',
              'Detay': data['Detay'] ?? '',
              'Doviz': data['Doviz'] ?? '',
              'Fiyat': data['Fiyat'] ?? '',
              'Kodu': data['Kodu'] ?? '',
              'Marka': data['Marka'] ?? '',
            };
          }).toList();

          // Mükerrer kontrolü
          var existingKoduSet = products.map((product) => product['Kodu']).toSet();
          var filteredProducts = newProducts.where((product) => !existingKoduSet.contains(product['Kodu'])).toList();

          print('Adding ${filteredProducts.length} new products to the list after search');

          setState(() {
            products.addAll(filteredProducts);
          });

          if (filteredProducts.isEmpty) {
            setState(() {
              hasMore = false;
            });
          }
        } else {
          setState(() {
            hasMore = false;
          });
        }
      }).catchError((error) {
        print('Error searching products: $error');
      });
    }
  }

  void showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filtrele'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text('Döviz:'),
                FilterChipWidget(
                  filterList: selectedDoviz,
                  filterType: 'Doviz',
                  onSelectionChanged: (selectedList) {
                    setState(() {
                      selectedDoviz = selectedList;
                    });
                  },
                ),
                SizedBox(height: 20),
                Text('Marka:'),
                FilterChipWidget(
                  filterList: selectedMarka,
                  filterType: 'Marka',
                  onSelectionChanged: (selectedList) {
                    setState(() {
                      selectedMarka = selectedList;
                    });
                  },
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
              child: Text('Filtrele'),
              onPressed: () {
                setState(() {
                  products.clear();
                  lastDocument = null;
                  hasMore = true;
                });
                fetchProducts();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildProductsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text('Ana Birim')),
          DataColumn(label: Text('Barkod')),
          DataColumn(label: Text('Detay')),
          DataColumn(label: Text('Doviz')),
          DataColumn(label: Text('Fiyat')),
          DataColumn(label: Text('Kodu')),
          DataColumn(label: Text('Marka')),
        ],
        rows: products.map((product) {
          return DataRow(cells: [
            DataCell(Text(product['Ana Birim'])),
            DataCell(Text(product['Barkod'])),
            DataCell(Text(product['Detay'])),
            DataCell(Text(product['Doviz'])),
            DataCell(Text(product['Fiyat'].toString())),
            DataCell(
              Text(product['Kodu']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseHistoryScreen(
                      productId: product['Kodu'],
                        productDetail: product['Detay'],

                    ),
                  ),
                );
              },
            ),
            DataCell(Text(product['Marka'])),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Ürünler'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Arama',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: searchProducts,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: showFilterDialog,
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: products.isEmpty && !isLoading
                  ? Center(child: Text('Veri bulunamadı'))
                  : SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    buildProductsTable(),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class FilterChipWidget extends StatefulWidget {
  final List<String> filterList;
  final String filterType;
  final ValueChanged<List<String>> onSelectionChanged;

  FilterChipWidget({required this.filterList, required this.filterType, required this.onSelectionChanged});

  @override
  _FilterChipWidgetState createState() => _FilterChipWidgetState();
}

class _FilterChipWidgetState extends State<FilterChipWidget> {
  List<String> selectedFilters = [];

  @override
  void initState() {
    super.initState();
    selectedFilters = widget.filterList;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('urunler').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        List<String> filters = [];
        snapshot.data!.docs.forEach((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String value = data[widget.filterType] ?? '';
          if (!filters.contains(value)) {
            filters.add(value);
          }
        });

        return Wrap(
          spacing: 8.0,
          children: filters.map((filter) {
            return FilterChip(
              label: Text(filter),
              selected: selectedFilters.contains(filter),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedFilters.add(filter);
                  } else {
                    selectedFilters.removeWhere((String name) {
                      return name == filter;
                    });
                  }
                });
                widget.onSelectionChanged(selectedFilters);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
