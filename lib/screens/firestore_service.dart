import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addUser(String uid, String email, String role) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'role': role,
    });
  }

  Future<void> createUserWithEmail(String email, String password, String role) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    User? user = userCredential.user;

    if (user != null) {
      await addUser(user.uid, email, role);
    }
  }

  Future<void> createUserWithPhone(String phone, String role) async {
    // Telefon numarası ile kullanıcı oluşturma işlemleri
    // Bu kısımda Firebase Authentication'ın telefon numarası ile doğrulama yöntemlerini kullanmanız gerekecek
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({'role': newRole});
  }

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

  Future<void> updateProductPricesByBrands(List<String> brands, double zamOrani) async {
    QuerySnapshot querySnapshot = await _db.collection('urunler')
        .where('Marka', whereIn: brands)
        .get();

    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double currentPrice = double.tryParse(data['Fiyat']?.toString() ?? '0') ?? 0.0;
      double newPrice = currentPrice + (currentPrice * zamOrani / 100);

      await _db.collection('urunler').doc(doc.id).update({'Fiyat': newPrice.toStringAsFixed(2)});
    }
  }

  Future<List<String>> fetchUniqueBrands() async {
    QuerySnapshot querySnapshot = await _db.collection('urunler').get();
    Set<String> brands = Set<String>();

    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      brands.add(data['Marka'] ?? '');
    }

    return brands.toList();
  }

  Future<void> addZamToCollection(String marka, String tarih, String yetkili, double zamOrani) async {
    await _db.collection('zam').add({
      'marka': marka,
      'tarih': tarih,
      'yetkili': yetkili,
      'zam orani': zamOrani,
    });
  }

  Future<List<Map<String, dynamic>>> fetchZamListesi() async {
    QuerySnapshot querySnapshot = await _db.collection('zam').get();
    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'tarih': data['tarih'] ?? '',
        'markalar': data['marka'] ?? '',
        'yetkili': data['yetkili'] ?? '',
        'zam orani': data['zam orani'] ?? 0,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> getCustomerDiscount(String customerName) async {
    var querySnapshot = await _db.collection('veritabanideneme')
        .where('Açıklama', isEqualTo: customerName)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    } else {
      throw Exception('İskonto bilgisi bulunamadı');
    }
  }

  Future<Map<String, dynamic>> getDiscountRates(String discountLevel, String marka) async {
    if (discountLevel == null || marka == null) {
      throw Exception('Geçersiz iskonto seviyesi veya marka');
    }

    var querySnapshot = await _db.collection('iskonto')
        .where(FieldPath.documentId, isEqualTo: marka)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      return {
        'rate': data[discountLevel] ?? 0.0
      };
    } else {
      return {'rate': 0.0}; // İskonto oranı bulunamazsa 0.0 döndür
    }
  }
}
