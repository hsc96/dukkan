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
import 'customer_expected_products_widget.dart'; // Beklenen ürünler widgetını ekliyoruz.

class CustomerDetailsScreen extends StatefulWidget {
  final String customerName;

  CustomerDetailsScreen({required this.customerName});

  @override
  _CustomerDetailsScreenState createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Müşteri Detayları - ${widget.customerName}'),
      drawer: CustomDrawer(),
      body: Column(
        children: [
          SizedBox(height: 20),
          ToggleButtons(
            isSelected: [currentIndex == 0, currentIndex == 1, currentIndex == 2, currentIndex == 3, currentIndex == 4],
            onPressed: (int index) {
              setState(() {
                currentIndex = index;
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Ürünler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Kitler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Teklifler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('İşlenenler'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Beklenen Ürünler'),
              ),
            ],
          ),
          if (currentIndex == 0) Expanded(child: ProductsWidget(customerName: widget.customerName)),
          if (currentIndex == 1) Expanded(child: KitsWidget(customerName: widget.customerName)),
          if (currentIndex == 2) Expanded(child: QuotesWidget(customerName: widget.customerName)),
          if (currentIndex == 3) Expanded(child: ProcessedWidget(customerName: widget.customerName)),
          if (currentIndex == 4) Expanded(child: CustomerExpectedProductsWidget(customerName: widget.customerName)),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
