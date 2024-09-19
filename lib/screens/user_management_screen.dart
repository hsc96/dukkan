import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRole = 'admin';
  String? _errorMessage;

  final List<String> _roles = ['admin', 'user', 'giriş'];

  FirestoreService _firestoreService = FirestoreService();

  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    // fetchUniqueBrands ve fetchZamListesi metodlarını kaldırdık çünkü bu metodlar UserManagementScreen ile ilgili değil
    _checkInitialConnectivity(); // Mevcut bağlantı durumunu kontrol et

    // İnternet bağlantısı değişikliklerini dinleyin
    connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      print('Connectivity Changed: $_isConnected'); // Debug için
    });
  }

  // Mevcut internet bağlantısını kontrol eden fonksiyon
  void _checkInitialConnectivity() async {
    try {
      ConnectivityResult result = await _connectivity.checkConnectivity();
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      print('Initial Connectivity Status: $_isConnected'); // Debug için
    } catch (e) {
      print("Bağlantı durumu kontrol edilirken hata oluştu: $e");
      setState(() {
        _isConnected = false;
      });
    }
  }

  // Yardımcı fonksiyon: İnternet yoksa uyarı dialog'u gösterir
  void _showNoConnectionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    connectivitySubscription.cancel(); // Aboneliği iptal et
    super.dispose();
  }

  Future<void> _createUser() async {
    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      String fullName = _fullNameController.text.trim();
      String phone = _phoneController.text.trim();

      if (email.isNotEmpty && password.isNotEmpty && fullName.isNotEmpty) {
        await _firestoreService.createUserWithEmail(email, password, _selectedRole, fullName, phone);
        setState(() {
          _errorMessage = 'Kullanıcı başarıyla oluşturuldu';
          _emailController.clear();
          _passwordController.clear();
          _fullNameController.clear();
          _phoneController.clear();
        });
      } else {
        setState(() {
          _errorMessage = 'Lütfen tüm alanları doldurun';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    List<Map<String, dynamic>> userList = [];

    try {
      var usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        var userData = userDoc.data();
        userList.add({
          'uid': userDoc.id,
          'email': userData['email'],
          'role': userData['role'],
          'fullName': userData['fullName'],
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }

    return userList;
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _firestoreService.updateUserRole(userId, newRole);
      setState(() {
        _errorMessage = 'Kullanıcı rolü güncellendi';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kullanıcı Yönetimi'),
      ),
      endDrawer: Drawer(), // Kendi CustomDrawer'ınızı kullanıyorsanız, onu ekleyin
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Ad Soyad Alanı
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(labelText: 'Ad Soyad'),
            ),
            SizedBox(height: 10),
            // Email Alanı
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 10),
            // Şifre Alanı
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            SizedBox(height: 10),
            // Telefon Numarası Alanı
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Telefon Numarası'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 10),
            // Rol Dropdown
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(labelText: 'Rol'),
              items: _roles.map((String role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue!;
                });
              },
            ),
            SizedBox(height: 20),
            // "Kullanıcı Oluştur" Butonu
            ElevatedButton(
              onPressed: () {
                if (_isConnected) {
                  _createUser();
                } else {
                  _showNoConnectionDialog(
                    'Bağlantı Sorunu',
                    'İnternet bağlantısı yok, kullanıcı oluşturma işlemi gerçekleştirilemiyor.',
                  );
                }
              },
              child: Text('Kullanıcı Oluştur'),
            ),
            SizedBox(height: 10),
            // Hata veya Başarı Mesajı
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            SizedBox(height: 20),
            // Kullanıcı Listesi
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchUsers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  var users = snapshot.data!;
                  var allRoles = [..._roles, 'Kullanım Dışı'];
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var user = users[index];
                      return ListTile(
                        title: Text(user['fullName']),
                        subtitle: Text('Email: ${user['email']}\nRol: ${user['role']}'),
                        trailing: DropdownButton<String>(
                          value: user['role'],
                          items: allRoles.map((String role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (String? newRole) {
                            if (newRole != null) {
                              if (_isConnected) {
                                _updateUserRole(user['uid'], newRole);
                              } else {
                                _showNoConnectionDialog(
                                  'Bağlantı Sorunu',
                                  'İnternet bağlantısı yok, rol güncelleme işlemi gerçekleştirilemiyor.',
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Kendi CustomBottomBar'ınızı kullanıyorsanız, onu ekleyin
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Kullanıcılar'),
          // Diğer item'lar...
        ],
      ),
    );
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserWithEmail(String email, String password, String role, String fullName, String phone) async {
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    User? user = userCredential.user;

    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'email': email,
        'role': role,
        'fullName': fullName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      throw Exception('Kullanıcı oluşturulamadı.');
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

// Diğer Firestore işlemleriniz...
}
