import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class PasswordSettingsWidget extends StatefulWidget {
  @override
  _PasswordSettingsWidgetState createState() => _PasswordSettingsWidgetState();
}

class _PasswordSettingsWidgetState extends State<PasswordSettingsWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _updatePassword() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _oldPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);
        setState(() {
          _errorMessage = 'Şifre başarıyla güncellendi';
          _showSuccessDialog();
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password') {
          _errorMessage = 'Eski şifreniz yanlış. Lütfen tekrar deneyin.';
        } else {
          _errorMessage = e.message ?? 'Bir hata oluştu';
        }
      });
    }
  }

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // kullanıcı butona tıklamalı
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Şifre Güncelleme'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Şifrenizi değiştirmek istediğinizden emin misiniz?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Evet'),
              onPressed: () {
                Navigator.of(context).pop();
                _updatePassword();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // kullanıcı butona tıklamalı
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Başarılı'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('İşlem başarıyla tamamlandı.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Şifre Ayarları'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _oldPasswordController,
              decoration: InputDecoration(labelText: 'Eski Şifre'),
              obscureText: true,
            ),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: 'Yeni Şifre'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _showConfirmationDialog();
              },
              child: Text('Şifre Güncelle'),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
