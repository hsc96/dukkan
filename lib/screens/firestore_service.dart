import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final int _pageSize = 10;

  Stream<List<DocumentSnapshot>> fetchCustomers({DocumentSnapshot? startAfter}) {
    Query query = _db.collection('veritabanideneme')
        .orderBy('Açıklama')
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) => snapshot.docs);
  }
}
