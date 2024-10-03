// lib/custom_drawer.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'backup_restore_screen.dart'; // Yeni ekranı import ediyoruz
// Diğer gerekli importlarınızı buraya ekleyin

class CustomDrawer extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signOut(BuildContext context) async {
    await _auth.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<String?> _getUserRole() async {
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      return doc['role'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menü',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          // Mevcut Menü Öğeleri
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Anasayfa'),
            onTap: () {
              Navigator.pushNamed(context, '/home');
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Profil'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Ayarlar'),
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.assignment),
            title: Text('Beklenen Ürünler'),
            onTap: () {
              Navigator.pushNamed(context, '/awaited_products');
            },
          ),
          ListTile(
            leading: Icon(Icons.format_quote),
            title: Text('Teklifler'),
            onTap: () {
              Navigator.pushNamed(context, '/quotes');
            },
          ),
          ListTile(
            leading: Icon(Icons.shopping_bag),
            title: Text('Ürünler'),
            onTap: () {
              Navigator.pushNamed(context, '/products');
            },
          ),
          // Yeni Yedekleme & Geri Yükleme Menü Öğesi
          ListTile(
            leading: Icon(Icons.backup),
            title: Text('Yedekle & Yükle'),
            onTap: () {
              print('Yedekle & Yükle butonuna tıklandı');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BackupRestoreScreen()),
              ); // Yeni sayfanın rotası
            },
          ),
          // Kullanıcı Rolüne Göre Menü Öğeleri
          FutureBuilder<String?>(
            future: _getUserRole(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Loading...'),
                );
              }
              String? role = snapshot.data;
              if (role != null && role != 'giriş') {
                return Column(
                  children: [
                    if (role == 'admin') ...[
                      ListTile(
                        leading: Icon(Icons.local_offer),
                        title: Text('İskonto'),
                        onTap: () {
                          Navigator.pushNamed(context, '/iskonto');
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.update),
                        title: Text('Zam Güncelle'),
                        onTap: () {
                          Navigator.pushNamed(context, '/zam_guncelle');
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.supervised_user_circle),
                        title: Text('Kullanıcı Yönetimi'),
                        onTap: () {
                          Navigator.pushNamed(context, '/user_management');
                        },
                      ),
                    ]
                  ],
                );
              }
              return Container();
            },
          ),
          // Çıkış Yap Menü Öğesi
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text('Çıkış Yap'),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
