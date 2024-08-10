import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'package:flutter/cupertino.dart'; // CupertinoIcons için gerekli import
import '../utils/colors.dart'; // Renk tanımlarını içe aktar

class CustomHeaderScreen extends StatefulWidget {
  @override
  _CustomHeaderScreenState createState() => _CustomHeaderScreenState();
}

class _CustomHeaderScreenState extends State<CustomHeaderScreen> {
  List<Map<String, dynamic>> users = [];
  Map<String, Map<String, dynamic>> salesAndQuotesData = {};
  Map<String, Map<String, dynamic>> previousSalesData = {};

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

  // Seçilen müşteri bilgisini almak için Stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> getSelectedCustomerStream() {
    return FirebaseFirestore.instance
        .collection('selectedCustomer')
        .doc('current')
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
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: getSelectedCustomerStream(),
              builder: (context, snapshot) {
                String selectedCustomerName = 'Müşteri Seçilmedi';
                String totalAmount = '0.00 TL';

                if (snapshot.hasData && snapshot.data?.data() != null) {
                  selectedCustomerName = snapshot.data!.data()!['customerName'] ?? 'Müşteri Seçilmedi';
                  totalAmount = snapshot.data!.data()!['totalAmount'] ?? '0.00 TL';
                }

                return Positioned(
                  top: 21.0,
                  left: 0.0,
                  right: 0.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
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
                                  selectedCustomerName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  'Toplam Tutar: $totalAmount',
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
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 180.0,
              left: MediaQuery
                  .of(context)
                  .size
                  .width / 2 - 60,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/scan');
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
                                                          .entries
                                                          .map<Widget>((entry) {
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
                                                              String productName = product['name'] ??
                                                                  'Ürün Bilgisi Yok';
                                                              double unitPrice = product['unitPrice'] ??
                                                                  0.0;
                                                              int quantity = product['quantity'] ??
                                                                  0;
                                                              double totalPrice = product['totalPrice'] ??
                                                                  0.0;

                                                              return ListTile(
                                                                title: Text(
                                                                    productName),
                                                                subtitle: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment
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