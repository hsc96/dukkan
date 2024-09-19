import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class CustomerExpectedProductsWidget extends StatefulWidget {
  final String customerName;

  CustomerExpectedProductsWidget({required this.customerName});

  @override
  _CustomerExpectedProductsWidgetState createState() => _CustomerExpectedProductsWidgetState();
}

class _CustomerExpectedProductsWidgetState extends State<CustomerExpectedProductsWidget> {
  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity(); // Mevcut bağlantı durumunu kontrol et

    // İnternet bağlantısı değişikliklerini dinleyin
    connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      print('Connectivity Changed: $_isConnected'); // Debug için
    });
  }

  // Mevcut internet bağlantısını kontrol eden fonksiyon
  void _checkInitialConnectivity() async {
    try {
      ConnectivityResult result = await _connectivity.checkConnectivity();
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      print('Initial Connectivity Status: $_isConnected'); // Debug için
    } catch (e) {
      print("Bağlantı durumu kontrol edilirken hata oluştu: $e");
      setState(() {
        _isConnected = false;
      });
    }
  }

  // Yardımcı fonksiyon: İnternet yoksa uyarı dialog'u gösterir
  void _showNoConnectionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    connectivitySubscription.cancel(); // Aboneliği iptal et
    super.dispose();
  }

  Future<String?> getCustomerUniqueId() async {
    var customerSnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Açıklama', isEqualTo: widget.customerName)
        .get();

    if (customerSnapshot.docs.isEmpty) {
      return null;
    }

    var customerData = customerSnapshot.docs.first.data() as Map<String, dynamic>;
    return customerData['Vergi Kimlik Numarası']?.toString() ?? customerData['T.C. Kimlik Numarası']?.toString() ?? null;
  }

  Future<void> markProductAsReady(String productId, Map<String, dynamic> productData) async {
    var uniqueId = productData['Unique ID'];
    var customerSnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Vergi Kimlik Numarası', isEqualTo: uniqueId)
        .get();

    if (customerSnapshot.docs.isEmpty) {
      customerSnapshot = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('T.C. Kimlik Numarası', isEqualTo: uniqueId)
          .get();
    }

    if (customerSnapshot.docs.isNotEmpty) {
      var customerData = customerSnapshot.docs.first.data() as Map<String, dynamic>;
      var customerName = customerData['Açıklama'];

      var customerProductsCollection = FirebaseFirestore.instance.collection('customerDetails');
      var customerDetailsSnapshot = await customerProductsCollection.where('customerName', isEqualTo: customerName).get();

      if (customerDetailsSnapshot.docs.isNotEmpty) {
        var docRef = customerDetailsSnapshot.docs.first.reference;
        var existingProducts = List<Map<String, dynamic>>.from(customerDetailsSnapshot.docs.first.data()['products'] ?? []);

        var productInfo = {
          'Kodu': productData['Kodu'],
          'Detay': productData['Detay'],
          'Adet': productData['Adet'],
          'Adet Fiyatı': productData['Adet Fiyatı'],
          'Toplam Fiyat': (double.tryParse(productData['Adet']?.toString() ?? '0') ?? 0) *
              (double.tryParse(productData['Adet Fiyatı']?.toString() ?? '0') ?? 0),
          'Teklif Numarası': productData['Teklif Numarası'],
          'Teklif Tarihi': productData['Teklif Tarihi'],
          'Sipariş Numarası': productData['Sipariş Numarası'],
          'Sipariş Tarihi': productData['Sipariş Tarihi'],
          'Beklenen Teklif': true,
          'Ürün Hazır Olma Tarihi': Timestamp.now(),
          'buttonInfo': 'B.sipariş', // buttonInfo alanını 'B.sipariş' olarak ayarlıyoruz
          'Müşteri': customerName // Müşteri unvanını ekliyoruz
        };

        existingProducts.add(productInfo);

        await docRef.update({
          'products': existingProducts,
        });

        // Remove product from pendingProducts collection
        await FirebaseFirestore.instance.collection('pendingProducts').doc(productId).delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: getCustomerUniqueId(),
      builder: (context, uniqueIdSnapshot) {
        if (uniqueIdSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (uniqueIdSnapshot.hasError) {
          return Text('Hata: ${uniqueIdSnapshot.error}');
        }
        if (!uniqueIdSnapshot.hasData || uniqueIdSnapshot.data == null) {
          return Text('Müşteri bulunamadı');
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('pendingProducts')
              .where('Unique ID', isEqualTo: uniqueIdSnapshot.data)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Hata: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text('Beklenen ürün yok');
            }

            var docs = snapshot.data!.docs;

            // Teslim tarihine göre sıralama
            docs.sort((a, b) {
              DateTime? aDate = a['deliveryDate'] != null ? (a['deliveryDate'] as Timestamp).toDate() : null;
              DateTime? bDate = b['deliveryDate'] != null ? (b['deliveryDate'] as Timestamp).toDate() : null;

              if (aDate == null && bDate == null) {
                return 0;
              } else if (aDate == null) {
                return 1;
              } else if (bDate == null) {
                return -1;
              } else {
                return aDate.compareTo(bDate);
              }
            });

            return ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                DateTime? deliveryDate = data['deliveryDate'] != null
                    ? (data['deliveryDate'] as Timestamp).toDate()
                    : null;

                return Card(
                  child: ExpansionTile(
                    title: Text(data['Detay'] ?? 'Detay yok'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Müşteri: ${data['Müşteri'] ?? 'Müşteri bilgisi yok'}'),
                        Text('Tahmini Teslim Tarihi: ${deliveryDate != null ? DateFormat('dd MMMM yyyy').format(deliveryDate) : 'Tarih yok'}'),
                      ],
                    ),
                    children: [
                      ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kodu: ${data['Kodu'] ?? 'Kodu yok'}'),
                            Text('Teklif No: ${data['Teklif Numarası'] ?? 'Teklif numarası yok'}'),
                            Text('Sipariş No: ${data['Sipariş Numarası'] ?? 'Sipariş numarası yok'}'),
                            Text('Adet Fiyatı: ${data['Adet Fiyatı'] ?? 'Adet fiyatı yok'}'),
                            Text('Adet: ${data['Adet'] ?? 'Adet yok'}'),
                            Text('Teklif Tarihi: ${data['Teklif Tarihi'] ?? 'Tarih yok'}'),
                            Text('Sipariş Tarihi: ${data['Sipariş Tarihi'] ?? 'Tarih yok'}'),
                            Text('İşleme Alan: ${data['islemeAlan'] ?? 'admin'}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            if (_isConnected) {
                              markProductAsReady(docs[index].id, data);
                            } else {
                              _showNoConnectionDialog(
                                'Bağlantı Sorunu',
                                'İnternet bağlantısı yok, işlemi gerçekleştiremiyorsunuz.',
                              );
                            }
                          },
                          child: Text('Ürün Hazır'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
