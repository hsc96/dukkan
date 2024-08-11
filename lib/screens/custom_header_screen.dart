import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'scan_screen.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';

class CustomHeaderScreen extends StatefulWidget {
  @override
  _CustomHeaderScreenState createState() => _CustomHeaderScreenState();
}

class _CustomHeaderScreenState extends State<CustomHeaderScreen> {
  List<Map<String, dynamic>> users = [];
  Map<String, Map<String, dynamic>> salesAndQuotesData = {};
  Map<String, Map<String, dynamic>> previousSalesData = {};
  List<Map<String, String>> selectedCustomers = [];
  List<Map<String, String>> temporarySelections = []; // Define the list here


  @override
  void initState() {
    super.initState();
    fetchUsers();

  }

  Future<void> fetchUsers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('users')
        .get();
    var docs = querySnapshot.docs;

    setState(() {
      users = docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['fullName'] ?? 'Bilinmiyor',
        };
      }).toList();
    });

    fetchSalesAndQuotesData();
  }

  Future<void> fetchSalesAndQuotesData() async {
    var today = DateFormat('dd.MM.yyyy').format(DateTime.now());

    // Önceki verileri temizle
    salesAndQuotesData.clear();

    for (var user in users) {
      var userId = user['id'];

      // Kullanıcının bugünkü satış verilerini al
      var salesQuerySnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: today)
          .get();

      // Kullanıcının bugünkü teklif verilerini al
      var quotesQuerySnapshot = await FirebaseFirestore.instance
          .collection('quotes')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: today)
          .get();

      int salesCount = salesQuerySnapshot.docs.length;
      int quotesCount = quotesQuerySnapshot.docs.length;

      // Müşteriye göre satış verilerini toplamak için bir harita başlat
      Map<String, Map<String, dynamic>> aggregatedSales = {};

      for (var doc in salesQuerySnapshot.docs) {
        var data = doc.data();
        var customerName = data['customerName'] ?? 'Unknown Customer';

        // Miktarı güvenli bir şekilde parse et
        double amount = 0.0;
        if (data['amount'] is String) {
          amount = double.tryParse(data['amount']) ?? 0.0;
        } else if (data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        }

        // Ürün detaylarını al
        List<dynamic> products = data['products'] ?? [];
        Map<String, Map<String, dynamic>> productMap = {};

        // Ürün verilerini toplamak
        for (var product in products) {
          String productName = product['Detay'] ?? 'Ürün Bilgisi Yok';
          double unitPrice = double.tryParse(
              product['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
          int quantity = int.tryParse(product['Adet']?.toString() ?? '0') ?? 0;
          double totalPrice = double.tryParse(
              product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;

          // Ürün verilerini toplamak
          if (!productMap.containsKey(productName)) {
            productMap[productName] = {
              'unitPrice': unitPrice,
              'quantity': quantity,
              'totalPrice': totalPrice,
            };
          } else {
            // Eğer ürün zaten varsa, toplam değerlerini güncelle
            productMap[productName]!['quantity'] += quantity;
            productMap[productName]!['totalPrice'] += totalPrice;
          }
        }

        // Satış verilerini toplamak
        if (!aggregatedSales.containsKey(customerName)) {
          aggregatedSales[customerName] = {
            'totalAmount': 0.0,
            'products': <Map<String, dynamic>>[],
          };
        }

        aggregatedSales[customerName]!['totalAmount'] += amount;

        // Ürün detayları listesini güncelle
        List<Map<String, dynamic>> productDetails = productMap.entries.map((
            entry) {
          return {
            'name': entry.key,
            'unitPrice': entry.value['unitPrice'],
            'quantity': entry.value['quantity'],
            'totalPrice': entry.value['totalPrice'],
          };
        }).toList();

        aggregatedSales[customerName]!['products'].addAll(productDetails);
      }

      // Toplanan ve toplanmış verilerle durumu güncelle
      setState(() {
        salesAndQuotesData[user['name']] = {
          'salesCount': salesCount,
          'quotesCount': quotesCount,
          'salesDetails': aggregatedSales,
        };
      });
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> gettemporarySelections() {
    return FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc('current')
        .snapshots();
  }

  void addNewCustomer(String customerName, String totalAmount) {
    setState(() {
      temporarySelections.add({
        'customerName': customerName,
        'totalAmount': totalAmount,
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> gettemporarySelectionsStream() {
    return FirebaseFirestore.instance
        .collection('temporarySelections')
        .snapshots();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Coşkun Sızdırmazlık'),
      endDrawer: CustomDrawer(),
      body: Container(
        color: colorTheme2,
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('temporarySelections').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                List<Map<String, String>> temporarySelections = [];

                for (var doc in snapshot.data!.docs) {
                  String customerName = doc.data()['customerName'] ?? 'Müşteri Seçilmedi';
                  String totalAmount = '0.00 TL';

                  var products = doc.data()['products'] as List<dynamic>?;
                  if (products != null) {
                    var genelToplamEntry = products.firstWhere(
                          (product) => product['Adet Fiyatı'] == 'Genel Toplam',
                      orElse: () => null,
                    );
                    if (genelToplamEntry != null) {
                      totalAmount = genelToplamEntry['Toplam Fiyat'] ?? '0.00';
                    }
                  }

                  // temporarySelections için güncelleme yapalım
                  temporarySelections.add({
                    'customerName': customerName,
                    'totalAmount': totalAmount,
                  });
                }

                return Positioned(
                  top: 21.0,
                  left: 0.0,
                  right: 0.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: temporarySelections.map((customer) {
                        return GestureDetector(
                          onTap: () async {
                            // Veriyi çekmek için currentX alanına göre belirlenecek
                            String collectionPath = 'temporarySelections';
                            String? documentId = customer['field']; // Müşteriye göre currentX field'ı

                            if (documentId != null) {
                              DocumentSnapshot<Map<String, dynamic>> currentData = await FirebaseFirestore.instance
                                  .collection(collectionPath)
                                  .doc(documentId)
                                  .get();

                              if (currentData.exists) {
                                String customerName = currentData.data()?['customerName'] ?? 'Müşteri Seçilmedi';
                                String totalAmount = '0.00 TL';

                                var products = currentData.data()?['products'] as List<dynamic>?;
                                if (products != null) {
                                  var genelToplamEntry = products.firstWhere(
                                        (product) => product['Adet Fiyatı'] == 'Genel Toplam',
                                    orElse: () => null,
                                  );
                                  if (genelToplamEntry != null) {
                                    totalAmount = genelToplamEntry['Toplam Fiyat'] ?? '0.00';
                                  }
                                }

                                // Seçilen müşteri bilgilerini güncelle
                                setState(() {
                                  selectedCustomers.clear();
                                  selectedCustomers.add({
                                    'customerName': customerName,
                                    'totalAmount': totalAmount,
                                  });
                                });

                                // ScanScreen sayfasına git
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScanScreen(onCustomerProcessed: (data) {}),
                                  ),
                                );
                              }
                            } else {
                              print("Müşteri field bilgisi bulunamadı.");
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0),
                            width: (MediaQuery.of(context).size.width - 56) / 4,
                            child: Card(
                              color: const Color(0xFF0C2B40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: 12.0),
                                  Text(
                                    customer['customerName']!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4.0),
                                  Text(
                                    'Toplam Tutar: ${customer['totalAmount']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                      }).toList(),
                    ),
                  ),
                );
              },
            ),


            Positioned(
              top: 180.0,
              left: MediaQuery.of(context).size.width / 2 - 60,
              child: GestureDetector(
                onTap: () async {
                  // Yeni müşteri işlemleri için currentX kullanılacak
                  var temporarySelections = FirebaseFirestore.instance.collection('temporarySelections');
                  var querySnapshot = await temporarySelections.get();

                  List<String> existingCurrentFields = querySnapshot.docs.map((doc) => doc.id).toList();

                  int maxCurrentNumber = 1;

                  for (var field in existingCurrentFields) {
                    if (field.startsWith('current')) {
                      String numberStr = field.replaceAll('current', '');
                      int? number = int.tryParse(numberStr);
                      if (number != null && number >= maxCurrentNumber) {
                        maxCurrentNumber = number + 1;
                      }
                    }
                  }

                  String newCurrentField = 'current$maxCurrentNumber';

                  // Yeni müşteri için yeni currentX alanını oluştur
                  await temporarySelections.doc(newCurrentField).set({
                    'customerName': '',
                    'products': [],
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScanScreen(onCustomerProcessed: (data) {})),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.barcode,
                        size: 120,
                        color: colorTheme5,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Ürün Tara',
                        style: TextStyle(
                          color: colorTheme5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 320.0,
              left: 0.0,
              right: 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20.0),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Table(
                          border: TableBorder.all(color: Colors.black),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(children: [
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Satış Elemanı',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Satış',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Teklif',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ]),
                            ...users.map((user) {
                              String userName = user['name'];
                              var userSalesDetails = salesAndQuotesData[userName]?['salesDetails'] ??
                                  {};

                              return TableRow(children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: InkWell(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (BuildContext context) {
                                            var mergedSalesDetails = {
                                              ...previousSalesData[userName] ??
                                                  {},
                                              ...userSalesDetails
                                            };

                                            previousSalesData[userName] =
                                                mergedSalesDetails.map((key,
                                                    value) {
                                                  return MapEntry(
                                                      key,
                                                      Map<String, dynamic>.from(
                                                          value));
                                                });

                                            return FractionallySizedBox(
                                              heightFactor: 0.8,
                                              child: Column(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(16),
                                                    child: Text(
                                                      '$userName - Satış Detayları',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight: FontWeight
                                                              .bold),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: ListView(
                                                      children: mergedSalesDetails
                                                          .entries.map<Widget>((
                                                          entry) {
                                                        String customerName = entry
                                                            .key;
                                                        var details = entry
                                                            .value;
                                                        double totalAmount =
                                                            details['totalAmount'] ??
                                                                0.0;
                                                        List<Map<String,
                                                            dynamic>> products =
                                                            details['products'] ??
                                                                [];

                                                        return ExpansionTile(
                                                          title: Text(
                                                              '$customerName - Toplam: ${totalAmount
                                                                  .toStringAsFixed(
                                                                  2)} TL'),
                                                          children: [
                                                            ...products.map<
                                                                Widget>((
                                                                product) {
                                                              String productName =
                                                                  product['name'] ??
                                                                      'Ürün Bilgisi Yok';
                                                              double unitPrice =
                                                                  product['unitPrice'] ??
                                                                      0.0;
                                                              int quantity = product['quantity'] ??
                                                                  0;
                                                              double totalPrice =
                                                                  product['totalPrice'] ??
                                                                      0.0;

                                                              return ListTile(
                                                                title: Text(
                                                                    productName),
                                                                subtitle: Column(
                                                                  crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                                  children: [
                                                                    Text(
                                                                        'Adet Fiyatı: ${unitPrice
                                                                            .toStringAsFixed(
                                                                            2)} TL'),
                                                                    Text(
                                                                        'Adet: $quantity'),
                                                                    Text(
                                                                        'Toplam Fiyat: ${totalPrice
                                                                            .toStringAsFixed(
                                                                            2)} TL'),
                                                                  ],
                                                                ),
                                                              );
                                                            }).toList(),
                                                            Divider(
                                                              color: Colors
                                                                  .black,
                                                              thickness: 1,
                                                            ),
                                                            ListTile(
                                                              title: Text(
                                                                  'Genel Toplam'),
                                                              subtitle: Text(
                                                                  '${totalAmount
                                                                      .toStringAsFixed(
                                                                      2)} TL'),
                                                            ),
                                                          ],
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: Text(userName),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        salesAndQuotesData[userName]?['salesCount']
                                            ?.toString() ??
                                            '0'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        salesAndQuotesData[userName]?['quotesCount']
                                            ?.toString() ??
                                            '0'),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ],
                        ),
                      ),
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
}
