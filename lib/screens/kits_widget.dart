import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KitsWidget extends StatefulWidget {
  final String customerName;

  KitsWidget({required this.customerName});

  @override
  _KitsWidgetState createState() => _KitsWidgetState();
}

class _KitsWidgetState extends State<KitsWidget> {
  List<Map<String, dynamic>> mainKits = [];

  @override
  void initState() {
    super.initState();
    fetchKits();
  }

  Future<void> fetchKits() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('kitler')
        .where('customerName', isEqualTo: widget.customerName)
        .get();

    setState(() {
      mainKits = querySnapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'subKits': List<Map<String, dynamic>>.from(data['subKits'] ?? []),
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
        };
      }).toList();
    });
  }

  void showEditSubKitDialog(int kitIndex, int subKitIndex) {
    // Buraya alt kit düzenleme kodunu ekleyebilirsiniz
  }

  Widget buildKitsList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: mainKits.length,
      itemBuilder: (context, index) {
        var kit = mainKits[index];

        return ExpansionTile(
          title: Row(
            children: [
              Text(kit['name']),
            ],
          ),
          children: [
            ...kit['subKits'].map<Widget>((subKit) {
              int subKitIndex = kit['subKits'].indexOf(subKit);

              return ExpansionTile(
                title: Row(
                  children: [
                    Text(subKit['name']),
                  ],
                ),
                children: [
                  ...subKit['products'].map<Widget>((product) {
                    return ListTile(
                      title: Text(product['Detay'] ?? ''),
                      subtitle: Text('Kodu: ${product['Kodu'] ?? ''}, Adet: ${product['Adet'] ?? ''}'),
                    );
                  }).toList(),
                  ListTile(
                    title: ElevatedButton(
                      onPressed: () => showEditSubKitDialog(index, subKitIndex),
                      child: Text('Düzenle'),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Expanded(child: buildKitsList());
  }
}
