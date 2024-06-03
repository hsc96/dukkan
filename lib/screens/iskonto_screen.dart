import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_drawer.dart';
import 'custom_bottom_bar.dart';
import 'custom_app_bar.dart';

class IskontoScreen extends StatefulWidget {
  @override
  _IskontoScreenState createState() => _IskontoScreenState();
}

class _IskontoScreenState extends State<IskontoScreen> {
  List<String> brands = [];
  Map<String, double> aSeviyeIskonto = {};
  Map<String, double> bSeviyeIskonto = {};
  Map<String, double> cSeviyeIskonto = {};
  Map<String, Map<String, double>> customIskonto = {};
  Map<String, bool> customIsExpanded = {};
  bool isASeviyeOpen = false;
  bool isBSeviyeOpen = false;
  bool isCSeviyeOpen = false;
  bool isEditable = true;
  bool isDeleting = false;
  List<String> customLevels = [];

  @override
  void initState() {
    super.initState();
    fetchUniqueBrands();
    fetchIskontoData();
  }

  Future<void> fetchUniqueBrands() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('urunler').get();
    var allBrands = querySnapshot.docs.map((doc) => doc.data()['Marka'] as String).toSet().toList();

    setState(() {
      brands = allBrands;
    });
  }

  Future<void> fetchIskontoData() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('iskonto').get();
    var docs = querySnapshot.docs;

    setState(() {
      docs.forEach((doc) {
        var data = doc.data();
        aSeviyeIskonto[doc.id] = data['a_seviye']?.toDouble() ?? 0;
        bSeviyeIskonto[doc.id] = data['b_seviye']?.toDouble() ?? 0;
        cSeviyeIskonto[doc.id] = data['c_seviye']?.toDouble() ?? 0;
        for (var key in data.keys) {
          if (!['a_seviye', 'b_seviye', 'c_seviye'].contains(key) && !customLevels.contains(key)) {
            customLevels.add(key);
            customIsExpanded[key] = false;
          }
          if (customLevels.contains(key)) {
            customIskonto[key] ??= {};
            customIskonto[key]![doc.id] = data[key]?.toDouble() ?? 0;
          }
        }
      });
      isEditable = docs.isEmpty;
    });
  }

  Future<void> saveIskonto() async {
    var batch = FirebaseFirestore.instance.batch();
    var iskontoCollection = FirebaseFirestore.instance.collection('iskonto');

    brands.forEach((brand) {
      var docRef = iskontoCollection.doc(brand);
      batch.set(docRef, {
        'a_seviye': aSeviyeIskonto[brand] ?? 0,
        'b_seviye': bSeviyeIskonto[brand] ?? 0,
        'c_seviye': cSeviyeIskonto[brand] ?? 0,
        for (var customLevel in customLevels)
          customLevel: customIskonto[customLevel]?[brand] ?? 0,
      });
    });

    await batch.commit();

    setState(() {
      isEditable = false;
    });
  }

  Future<void> deleteLevel(String level) async {
    bool confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seviye Sil'),
          content: Text('Bu seviyeyi silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Hayır'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );

    if (confirmed) {
      bool finalConfirmed = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Seviye Sil'),
            content: Text('$level seviyesini kaldırmak üzeresiniz. Onaylıyor musunuz?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text('Hayır'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text('Evet'),
              ),
            ],
          );
        },
      );

      if (finalConfirmed) {
        await FirebaseFirestore.instance.collection('iskonto').get().then((querySnapshot) {
          querySnapshot.docs.forEach((doc) {
            if (doc.data().containsKey(level)) {
              FirebaseFirestore.instance.collection('iskonto').doc(doc.id).update({level: FieldValue.delete()});
            }
          });
        });

        setState(() {
          customLevels.remove(level);
          customIskonto.remove(level);
          customIsExpanded.remove(level);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$level seviyesi kaldırıldı')),
        );
      }
    }
  }

  void addNewLevel() async {
    TextEditingController newLevelController = TextEditingController();
    String? selectedLevel;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Yeni Seviye Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newLevelController,
                decoration: InputDecoration(labelText: 'Yeni Seviye Adı'),
              ),
              SizedBox(height: 20),
              Text('Mevcut Seviyeden Kopyala?'),
              DropdownButton<String>(
                hint: Text('Seviye Seçin'),
                value: selectedLevel,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedLevel = newValue;
                  });
                },
                items: ['A Seviye', 'B Seviye', 'C Seviye'].map((String level) {
                  return DropdownMenuItem<String>(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  String newLevel = newLevelController.text.trim();
                  if (newLevel.isNotEmpty) {
                    customLevels.add(newLevel);
                    customIsExpanded[newLevel] = false;
                    customIskonto[newLevel] = {};
                    if (selectedLevel != null) {
                      Map<String, double> sourceMap;
                      if (selectedLevel == 'A Seviye') {
                        sourceMap = aSeviyeIskonto;
                      } else if (selectedLevel == 'B Seviye') {
                        sourceMap = bSeviyeIskonto;
                      } else {
                        sourceMap = cSeviyeIskonto;
                      }
                      brands.forEach((brand) {
                        customIskonto[newLevel]![brand] = sourceMap[brand] ?? 0;
                      });
                    }
                  }
                });
                Navigator.of(context).pop();
              },
              child: Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  Widget buildIskontoList(Map<String, double> iskontoMap, String label, {bool isCustom = false, String? level}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: brands.length,
      itemBuilder: (context, index) {
        String brand = brands[index];
        String key = isCustom ? brand : brand;
        return Row(
          children: [
            Expanded(
              child: Text(
                brand,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: TextField(
                enabled: isEditable,
                decoration: InputDecoration(labelText: '$label İskonto (%)'),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: iskontoMap[key]?.toString() ?? '0'),
                onChanged: (value) {
                  setState(() {
                    iskontoMap[key] = double.tryParse(value) ?? 0;
                  });
                },
              ),
            ),
            if (isEditable && isCustom && level != null)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteLevel(level),
              ),
          ],
        );
      },
    );
  }

  void enableEditing() {
    setState(() {
      isEditable = true;
      isDeleting = true;
    });
  }

  void disableEditing() {
    setState(() {
      isEditable = false;
      isDeleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'İskonto'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    if (index == 0) isASeviyeOpen = !isASeviyeOpen;
                    if (index == 1) isBSeviyeOpen = !isBSeviyeOpen;
                    if (index == 2) isCSeviyeOpen = !isCSeviyeOpen;
                    if (index >= 3) customIsExpanded[customLevels[index - 3]] =
                    !customIsExpanded[customLevels[index - 3]]!;
                  });
                },
                children: [
                  ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text('A Seviye İskonto'),
                      );
                    },
                    body: buildIskontoList(aSeviyeIskonto, 'A Seviye'),
                    isExpanded: isASeviyeOpen,
                  ),
                  ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text('B Seviye İskonto'),
                      );
                    },
                    body: buildIskontoList(bSeviyeIskonto, 'B Seviye'),
                    isExpanded: isBSeviyeOpen,
                  ),
                  ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text('C Seviye İskonto'),
                      );
                    },
                    body: buildIskontoList(cSeviyeIskonto, 'C Seviye'),
                    isExpanded: isCSeviyeOpen,
                  ),
                  for (var customLevel in customLevels)
                    ExpansionPanel(
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text('$customLevel İskonto')),
                              if (isEditable)
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  onPressed: () => deleteLevel(customLevel),
                                ),
                            ],
                          ),
                        );
                      },
                      body: buildIskontoList(customIskonto[customLevel]!, customLevel, isCustom: true, level: customLevel),
                      isExpanded: customIsExpanded[customLevel] ?? false,
                    ),
                ],
              ),
              SizedBox(height: 20),
              if (isEditable)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: saveIskonto,
                      child: Text('Kaydet'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: addNewLevel,
                      child: Text('Seviye Ekle'),
                    ),
                  ],
                ),
              if (!isEditable)
                ElevatedButton(
                  onPressed: enableEditing,
                  child: Text('Düzenle'),
                ),
              if (isEditable && isDeleting)
                ElevatedButton(
                  onPressed: disableEditing,
                  child: Text('İptal'),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
