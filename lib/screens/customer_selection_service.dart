import 'dart:convert'; // JSON dönüşümü için
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSelectionService {
  final String customerKey = 'selected_customer';
  final String productsKey = 'selected_products';

  Future<void> saveSelectedCustomer(String customerName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(customerKey, customerName);

    // Firestore'a kaydet
    await FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc('current')
        .set({'customerName': customerName}, SetOptions(merge: true));
  }

  Future<String?> getSelectedCustomer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? customerName = prefs.getString(customerKey);

    // Eğer yerel olarak yoksa Firestore'dan al
    if (customerName == null) {
      var doc = await FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc('current')
          .get();
      customerName = doc.data()?['customerName'];
    }

    return customerName;
  }

  Future<void> saveProductList(List<Map<String, dynamic>> products) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(productsKey, jsonEncode(products)); // JSON string'e çevir

    // Firestore'a kaydet
    await FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc('current')
        .set({'products': products}, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getProductList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? productsString = prefs.getString(productsKey);

    List<Map<String, dynamic>> products = [];
    if (productsString != null) {
      products = List<Map<String, dynamic>>.from(
          jsonDecode(productsString)); // JSON string'den listeye çevir
    } else {
      // Eğer yerel olarak yoksa Firestore'dan al
      var doc = await FirebaseFirestore.instance
          .collection('temporarySelections')
          .doc('current')
          .get();
      var productsData = doc.data()?['products'];
      if (productsData != null) {
        products = List<Map<String, dynamic>>.from(productsData);
      }
    }

    return products;
  }

  Future<void> clearTemporaryData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(customerKey);
    await prefs.remove(productsKey);

    // Firestore'dan da sil
    await FirebaseFirestore.instance
        .collection('temporarySelections')
        .doc('current')
        .delete();
  }
}
