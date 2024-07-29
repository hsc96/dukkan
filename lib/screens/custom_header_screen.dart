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

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('users').get();
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

    for (var user in users) {
      var userId = user['id'];

      var salesQuerySnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: today)
          .get();

      var quotesQuerySnapshot = await FirebaseFirestore.instance
          .collection('quotes')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: today)
          .get();

      int salesCount = salesQuerySnapshot.docs.length;
      int quotesCount = quotesQuerySnapshot.docs.length;

      List<Map<String, dynamic>> salesDetails = salesQuerySnapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        salesAndQuotesData[user['name']] = {
          'salesCount': salesCount,
          'quotesCount': quotesCount,
          'salesDetails': salesDetails,
        };
      });
    }
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
            Positioned(
              top: 21.0,
              left: 0.0,
              right: 0.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(users.length, (index) {
                    return Container(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? Colors.orange
                                        : index == 1
                                        ? Colors.blue
                                        : index == 2
                                        ? Colors.green
                                        : index == 3
                                        ? Colors.red
                                        : Colors.purple,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8.0),
                              ],
                            ),
                            SizedBox(height: 12.0),
                            Text(
                              users[index]["name"],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4.0),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Positioned(
              top: 180.0,
              left: MediaQuery.of(context).size.width / 2 - 60,
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
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Satış',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Teklif',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ]),
                            ...users.map((user) {
                              String userName = user['name'];
                              return TableRow(children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SalesDetailsScreen(
                                              userName: userName,
                                              salesDetails: salesAndQuotesData[userName]?['salesDetails'] ?? [],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(userName),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(salesAndQuotesData[userName]?['salesCount']?.toString() ?? '0'),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(salesAndQuotesData[userName]?['quotesCount']?.toString() ?? '0'),
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

class SalesDetailsScreen extends StatelessWidget {
  final String userName;
  final List<Map<String, dynamic>> salesDetails;

  SalesDetailsScreen({required this.userName, required this.salesDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$userName - Satış Detayları'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: salesDetails.length,
          itemBuilder: (context, index) {
            var detail = salesDetails[index];
            return Card(
              child: ListTile(
                title: Text('Ürün: ${detail['product']}'),
                subtitle: Text('Tutar: ${detail['amount']} TL\nTarih: ${detail['date']}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
