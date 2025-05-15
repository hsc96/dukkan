import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesDataService {
  final FirebaseFirestore _db;
  SalesDataService({ FirebaseFirestore? instance })
      : _db = instance ?? FirebaseFirestore.instance;

  /// Tüm kullanıcıları (uid → fullName) getirir.
  Future<Map<String, String>> getUserIdToNameMap() async {
    var snapshot = await _db.collection('users').get();
    return {
      for (var doc in snapshot.docs)
        doc.id: (doc.data()['fullName'] as String?) ?? 'Bilinmeyen'
    };
  }

  /// Belirli bir tarihteki satış/teklif sayıları getirir.
  /// salesCollection = 'sales' veya 'quotes'
  Future<Map<String, Map<String, dynamic>>> _getCountsAndDetails(
      String salesCollection,
      DateTime date,
      String userField,   // 'salespersons' → List<String> alanı, 'salesperson' → tek String alanı
      String amountField, // 'amount' alanı
      ) async {
    // Tarihi "dd.MM.yyyy" formatında al
    final formatted = DateFormat('dd.MM.yyyy').format(date);
    final snap = await _db
        .collection(salesCollection)
        .where('date', isEqualTo: formatted)
        .get();

    // UID → fullName haritası
    final userMap = await getUserIdToNameMap();
    final result = <String, Map<String, dynamic>>{};

    for (var doc in snap.docs) {
      final data = doc.data();
      // Tutarı parse et
      double amount = 0.0;
      final a = data[amountField];
      if (a is num) {
        amount = a.toDouble();
      } else if (a is String) {
        amount = double.tryParse(a) ?? 0.0;
      }

      // Aktör listesi oluştur
      List<String> actors;
      if (salesCollection == 'sales') {
        actors = List<String>.from(data[userField] ?? ['Unknown']);
      } else {
        actors = [ (data[userField] as String?) ?? 'Unknown' ];
      }

      // Her aktör için sayacı artır
      for (var actor in actors) {
        // UID ise adını al, değilse olduğu gibi kullan
        final name = userMap[actor] ?? actor;
        final entry = result.putIfAbsent(name, () => {
          'count': 0,
          'totalAmount': 0.0,
        });
        entry['count'] = (entry['count'] as int) + 1;
        entry['totalAmount'] = (entry['totalAmount'] as double) + amount;
      }
    }

    return result;
  }

  /// Bugünkü satışları getirir: { salesPerson: {count, totalAmount}, ... }
  Future<Map<String, Map<String, dynamic>>> getSalesForDate(DateTime date) =>
      _getCountsAndDetails('sales', date, 'salespersons', 'amount');

  /// Bugünkü teklifleri getirir: { salesPerson: {count, totalAmount}, ... }
  Future<Map<String, Map<String, dynamic>>> getQuotesForDate(DateTime date) =>
      _getCountsAndDetails('quotes', date, 'salesperson', 'amount');
}
