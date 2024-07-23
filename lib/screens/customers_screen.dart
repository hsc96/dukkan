import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../providers/loading_provider.dart';
import 'customer_details_screen.dart';
import 'update_all_documents.dart';

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<DocumentSnapshot> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  List<Map<String, dynamic>> newCustomers = [];
  List<String> discountLevels = [];
  TextEditingController searchController = TextEditingController();
  bool isAscending = true;
  int sortColumnIndex = 0;
  final ScrollController scrollController = ScrollController();
  bool showFetchButton = false;
  bool isFetchingAdditionalCustomers = false;
  bool isSearching = false;
  double totalInvoiceAmount = 0;


  @override
  void initState() {
    super.initState();
    fetchInitialCustomers();
    fetchDiscountLevels();

    scrollController.addListener(() {
      if (scrollController.position.atEdge) {
        if (scrollController.position.pixels != 0) {
          fetchAdditionalCustomers();
        }
      }
    });

    searchController.addListener(() {
      if (searchController.text.isEmpty) {
        setState(() {
          isSearching = false;
          filteredCustomers = customers.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return {
              'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
              'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
            };
          }).toList();
        });
      } else {
        searchCustomers(searchController.text);
      }
    });
  }


  Future<void> fetchInitialCustomers() async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('Fatura Kesilecek Tutar', isGreaterThan: 0)
          .orderBy('Fatura Kesilecek Tutar', descending: true)
          .limit(50)
          .get();

      var descriptions = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      double totalAmount = querySnapshot.docs.fold(0.0, (sum, doc) {
        var data = doc.data() as Map<String, dynamic>;
        return sum + (data['Fatura Kesilecek Tutar'] ?? 0.0);
      });

      setState(() {
        customers = querySnapshot.docs; // DocumentSnapshot tipini sakla
        filteredCustomers = descriptions;
        totalInvoiceAmount = double.parse(totalAmount.toStringAsFixed(3));
      });

      if (customers.length < 50) {
        await fetchAdditionalAlphabeticalCustomers(50 - customers.length);
      }

      showFetchButton = customers.length < 50;
    } catch (e) {
      print('Error fetching initial customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Müşteri verileri alınamadı: $e'),
        ),
      );
    }
  }


  Future<void> fetchAdditionalAlphabeticalCustomers(int count) async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .orderBy('AçıklamaLowerCase')
          .limit(count)
          .get();

      var descriptions = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      setState(() {
        customers.addAll(querySnapshot.docs);
        filteredCustomers.addAll(descriptions);
      });
    } catch (e) {
      print('Error fetching additional alphabetical customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alfabetik müşteri verileri alınamadı: $e'),
        ),
      );
    }
  }





  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }


  Future<void> fetchAdditionalCustomers([int count = 20]) async {
    if (isFetchingAdditionalCustomers) return;

    setState(() {
      isFetchingAdditionalCustomers = true;
    });

    try {
      var customerDetailsCollection = FirebaseFirestore.instance.collection('veritabanideneme');
      QuerySnapshot querySnapshot;

      if (customers.isNotEmpty) {
        var lastDocument = customers.last as DocumentSnapshot;

        // Fatura Kesilecek Tutar'ı olan müşterileri getir
        querySnapshot = await customerDetailsCollection
            .where('Fatura Kesilecek Tutar', isGreaterThan: 0)
            .orderBy('Fatura Kesilecek Tutar', descending: true)
            .startAfterDocument(lastDocument)
            .limit(count)
            .get();

        if (querySnapshot.docs.isEmpty) {
          // Eğer yeterli veri yoksa, alfabetik olarak diğer verileri getir
          querySnapshot = await customerDetailsCollection
              .orderBy('AçıklamaLowerCase')
              .startAfterDocument(lastDocument)
              .limit(count)
              .get();
        }
      } else {
        querySnapshot = await customerDetailsCollection
            .where('Fatura Kesilecek Tutar', isGreaterThan: 0)
            .orderBy('Fatura Kesilecek Tutar', descending: true)
            .limit(count)
            .get();

        if (querySnapshot.docs.isEmpty) {
          querySnapshot = await customerDetailsCollection
              .orderBy('AçıklamaLowerCase')
              .limit(count)
              .get();
        }
      }

      var additionalCustomers = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      double additionalTotalAmount = querySnapshot.docs.fold(0.0, (sum, doc) {
        var data = doc.data() as Map<String, dynamic>;
        return sum + (data['Fatura Kesilecek Tutar'] ?? 0.0);
      });

      setState(() {
        customers.addAll(querySnapshot.docs);
        filteredCustomers.addAll(additionalCustomers);
        totalInvoiceAmount += additionalTotalAmount;  // Mevcut toplamın üzerine ekle
        totalInvoiceAmount = double.parse(totalInvoiceAmount.toStringAsFixed(3));
        isFetchingAdditionalCustomers = false;
      });
    } catch (e) {
      print('Error fetching additional customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ek müşteri verileri alınamadı: $e'),
        ),
      );
      setState(() {
        isFetchingAdditionalCustomers = false;
      });
    }
  }








  void _addCustomersToList(List<DocumentSnapshot> docs) {
    setState(() {
      var newCustomerData = docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      customers.addAll(docs.where((newCustomer) =>
      !customers.any((existingCustomer) =>
      existingCustomer.id == newCustomer.id
      )));

      filteredCustomers = List.from(customers.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }));
    });
  }


  Future<void> fetchDiscountLevels() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('iskonto')
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      setState(() {
        discountLevels =
            data.keys.where((key) => key != 'a_seviye' && key != 'b_seviye' &&
                key != 'c_seviye').toList();
      });
    }
  }

  Future<void> updateAllDocuments() async {
    var collection = FirebaseFirestore.instance.collection('veritabanideneme');
    var querySnapshot = await collection.get();

    for (var doc in querySnapshot.docs) {
      var data = doc.data();
      String aciklama = data['Açıklama'] ?? '';
      await doc.reference.update({
        'AçıklamaLowerCase': aciklama.toLowerCase(),
      });
    }
  }


  Future<void> searchCustomers(String query) async {
    String lowerCaseQuery = query.toLowerCase();

    try {
      // Veritabanında arama yap
      var querySnapshot = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('AçıklamaLowerCase', isGreaterThanOrEqualTo: lowerCaseQuery)
          .where(
          'AçıklamaLowerCase', isLessThanOrEqualTo: lowerCaseQuery + '\uf8ff')
          .get();

      var descriptions = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      // Mevcut listede arama yap
      var localResults = customers.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String aciklama = data['Açıklama'] ?? '';
        return aciklama.toLowerCase().contains(lowerCaseQuery);
      }).map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      setState(() {
        filteredCustomers = [
          ...descriptions,
          ...localResults.where((localDoc) =>
          !descriptions.any((desc) => desc['Açıklama'] == localDoc['Açıklama']))
        ];
      });
    } catch (e) {
      print('Error searching customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Müşteri araması başarısız: $e'),
        ),
      );
    }
  }
  Future<void> fetchSortedCustomers(bool ascending) async {
    setState(() {
      isFetchingAdditionalCustomers = true;
      customers.clear();
      filteredCustomers.clear();
    });

    try {
      var customerDetailsCollection = FirebaseFirestore.instance.collection('veritabanideneme');
      QuerySnapshot querySnapshot;

      querySnapshot = await customerDetailsCollection
          .orderBy('Fatura Kesilecek Tutar', descending: !ascending)
          .limit(50)
          .get();

      var sortedCustomers = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
          'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
        };
      }).toList();

      double totalAmount = querySnapshot.docs.fold(0.0, (sum, doc) {
        var data = doc.data() as Map<String, dynamic>;
        return sum + (data['Fatura Kesilecek Tutar'] ?? 0.0);
      });

      setState(() {
        customers = querySnapshot.docs;
        filteredCustomers = sortedCustomers;
        totalInvoiceAmount = double.parse(totalAmount.toStringAsFixed(3));
        isFetchingAdditionalCustomers = false;
      });
    } catch (e) {
      print('Error fetching sorted customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sıralı müşteri verileri alınamadı: $e'),
        ),
      );
      setState(() {
        isFetchingAdditionalCustomers = false;
      });
    }
  }




  void sortCustomers(int columnIndex, bool ascending) {
    if (columnIndex == 0) {
      filteredCustomers.sort((a, b) =>
      ascending ? a['Açıklama'].compareTo(b['Açıklama']) : b['Açıklama'].compareTo(a['Açıklama']));
      setState(() {
        sortColumnIndex = columnIndex;
        isAscending = ascending;
      });
    } else if (columnIndex == 1) {
      fetchSortedCustomers(ascending);
    }
  }



  Future<void> pickJsonFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        Provider.of<LoadingProvider>(context, listen: false).startLoading();

        String filePath = result.files.single.path!;
        String jsonString = await File(filePath).readAsString();
        List<dynamic> jsonData = json.decode(jsonString);
        List<Map<String, dynamic>> newCustomersList = List<
            Map<String, dynamic>>.from(jsonData);

        await addCustomers(newCustomersList);

        Provider.of<LoadingProvider>(context, listen: false).stopLoading();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newCustomersList.length} yeni müşteri eklendi!'),
            duration: Duration(seconds: 3),
          ),
        );

        showNewCustomersForDiscount();
      }
    } catch (e) {
      Provider.of<LoadingProvider>(context, listen: false).stopLoading();
      print('Dosya okuma hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya yüklenirken bir hata oluştu!'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> addCustomers(List<Map<String, dynamic>> newCustomersList) async {
    var collection = FirebaseFirestore.instance.collection('veritabanideneme');
    int addedCount = 0;

    for (var i = 0; i < newCustomersList.length; i++) {
      var newCustomer = newCustomersList[i];
      String code = newCustomer['Kodu'];
      String taxNumber = newCustomer['Vergi Kimlik Numarası'];
      String idNumber = newCustomer['T.C. Kimlik Numarası'];

      var query = await collection.where('Kodu', isEqualTo: code).get();

      if (query.docs.isEmpty) {
        // Eğer Fatura Kesilecek Tutar alanı yoksa ekle
        if (!newCustomer.containsKey('Fatura Kesilecek Tutar')) {
          newCustomer['Fatura Kesilecek Tutar'] = 0.0;
        }

        // Açıklama alanını küçük harfe çevir
        if (newCustomer.containsKey('Açıklama')) {
          newCustomer['AçıklamaLowerCase'] = (newCustomer['Açıklama'] ?? '').toLowerCase();
        }

        await collection.add(newCustomer);
        addedCount++;
        newCustomers.add(newCustomer);
      }

      Provider.of<LoadingProvider>(context, listen: false).updateProgress(
          (i + 1) / newCustomersList.length);
    }

    fetchInitialCustomers(); // Yeni müşteri listesini almak için çağır

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$addedCount yeni müşteri veritabanına eklendi!'),
        duration: Duration(seconds: 3),
      ),
    );
  }



  void showNewCustomersForDiscount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Yeni Müşteriler İskonto Eşleştirme'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: newCustomers.length,
              itemBuilder: (context, index) {
                var customer = newCustomers[index];
                return ListTile(
                  title: Text(customer['Açıklama'] ?? ''),
                  subtitle: DropdownButton<String>(
                    hint: Text('İskonto Seviye Seçin'),
                    value: customer['iskonto'],
                    onChanged: (String? newValue) {
                      setState(() {
                        customer['iskonto'] = newValue;
                      });
                    },
                    items: [
                      'A Seviye',
                      'B Seviye',
                      'C Seviye',
                      ...discountLevels
                    ].map((String level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => saveCustomerDiscount(customer),
                    child: Text('Kaydet'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> saveCustomerDiscount(Map<String, dynamic> customer) async {
    var customerCollection = FirebaseFirestore.instance.collection(
        'veritabanideneme');
    var querySnapshot = await customerCollection.where(
        'Kodu', isEqualTo: customer['Kodu']).get();

    if (querySnapshot.docs.isNotEmpty) {
      var docRef = querySnapshot.docs.first.reference;
      await docRef.update({
        'iskonto': customer['iskonto']
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İskonto kaydedildi')),
      );
    }
  }

  void navigateToCustomerDetails(String customerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsScreen(customerName: customerName),
      ),
    );
  }

  @override
  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Müşteriler'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (query) {
                      setState(() {
                        isSearching = true;
                      });
                      searchCustomers(query);
                    },
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
                  icon: Icon(Icons.add, color: colorTheme5),
                  onPressed: pickJsonFile,
                ),
                IconButton(
                  icon: Icon(Icons.update, color: colorTheme5),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UpdateAllDocumentsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Consumer<LoadingProvider>(
            builder: (context, loadingProvider, child) {
              return loadingProvider.isLoading
                  ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: loadingProvider.progress),
                    SizedBox(height: 8),
                    Text('Lütfen bekleyin, veriler yükleniyor...'),
                  ],
                ),
              )
                  : Container();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    DataTable(
                      columns: [
                        DataColumn(
                          label: Text('FATURA KESİLECEK TUTAR'),
                          onSort: (columnIndex, ascending) =>
                              sortCustomers(columnIndex, ascending),
                        ),
                        DataColumn(
                          label: Text('MÜŞTERİ'),

                        ),
                      ],
                      rows: filteredCustomers.map((customer) {
                        return DataRow(cells: [
                          DataCell(Text(
                              customer['Fatura Kesilecek Tutar'].toString())),
                          DataCell(
                            Text(customer['Açıklama']),
                            onTap: () => navigateToCustomerDetails(
                                customer['Açıklama']),
                          ),
                        ]);
                      }).toList(),
                    ),
                    if (showFetchButton)
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showFetchButton = false;
                            });
                            fetchAdditionalCustomers(20);
                          },
                          child: Text('Müşteri Getir'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'toplam fatura tutarı: $totalInvoiceAmount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          CustomBottomBar(),
        ],
      ),
    );
  }


}