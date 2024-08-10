import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSelectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> selectCustomer(String customerId, String customerName) async {
    await _firestore.collection('selectedCustomer').doc('current').set({
      'customerId': customerId,
      'customerName': customerName,
    });
  }

  Stream<Map<String, dynamic>> getSelectedCustomerStream() {
    return _firestore
        .collection('selectedCustomer')
        .doc('current')
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }
}
