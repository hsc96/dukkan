import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'scan_screen.dart';
import 'package:flutter/cupertino.dart';
import '../utils/colors.dart';
import '../services/sales_data_service.dart';

class CustomHeaderScreen extends StatefulWidget {
  @override
  _CustomHeaderScreenState createState() => _CustomHeaderScreenState();
}
List<Map<String, dynamic>> users = [];
class _CustomHeaderScreenState extends State<CustomHeaderScreen> {

  Map<String, Map<String, dynamic>> salesAndQuotesData = {};
  List<Map<String, String>> temporarySelections = [];
  final _salesService = SalesDataService();
  List<String> allSalespersons = [];


  @override
  void initState() {
    super.initState();

    _fetchAllUsers().then((_) => _loadHeaderData());
    _listenToTemporarySelections();  // ← Bunu ekleyin
  }

  Future<void> _loadHeaderData() async {
    DateTime today = DateTime.now();
    var salesData  = await _salesService.getSalesForDate(today);
    var quoteData  = await _salesService.getQuotesForDate(today);

    // İsimleri birleşik bir haritaya alalım
    Map<String, Map<String, dynamic>> combined = {};
    for (var name in {...salesData.keys, ...quoteData.keys}) {
      combined[name] = {
        'salesCount':  salesData[name]?['count']       ?? 0,
        'quotesCount': quoteData[name]?['count']       ?? 0,
        // isterseniz toplam tutarları da saklayabilirsiniz:
        'salesAmount':salesData[name]?['totalAmount'] ?? 0.0,
        'quotesAmount':quoteData[name]?['totalAmount'] ?? 0.0,
      };
    }

    setState(() {
      salesAndQuotesData = combined;
    });
  }
  Future<void> _fetchAllUsers() async {
    var snap = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      allSalespersons = snap.docs
          .map((d) => (d.data()['fullName'] as String?) ?? d.id)
          .toList();
    });
  }

  void _listenToTemporarySelections() {
    FirebaseFirestore.instance
        .collection('temporarySelections')
        .snapshots()
        .listen((snapshot) {
      List<Map<String, String>> list = [];
      for (var doc in snapshot.docs) {
        list.add({
          'currentId': doc.id,
          'customerName': doc.data()['customerName'] ?? '',
          'totalAmount': (doc.data()['grandTotal']?.toString() ?? '0.00'),
        });
      }
      setState(() {
        temporarySelections = list;
      });
    });
  }

  Future<Map<String, dynamic>> getQuotesForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end   = DateTime(date.year, date.month, date.day, 23, 59, 59);
    var snap = await FirebaseFirestore.instance
        .collection('quotes')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();
    Map<String, dynamic> data = {};
    for (var doc in snap.docs) {
      final createdBy = doc.data()['createdBy'] ?? 'Bilinmeyen';
      data[createdBy] ??= {'count': 0, 'totalAmount': 0.0};
      data[createdBy]['count']++;
      // Ürün toplamı topla...
    }
    return data;
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

  void showSalesDetails(String salespersonName) async {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());

    // 1) O günün sales dokümanları
    var salesSnap = await FirebaseFirestore.instance
        .collection('sales')
        .where('date', isEqualTo: today)
        .where('salespersons', arrayContains: salespersonName)
        .get();

    // 2) O günün quotes dokümanları
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd   = DateTime(now.year, now.month, now.day, 23, 59, 59);

    var quotesSnap = await FirebaseFirestore.instance
        .collection('quotes')
        .where('date', isGreaterThanOrEqualTo: todayStart)
        .where('date', isLessThanOrEqualTo: todayEnd)
        .where('createdBy', isEqualTo: salespersonName)
        .get();


    // 3) sales ve quotes’ı customerName’e göre grupla
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
    for (var doc in [...salesSnap.docs, ...quotesSnap.docs]) {
      final cust = doc.data()['customerName'] as String? ?? 'Bilinmeyen';
      grouped.putIfAbsent(cust, () => []).add(doc);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text(
                '$salespersonName — Detaylar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...grouped.entries.map((entry) {
                final cust = entry.key;
                final docs = entry.value;

                // *** Müşteri bazlı toplam tutar ***
                final custTotal = docs.fold<double>(0.0, (sum, doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  final products = (data['products'] as List<dynamic>?) ?? [];
                  double productsTotal = products.fold(0.0, (pSum, p) {
                    final toplam = p['Toplam Fiyat'];
                    if (toplam is num) return pSum + toplam.toDouble();
                    if (toplam is String) return pSum + (double.tryParse(toplam) ?? 0.0);
                    return pSum;
                  });
                  return sum + productsTotal;
                });

                return ExpansionTile(
                  title: Text('$cust — Toplam: ${custTotal.toStringAsFixed(2)} TL'),
                  children: docs.expand<Widget>((doc) {
                    final data = doc.data()! as Map<String, dynamic>;
                    final type     = data['type'] as String? ?? '';
                    final products = (data['products'] as List<dynamic>?) ?? [];

                    // **SATIŞ BLOĞU TOPLAMI**
                    double salesBlockTotal = products.fold(0.0, (sum, p) {
                      final toplam = p['Toplam Fiyat'];
                      if (toplam is num) return sum + toplam.toDouble();
                      if (toplam is String) return sum + (double.tryParse(toplam) ?? 0.0);
                      return sum;
                    });

                    return <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          type == 'Teklif' ? '— TEKLİF —' : '— SATIŞ —',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...products.map<Widget>((p) {
                        final detay   = p['Detay']?.toString()      ?? '';
                        final adet    = p['Adet']?.toString()        ?? '0';
                        final fiyat   = p['Adet Fiyatı']?.toString() ?? '0';
                        final toplamF = p['Toplam Fiyat']?.toString() ?? '0';

                        // Etiket kontrolü
                        String? label;
                        if (type == 'Hesaba İşle') {
                          label = 'Cari Hesaba Kaydedildi';
                        } else if (type == 'Nakit Tahsilat' || type == 'N.Tahsilat') {
                          label = 'Nakit Tahsilat';
                        } else {
                          label = null;
                        }

                        return ListTile(
                          title: Text(detay),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (label != null)
                                Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Adet: $adet   Fiyat: $fiyat'),
                              Text('Toplam: $toplamF'),
                            ],
                          ),
                        );
                      }).toList(),
                      // *** SATIŞ BLOĞU TOPLAMINI GÖSTER ***
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, top: 2.0, bottom: 8.0),
                        child: Text(
                          'Satış Toplamı: ${salesBlockTotal.toStringAsFixed(2)} TL',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Divider(thickness: 1),
                    ];
                  }).toList(),
                );
              }).toList(),
            ],
          ),
        );
      },
    );


  }




  /// Satış mı, teklif mi bakarak o günün detaylarını getirip alt pencerede gösterir.
  /// Günün “sales” veya “quotes” kayıtlarını
  /// satış elemanına göre getirir, müşteri bazında gruplar
  /// ve alt alta ürün detaylarını BottomSheet’te gösterir.
  void _showRecordDetails(String salespersonName, {required bool isSale}) async {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final collection = isSale ? 'sales' : 'quotes';
    final userField  = isSale ? 'salespersons' : 'salesperson';
    final typeLabel  = isSale ? 'SATIŞ' : 'TEKLİF';

    // 1) Firestore’dan ilgili dokümanları çek
    QuerySnapshot<Map<String, dynamic>> snap;
    if (isSale) {
      snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('date', isEqualTo: today)
          .where(userField, arrayContains: salespersonName)
          .get();
    } else {
      snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('date', isEqualTo: today)
          .where(userField, isEqualTo: salespersonName)
          .get();
    }

    Future<List<QueryDocumentSnapshot>> fetchSalesAndQuotes(String salespersonName) async {
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('salespersons', arrayContains: salespersonName)
          .get();

      final quotesSnapshot = await FirebaseFirestore.instance
          .collection('quotes')
          .where('salesperson', isEqualTo: salespersonName)
          .get();

      final allDocs = <QueryDocumentSnapshot>[];
      allDocs.addAll(salesSnapshot.docs);
      allDocs.addAll(quotesSnapshot.docs);

      return allDocs;
    }


    // 2) customerName’e göre grupla
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
    for (var doc in snap.docs) {
      final cust = doc.data()['customerName'] as String? ?? 'Bilinmeyen Müşteri';
      grouped.putIfAbsent(cust, () => []).add(doc);
    }

    // 3) BottomSheet’i göster
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text(
                '$salespersonName — $typeLabel Detayları',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...grouped.entries.map((entry) {
                final cust = entry.key;
                final docs = entry.value;

                // Müşteri bazlı toplam tutar
                double custTotal = docs.fold(0.0, (sum, d) {
                  final data = d.data()!;
                  final products = (data['products'] as List<dynamic>?) ?? [];
                  double productsTotal = products.fold(0.0, (pSum, p) {
                    final toplam = p['Toplam Fiyat'];
                    if (toplam is num) return pSum + toplam.toDouble();
                    if (toplam is String) return pSum + (double.tryParse(toplam) ?? 0.0);
                    return pSum;
                  });
                  return sum + productsTotal;
                });

                return ExpansionTile(
                  title: Text('$cust — Toplam: ${custTotal.toStringAsFixed(2)} TL'),
                  children: docs.expand<Widget>((doc) {
                    final data = doc.data();
                    final type     = data['type'] as String? ?? '';
                    final products = (data['products'] as List<dynamic>?) ?? [];
                    final quoteNumber = data['quoteNumber']?.toString();

                    // Blok toplamı
                    double blockTotal = products.fold(0.0, (sum, p) {
                      final toplam = p['Toplam Fiyat'];
                      if (toplam is num) return sum + toplam.toDouble();
                      if (toplam is String) return sum + (double.tryParse(toplam) ?? 0.0);
                      return sum;
                    });

                    return <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          type == 'Teklif' ? '— TEKLİF —' : '— SATIŞ —',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...products.map<Widget>((p) {
                        final detay   = p['Detay']?.toString()      ?? '';
                        final adet    = p['Adet']?.toString()        ?? '0';
                        final fiyat   = p['Adet Fiyatı']?.toString() ?? '0';
                        final toplamF = p['Toplam Fiyat']?.toString() ?? '0';

                        String? label;
                        if (type == 'Hesaba İşle') {
                          label = 'Cari Hesaba Kaydedildi';
                        } else if (type == 'Nakit Tahsilat' || type == 'N.Tahsilat') {
                          label = 'Nakit Tahsilat';
                        } else if (type == 'Teklif') {
                          label = 'Teklif';
                        } else {
                          label = null;
                        }

                        return ListTile(
                          title: Text(detay),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (label != null)
                                Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Adet: $adet   Fiyat: $fiyat'),
                              Text('Toplam: $toplamF'),
                            ],
                          ),
                        );
                      }).toList(),
                      // SAĞDA: Satış için toplam, teklif için hem toplam hem teklif no!
                      Row(
                        children: [
                          Spacer(),
                          if (type == 'Teklif' && quoteNumber != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TEKLİF TOPLAMI: ${blockTotal.toStringAsFixed(2)} TL',
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'TEKLİF NO: $quoteNumber',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'SATIŞ TOPLAMI: ${blockTotal.toStringAsFixed(2)} TL',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Divider(thickness: 1),
                    ];
                  }).toList(),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }







  @override
  Widget build(BuildContext context) {
    // Satış elemanlarının listesini salesAndQuotesData'dan alıyoruz

    List<String> salespersons = allSalespersons;
    return Scaffold(
      appBar: CustomAppBar(title: 'Coşkun Sızdırmazlık'),
      endDrawer: CustomDrawer(),
      body: Container(
        color: colorTheme2,
        child: Stack(
          children: [
            // Mevcut StreamBuilder'ınız burada kalıyor
            Positioned(
              top: 21,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: temporarySelections.map((customer) {
                    final docId = customer['currentId']!;  // Firestore doc ID
                    return GestureDetector(
                      onTap: () {
                        final docId = customer['currentId']!;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanScreen(
                              onCustomerProcessed: (data) {},
                              documentId: docId,  // ← burası docId olacak
                            ),
                          ),
                        ).then((_) {
                          _loadHeaderData();
                          _listenToTemporarySelections();
                        });


                      },
                      child: Card(
                        color: const Color(0xFF0C2B40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 56) / 4,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                customer['customerName']!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4),
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
            ),



            // Ürün Tara butonunuz burada kalıyor

            // 'Ürün Tara' butonunu ekliyoruz
            Positioned(
              top: 180.0,
              left: MediaQuery.of(context).size.width / 2 - 60,
              child: GestureDetector(
                onTap: () async {
                  // 1) Yeni currentX oluşturma
                  var tmpColl = FirebaseFirestore.instance.collection('temporarySelections');
                  var querySnapshot = await tmpColl.get();
                  int maxNum = 1;
                  for (var doc in querySnapshot.docs) {
                    if (doc.id.startsWith('current')) {
                      int? n = int.tryParse(doc.id.replaceAll('current', ''));
                      if (n != null && n >= maxNum) maxNum = n + 1;
                    }
                  }
                  String newCurrentField = 'current$maxNum';
                  await tmpColl.doc(newCurrentField).set({
                    'customerName': '',
                    'products': [],
                  });

                  // 2) ScanScreen'e geç ve geri döndüğünde header'ı yenile
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScanScreen(
                        onCustomerProcessed: (data) {},
                        documentId: newCurrentField,
                      ),
                    ),
                  ).then((_) {
                    // ScanScreen kapatıldıktan sonra çalışır:
                    _loadHeaderData();
                    _listenToTemporarySelections();
                  });
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

                              return TableRow(children: [
                                // 1. sütun: satış elemanı adı
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(salespersonName),
                                  ),
                                ),

                                // 2. sütun: satış sayısı, tıklanınca satış detaylarını getir
                                TableCell(
                                  child: InkWell(
                                    onTap: () => _showRecordDetails(salespersonName, isSale: true),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text((data['salesCount'] ?? 0).toString()),
                                    ),
                                  ),
                                ),

                                // 3. sütun: teklif sayısı, tıklanınca teklif detaylarını getir
                                TableCell(
                                  child: InkWell(
                                    onTap: () => _showRecordDetails(salespersonName, isSale: false),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text((data['quotesCount'] ?? 0).toString()),
                                    ),
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
