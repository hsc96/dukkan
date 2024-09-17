import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'network_service.dart'; // İnternet bağlantısı kontrol eden servis
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kullanıcı ekleme işlemi
  Future<void> addUser(String uid, String email, String role, String fullName) async {
    // İnternet bağlantısı kontrolü
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    await _db.collection('users').doc(uid).set({
      'email': email,
      'role': role,
      'fullName': fullName,
    });
  }

  // Email ile kullanıcı oluşturma
  Future<void> createUserWithEmail(String email, String password, String role, String fullName) async {
    // İnternet bağlantısı kontrolü
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    User? user = userCredential.user;

    if (user != null) {
      await addUser(user.uid, email, role, fullName);
    }
  }

  // Ürün detaylarını çekme
  Future<Map<String, dynamic>> fetchProductDetails(String productCode) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    try {
      QuerySnapshot querySnapshot = await _db
          .collection('urunler')
          .where('Kodu', isEqualTo: productCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      } else {
        return {}; // Ürün bulunamazsa boş bir map döner
      }
    } catch (e) {
      print('Error fetching product details: $e');
      return {}; // Hata durumunda boş bir map döner
    }
  }

  // Telefon numarası ile kullanıcı oluşturma
  Future<void> createUserWithPhone(String phone, String role, String fullName) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    // Telefon numarası ile kullanıcı oluşturma işlemleri
    // Bu kısımda Firebase Authentication'ın telefon numarası ile doğrulama yöntemlerini kullanmanız gerekecek
  }

  // Kullanıcı rolünü güncelleme
  Future<void> updateUserRole(String userId, String newRole) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    await _db.collection('users').doc(userId).update({'role': newRole});
  }

  // Barkod ile ürün bulma
  Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

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

  // Barkod ile birden fazla ürün bulma
  Future<List<Map<String, dynamic>>> fetchProductsByBarcode(String barcode) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    QuerySnapshot querySnapshot = await _db.collection('urunler')
        .where('Barkod', isEqualTo: barcode)
        .get();
    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data;
    }).toList();
  }

  // Müşteri adı filtreleme
  Future<List<String>> fetchFilteredCustomers(String query) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    QuerySnapshot querySnapshot = await _db.collection('veritabanideneme')
        .where('Açıklama', isGreaterThanOrEqualTo: query)
        .where('Açıklama', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['Açıklama'] ?? 'Açıklama bilgisi yok';
    }).cast<String>().toList();
  }

  // Markalarına göre ürün fiyatlarını güncelleme
  Future<void> updateProductPricesByBrands(List<String> brands, double zamOrani) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    QuerySnapshot querySnapshot = await _db.collection('urunler')
        .where('Marka', whereIn: brands)
        .get();

    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double currentPrice = double.tryParse(data['Fiyat']?.toString() ?? '0') ?? 0.0;
      double newPrice = currentPrice + (currentPrice * zamOrani / 100);

      await _db.collection('urunler').doc(doc.id).update(
          {'Fiyat': newPrice.toStringAsFixed(2)});
    }
  }

  // Markaları listeleme
  Future<List<String>> fetchUniqueBrands() async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    QuerySnapshot querySnapshot = await _db.collection('urunler').get();
    Set<String> brands = Set<String>();

    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      brands.add(data['Marka'] ?? '');
    }

    return brands.toList();
  }

  // Zam ekleme
  Future<void> addZamToCollection(String marka, String tarih, String yetkili, double zamOrani) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    await _db.collection('zam').add({
      'marka': marka,
      'tarih': tarih,
      'yetkili': yetkili,
      'zam orani': zamOrani,
    });
  }

  // Zam listesini çekme
  Future<List<Map<String, dynamic>>> fetchZamListesi() async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

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

  // Müşteri iskontosunu getirme
  Future<Map<String, dynamic>> getCustomerDiscount(String customerName) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

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

  // İskonto oranlarını getirme
  Future<Map<String, dynamic>> getDiscountRates(String discountLevel, String marka) async {
    if (!await NetworkService.hasInternetConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }

    var querySnapshot = await _db.collection('iskonto')
        .where(FieldPath.documentId, isEqualTo: marka)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      var data = querySnapshot.docs.first.data();
      return {'rate': data[discountLevel] ?? 0.0};
    } else {
      return {'rate': 0.0}; // İskonto oranı bulunamazsa 0.0 döndür
    }
  }
}
