import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

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

  Future<void> _createUser() async {
    try {
      String email = _emailController.text;
      String password = _passwordController.text;
      String fullName = _fullNameController.text;
      String phone = _phoneController.text;

      if (email.isNotEmpty && password.isNotEmpty && fullName.isNotEmpty) {
        await _firestoreService.createUserWithEmail(email, password, _selectedRole, fullName);
        setState(() {
          _errorMessage = 'Kullanıcı başarıyla oluşturuldu';
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
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kullanıcı Yönetimi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(labelText: 'Ad Soyad'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Telefon Numarası'),
            ),
            DropdownButton<String>(
              value: _selectedRole,
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
            ElevatedButton(
              onPressed: _createUser,
              child: Text('Kullanıcı Oluştur'),
            ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
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
                              _updateUserRole(user['uid'], newRole);
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
    );
  }
}
