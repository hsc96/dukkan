import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'scan_screen.dart'; // ScanScreen sayfası için import
import 'ZamGuncelleScreen.dart'; // ZamGuncelleScreen sayfası için import

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorTheme3,
            ),
            child: Text(
              'Menü',
              style: TextStyle(
                color: colorTheme5,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Anasayfa'),
            onTap: () {
              Navigator.pushNamed(context, '/');
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Profil'),
            onTap: () {
              // Profil butonuna basıldığında yapılacak işlemler
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Ayarlar'),
            onTap: () {
              // Ayarlar butonuna basıldığında yapılacak işlemler
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
            leading: Icon(Icons.qr_code_scanner),
            title: Text('Ürün Tara'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScanScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.update),
            title: Text('Zam Güncelle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ZamGuncelleScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
