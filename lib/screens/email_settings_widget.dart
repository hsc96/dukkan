import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class EmailSettingsWidget extends StatefulWidget {
  @override
  _EmailSettingsWidgetState createState() => _EmailSettingsWidgetState();
}

class _EmailSettingsWidgetState extends State<EmailSettingsWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  String _errorMessage = '';

  Future<void> _updateEmail() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateEmail(_emailController.text);
        setState(() {
          _errorMessage = 'Email başarıyla güncellendi';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Bir hata oluştu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Email Ayarları'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Yeni Email Adresini Girin'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateEmail,
              child: Text('Email Güncelle'),
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
