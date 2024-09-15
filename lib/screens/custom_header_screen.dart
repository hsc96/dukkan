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

    // fetchSalesAndQuotesData fonksiyonunu burada çağırıyoruz
    fetchSalesAndQuotesData();
  }


  Future<void> fetchSalesAndQuotesData() async {
    var today = DateFormat('dd.MM.yyyy').format(DateTime.now());

    // Önceki verileri temizle
    salesAndQuotesData.clear();

    // Bugünün tüm satış verilerini al
    var salesQuerySnapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('date', isEqualTo: today)
        .get();

    // Satış elemanlarına ve müşterilere göre verileri gruplamak için bir harita başlat
    Map<String, Map<String, dynamic>> salespersonData = {};

    for (var doc in salesQuerySnapshot.docs) {
      var data = doc.data();
      var customerName = data['customerName'] ?? 'Unknown Customer';
      List<dynamic> salespersons = data['salespersons'] ?? [];
      List<dynamic> products = data['products'] ?? [];

      // Eğer salespersons listesi boşsa, 'Unknown Salesperson' olarak işleyebiliriz
      if (salespersons.isEmpty) {
        salespersons = ['Unknown Salesperson'];
      }

      // Her satış elemanı için işlemi kaydedelim
      for (var salespersonName in salespersons) {
        // Eğer satış elemanı daha önce eklenmediyse, yeni bir giriş oluştur
        if (!salespersonData.containsKey(salespersonName)) {
          salespersonData[salespersonName] = {
            'salesCount': 0,
            'salesDetails': {},
          };
        }

        Map<String, dynamic> salespersonEntry = salespersonData[salespersonName]!;

        // Satış sayısını artır
        salespersonEntry['salesCount'] = (salespersonEntry['salesCount'] ?? 0) + 1;

        // Satış detaylarını güncelle
        Map<String, dynamic> salesDetails = Map<String, dynamic>.from(salespersonEntry['salesDetails'] ?? {});

        if (!salesDetails.containsKey(customerName)) {
          salesDetails[customerName] = {
            'totalAmount': 0.0,
            'products': [],
          };
        }

        Map<String, dynamic> customerSales = Map<String, dynamic>.from(salesDetails[customerName] ?? {});

        // Toplam tutarı ekle
        double amount = 0.0;
        if (data['amount'] is String) {
          amount = double.tryParse(data['amount']) ?? 0.0;
        } else if (data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        }
        customerSales['totalAmount'] = (customerSales['totalAmount'] ?? 0.0) + amount;

        // Ürünleri ekle
        List<Map<String, dynamic>> salespersonProducts = products.where((product) {
          return product['addedBy'] == salespersonName;
        }).map<Map<String, dynamic>>((product) => Map<String, dynamic>.from(product)).toList();

        // customerSales['products'] listesini güncelle
        if (!customerSales.containsKey('products') || customerSales['products'] == null) {
          customerSales['products'] = <Map<String, dynamic>>[];
        }

        List<Map<String, dynamic>> productsList = List<Map<String, dynamic>>.from(customerSales['products']);

        productsList.addAll(salespersonProducts);

        customerSales['products'] = productsList;

        // salesDetails içinde customerSales'i güncelle
        salesDetails[customerName] = customerSales;

        // salespersonEntry içinde salesDetails'i güncelle
        salespersonEntry['salesDetails'] = salesDetails;

        // salespersonData içinde salespersonEntry'yi güncelle
        salespersonData[salespersonName] = salespersonEntry;
      }
    }

    // Durumu güncelle
    setState(() {
      salesAndQuotesData = salespersonData;
    });
  }








  Stream<DocumentSnapshot<Map<String, dynamic>>> gettemporarySelections() {
    return FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc('current')
        .snapshots();
  }

  void addNewCustomer(String customerName, String totalAmount) {
    setState(() {
      // Mavi kutucuk oluşturulurken
      temporarySelections.add({
        'customerName': customerName,
        'totalAmount': totalAmount,
        'current': 'currentX' // Bu X, ilgili current numarasıdır.
      });

    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> gettemporarySelectionsStream() {
    return FirebaseFirestore.instance
        .collection('temporarySelections')
        .snapshots();
  }

  void showSalesDetails(String salespersonName, Map<String, dynamic> salesDetails) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  '$salespersonName - Satış Detayları',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: salesDetails.entries.map<Widget>((entry) {
                    String customerName = entry.key;
                    var details = entry.value as Map<String, dynamic>;
                    double totalAmount = details['totalAmount'] ?? 0.0;

                    List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(details['products'] ?? []);

                    return ExpansionTile(
                      title: Text('$customerName - Toplam: ${totalAmount.toStringAsFixed(2)} TL'),
                      children: [
                        ...products.map<Widget>((product) {
                          String productName = product['Detay'] ?? 'Ürün Bilgisi Yok';
                          double unitPrice = double.tryParse(product['Adet Fiyatı']?.toString() ?? '0') ?? 0.0;
                          int quantity = int.tryParse(product['Adet']?.toString() ?? '1') ?? 1;
                          double totalPrice = double.tryParse(product['Toplam Fiyat']?.toString() ?? '0') ?? 0.0;

                          return ListTile(
                            title: Text(productName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Adet Fiyatı: ${unitPrice.toStringAsFixed(2)} TL'),
                                Text('Adet: $quantity'),
                                Text('Toplam Fiyat: ${totalPrice.toStringAsFixed(2)} TL'),
                              ],
                            ),
                          );
                        }).toList(),
                        Divider(color: Colors.black, thickness: 1),
                        ListTile(
                          title: Text('Genel Toplam'),
                          subtitle: Text('${totalAmount.toStringAsFixed(2)} TL'),
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
  }





  @override
  Widget build(BuildContext context) {
    // Satış elemanlarının listesini salesAndQuotesData'dan alıyoruz
    List<String> salespersons = salesAndQuotesData.keys.toList();

    return Scaffold(
      appBar: CustomAppBar(title: 'Coşkun Sızdırmazlık'),
      endDrawer: CustomDrawer(),
      body: Container(
        color: colorTheme2,
        child: Stack(
          children: [
            // Mevcut StreamBuilder'ınız burada kalıyor
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('temporarySelections').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                List<Map<String, String>> temporarySelections = [];

                for (var doc in snapshot.data!.docs) {
                  String documentId = doc.id; // current ID'sini alın
                  String customerName = doc.data()?['customerName'] ?? 'Müşteri Seçilmedi';
                  String totalAmount = '0.00 TL';

                  var products = doc.data()?['products'] as List<dynamic>?;
                  if (products != null) {
                    var genelToplamEntry = products.firstWhere(
                          (product) => product['Adet Fiyatı'] == 'Genel Toplam',
                      orElse: () => null,
                    );
                    if (genelToplamEntry != null) {
                      totalAmount = genelToplamEntry['Toplam Fiyat'] ?? '0.00';
                    }
                  }

                  // Mavi kutucuk verilerini doldurun
                  temporarySelections.add({
                    'customerName': customerName,
                    'totalAmount': totalAmount,
                    'currentId': documentId, // current ID'sini burada saklayın
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
                        // Mavi kutucuklar için GestureDetector
                        return GestureDetector(
                          onTap: () async {
                            print("Mavi kutuya tıklandı!");

                            // `currentId` değerini mavi kutucukta kullanıyoruz
                            String? documentId = customer['currentId']; // Müşteriye göre currentX field'ı

                            if (documentId != null) {
                              print("Document ID: $documentId");

                              DocumentSnapshot<Map<String, dynamic>> currentData = await FirebaseFirestore.instance


                                  .collection('temporarySelections')
                                  .doc(documentId)
                                  .get();

                              if (currentData.exists) {
                                print("Document data mevcut!");

                                // ScanScreen sayfasına git
                                print("ScanScreen'e yönlendirme yapılacak, Document ID: $documentId");
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScanScreen(
                                      onCustomerProcessed: (data) {},
                                      documentId: documentId,
                                    ),
                                  ),
                                );
                              } else {
                                print("Veri mevcut değil, currentX bulunamadı.");
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

            // Ürün Tara butonunuz burada kalıyor

            // 'Ürün Tara' butonunu ekliyoruz
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

                  // Yeni oluşturulan currentX field'ını ScanScreen'e geçiyoruz
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScanScreen(
                        onCustomerProcessed: (data) {},
                        documentId: newCurrentField, // newCurrentField is passed here
                      ),
                    ),
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

            // [Bu bölümü aynen koruyabilirsiniz]

            // Satış Elemanları Tablosu
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
                            ...salespersons.map((salespersonName) {
                              var data = salesAndQuotesData[salespersonName] ?? {};
                              var userSalesDetails = data['salesDetails'] ?? {};

                              return TableRow(children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: InkWell(
                                      onTap: () {
                                        showSalesDetails(salespersonName, userSalesDetails);
                                      },
                                      child: Text(salespersonName),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text((data['salesCount'] ?? 0).toString()),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text((data['quotesCount'] ?? 0).toString()),
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
