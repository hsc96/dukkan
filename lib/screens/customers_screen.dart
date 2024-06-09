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
import 'customer_details_screen.dart'; // CustomerDetailsScreen import edildi

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  List<Map<String, dynamic>> newCustomers = [];
  List<String> discountLevels = [];
  TextEditingController searchController = TextEditingController();
  bool isAscending = true;
  int sortColumnIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchCustomers();
    fetchDiscountLevels();
  }

  Future<void> fetchCustomers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('veritabanideneme').get();
    var docs = querySnapshot.docs;
    var descriptions = docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
        'Fatura Kesilecek Tutar': (data['Açıklama'] == 'Müşteri 1') ? 10 : (data['Açıklama'] == 'Müşteri 2') ? 15 : 20
      };
    }).toList();

    setState(() {
      customers = descriptions;
      filteredCustomers = descriptions;
    });
  }

  Future<void> fetchDiscountLevels() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('iskonto').get();
    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      setState(() {
        discountLevels = data.keys.where((key) => key != 'a_seviye' && key != 'b_seviye' && key != 'c_seviye').toList();
      });
    }
  }

  void filterCustomers(String query) {
    setState(() {
      filteredCustomers = customers
          .where((customer) => customer['Açıklama'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void sortCustomers(int columnIndex, bool ascending) {
    if (columnIndex == 0) {
      filteredCustomers.sort((a, b) =>
      ascending ? a['Açıklama'].compareTo(b['Açıklama']) : b['Açıklama'].compareTo(a['Açıklama']));
    } else if (columnIndex == 1) {
      filteredCustomers.sort((a, b) => ascending
          ? a['Fatura Kesilecek Tutar'].compareTo(b['Fatura Kesilecek Tutar'])
          : b['Fatura Kesilecek Tutar'].compareTo(a['Fatura Kesilecek Tutar']));
    }
    setState(() {
      sortColumnIndex = columnIndex;
      isAscending = ascending;
    });
  }

  Future<void> pickJsonFile() async {
    try {
      // Dosya seç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        Provider.of<LoadingProvider>(context, listen: false).startLoading();

        // Dosya yolu
        String filePath = result.files.single.path!;

        // Dosyayı oku
        String jsonString = await File(filePath).readAsString();

        // JSON'u çöz
        List<dynamic> jsonData = json.decode(jsonString);

        // JSON'u analiz et
        List<Map<String, dynamic>> newCustomersList = List<Map<String, dynamic>>.from(jsonData);

        // Var olan müşterilerle karşılaştır ve ekle
        await addCustomers(newCustomersList);

        Provider.of<LoadingProvider>(context, listen: false).stopLoading();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newCustomersList.length} yeni müşteri eklendi!'),
            duration: Duration(seconds: 3),
          ),
        );

        // Yeni eklenen müşterilerle iskonto eşleştirme işlemi
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
        await collection.add(newCustomer);
        addedCount++;
        newCustomers.add(newCustomer);
      }

      Provider.of<LoadingProvider>(context, listen: false).updateProgress((i + 1) / newCustomersList.length);
    }

    fetchCustomers(); // Yeni müşteri listesini almak için çağır

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
                    items: ['A Seviye', 'B Seviye', 'C Seviye', ...discountLevels].map((String level) {
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
    var customerCollection = FirebaseFirestore.instance.collection('veritabanideneme');
    var querySnapshot = await customerCollection.where('Kodu', isEqualTo: customer['Kodu']).get();

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
                    onChanged: (query) => filterCustomers(query),
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
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text('FATURA KESİLECEK TUTAR'),
                      onSort: (columnIndex, ascending) => sortCustomers(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: Text('MÜŞTERİ'),
                      onSort: (columnIndex, ascending) => sortCustomers(columnIndex, ascending),
                    ),
                  ],
                  rows: filteredCustomers.map((customer) {
                    return DataRow(cells: [
                      DataCell(Text(customer['Fatura Kesilecek Tutar'].toString())),
                      DataCell(
                        Text(customer['Açıklama']),
                        onTap: () => navigateToCustomerDetails(customer['Açıklama']),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
