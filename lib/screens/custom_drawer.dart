import 'package:flutter/material.dart';
import '../utils/colors.dart';

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
        ],
      ),
    );
  }
}
