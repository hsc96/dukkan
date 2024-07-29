import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? currentUser;
  int salesCount = 0;
  double totalSalesAmount = 0.0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchCurrentUser();
  }

  Future<void> fetchCurrentUser() async {
    currentUser = _auth.currentUser;
    if (currentUser != null) {
      fetchSalesData();
    }
  }

  Future<void> fetchSalesData() async {
    String formattedDate = DateFormat('dd.MM.yyyy').format(selectedDate);
    var querySnapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('date', isEqualTo: formattedDate)
        .get();

    int count = querySnapshot.docs.length;
    double totalAmount = querySnapshot.docs.fold(0.0, (sum, doc) {
      return sum + (doc['amount'] ?? 0.0);
    });

    setState(() {
      salesCount = count;
      totalSalesAmount = totalAmount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Kullanıcı: ${currentUser?.email ?? 'Bilinmiyor'}',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 16),
            Text(
              'Tarih: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 16),
            Text(
              'Satış Adedi: $salesCount',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 16),
            Text(
              'Toplam Tutar: ${totalSalesAmount.toStringAsFixed(2)} TL',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
