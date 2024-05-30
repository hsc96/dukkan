import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // CupertinoIcons için gerekli import
import '../utils/colors.dart'; // Renk tanımlarını içe aktar
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class CustomHeaderScreen extends StatefulWidget {
  @override
  _CustomHeaderScreenState createState() => _CustomHeaderScreenState();
}

class _CustomHeaderScreenState extends State<CustomHeaderScreen> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Örnek veri
    List<Map<String, dynamic>> customers = [
      {
        "name": "Müşteri 2",
        "currentBalance": 650,
        "totalBalance": 1100,
        "date": "19 Mayıs 2024",
      },
      {
        "name": "Müşteri 2",
        "currentBalance": 400,
        "totalBalance": 900,
        "date": "19 Mayıs 2024",
      },
      {
        "name": "Müşteri 3",
        "currentBalance": 200,
        "totalBalance": 700,
        "date": "19 Mayıs 2024",
      },
      {
        "name": "Müşteri 4",
        "currentBalance": 500,
        "totalBalance": 2000,
        "date": "19 Mayıs 2024",
      },
      {
        "name": "Müşteri 5",
        "currentBalance": 700,
        "totalBalance": 1300,
        "date": "19 Mayıs 2024",
      },
    ];

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
                  children: List.generate(customers.length, (index) {
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
                              customers[index]["name"],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              '${customers[index]["currentBalance"]} TL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Toplam: ${customers[index]["totalBalance"]} TL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4.0),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                onPressed: () {
                                  print(
                                      '${customers[index]["name"]} detaylarına bakıldı.');
                                },
                                child: Text(
                                  'Detaylar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
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
                            3: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: colorTheme2,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'ÜRÜN',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'ADET',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'ADET FİYAT',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'TOPLAM FİYAT',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('K21-040 40X50X10'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('4'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('70,00 TL'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('280,00 TL'),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('K21-040 40X50X10'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('4'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('70,00 TL'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.8),
                                  child: Text('280,00 TL'),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Toplam Tutar',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('560,00 TL',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('KDV %20',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('112,00 TL',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Genel Toplam',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(''),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('672,00 TL',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
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
