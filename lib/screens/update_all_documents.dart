import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateAllDocumentsScreen extends StatefulWidget {
  @override
  _UpdateAllDocumentsScreenState createState() => _UpdateAllDocumentsScreenState();
}

class _UpdateAllDocumentsScreenState extends State<UpdateAllDocumentsScreen> {
  bool isUpdating = false;

  Future<void> updateAllDocuments() async {
    setState(() {
      isUpdating = true;
    });

    var collection = FirebaseFirestore.instance.collection('veritabanideneme');
    var querySnapshot = await collection.get();

    for (var doc in querySnapshot.docs) {
      var data = doc.data();
      String aciklama = data['Açıklama'] ?? '';
      Map<String, dynamic> updates = {
        'AçıklamaLowerCase': aciklama.toLowerCase(),
      };

      // Eğer Fatura Kesilecek Tutar alanı yoksa ekle
      if (!data.containsKey('Fatura Kesilecek Tutar')) {
        updates['Fatura Kesilecek Tutar'] = 0.0;
      }

      await doc.reference.update(updates);
    }

    setState(() {
      isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tüm belgeler güncellendi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Belgeleri Güncelle')),
      body: Center(
        child: isUpdating
            ? CircularProgressIndicator()
            : ElevatedButton(
          onPressed: updateAllDocuments,
          child: Text('Tüm Belgeleri Güncelle'),
        ),
      ),
    );
  }
}
