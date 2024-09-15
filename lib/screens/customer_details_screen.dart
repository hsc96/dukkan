import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import '../utils/colors.dart';
import 'package:intl/intl.dart';
import 'products_widget.dart';
import 'kits_widget.dart';
import 'quotes_widget.dart';
import 'processed_screen.dart';
import 'customer_expected_products_widget.dart';
import 'account_tracking_screen.dart'; // Cari Hesap Takip ekranını import et

class CustomerDetailsScreen extends StatefulWidget {
  final String customerName;

  CustomerDetailsScreen({required this.customerName});

  @override
  _CustomerDetailsScreenState createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  int currentIndex = 0;
  double genelToplam = 0.0;

  void updateGenelToplam(double total) {
    setState(() {
      genelToplam = total;
    });
  }

  void navigateToAccountTracking() async {
    // Müşterinin ürün verilerini CariHesapTakipScreen'e geçirmek için al
    var querySnapshot = await FirebaseFirestore.instance
        .collection('customerDetails')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    List<Map<String, dynamic>> products = [];

    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      products = List<Map<String, dynamic>>.from(data['products'] ?? []);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CariHesapTakipScreen(
          customerName: widget.customerName,
          products: products, // Bu satırı ekleyin
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Müşteri Detayları - ${widget.customerName}'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ToggleButtons(
                  isSelected: [
                    currentIndex == 0,
                    currentIndex == 1,
                    currentIndex == 2,
                    currentIndex == 3,
                    currentIndex == 4,
                    false // "Cari Hesap Takip" için sahte bir seçilme durumu ekliyoruz
                  ],
                  onPressed: (int index) {
                    if (index < 5) {
                      setState(() {
                        currentIndex = index;
                      });
                    } else {
                      navigateToAccountTracking();
                    }
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Ürünler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Kitler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Teklifler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('İşlenenler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Beklenen Ürünler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Cari Hesap Takip'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (currentIndex == 0)
            Expanded(
              child: ProductsWidget(
                customerName: widget.customerName,
                onTotalUpdated: updateGenelToplam,
                onProcessSelected: (selectedIndexes, customerProducts) {
                  // Burada gerekli işlemleri yapabilirsiniz
                  // Bu callback fonksiyonu ile ürünleri işleme alabilirsiniz
                },
              ),
            ),

          if (currentIndex == 1) Expanded(child: KitsWidget(customerName: widget.customerName)),
          if (currentIndex == 2) Expanded(child: QuotesWidget(customerName: widget.customerName)),
          if (currentIndex == 3) Expanded(child: ProcessedWidget(customerName: widget.customerName)),
          if (currentIndex == 4) Expanded(child: CustomerExpectedProductsWidget(customerName: widget.customerName)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Genel Toplam: ${genelToplam.toStringAsFixed(2)} TL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
