import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    var querySnapshot = await _db.collection('urunler')
        .where('Barkod', isEqualTo: barcode)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    } else {
      throw Exception('Ürün bulunamadı');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductsByBarcode(String barcode) async {
    QuerySnapshot querySnapshot = await _db.collection('urunler')
        .where('Barkod', isEqualTo: barcode)
        .get();
    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data;
    }).toList();
  }

  Future<List<String>> fetchFilteredCustomers(String query) async {
    QuerySnapshot querySnapshot = await _db.collection('veritabanideneme')
        .where('Açıklama', isGreaterThanOrEqualTo: query)
        .where('Açıklama', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['Açıklama'] ?? 'Açıklama bilgisi yok';
    }).cast<String>().toList();
  }
}
