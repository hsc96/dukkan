import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<String>> fetchFilteredCustomers(String query) async {
    QuerySnapshot querySnapshot = await _db.collection('veritabanideneme')
        .where('Açıklama', isGreaterThanOrEqualTo: query)
        .where('Açıklama', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['Açıklama'] ?? 'Açıklama bilgisi yok';
    }).cast<String>().toList(); // List<String> türüne dönüştür
  }
}
