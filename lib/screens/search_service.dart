import 'package:cloud_firestore/cloud_firestore.dart';

Future<List<Map<String, dynamic>>> searchCustomers(String query, List<DocumentSnapshot> localCustomers) async {
  String lowerCaseQuery = query.toLowerCase();

  try {
    // Veritabanında arama yap
    var querySnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('AçıklamaLowerCase', isGreaterThanOrEqualTo: lowerCaseQuery)
        .where('AçıklamaLowerCase', isLessThanOrEqualTo: lowerCaseQuery + '\uf8ff')
        .get();

    var descriptions = querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
        'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
      };
    }).toList();

    // Mevcut listede arama yap
    var localResults = localCustomers.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      String aciklama = data['Açıklama'] ?? '';
      return aciklama.toLowerCase().contains(lowerCaseQuery);
    }).map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'Açıklama': data['Açıklama'] ?? 'Açıklama bilgisi yok',
        'Fatura Kesilecek Tutar': data['Fatura Kesilecek Tutar'] ?? 0.0,
      };
    }).toList();

    return [
      ...descriptions,
      ...localResults.where((localDoc) => !descriptions.any((desc) => desc['Açıklama'] == localDoc['Açıklama']))
    ];
  } catch (e) {
    print('Error searching customers: $e');
    return [];
  }
}
