import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_drawer.dart';
import 'custom_bottom_bar.dart';
import 'custom_app_bar.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  int currentIndex = 0;
  List<Map<String, dynamic>> customers = [];
  Map<String, String> customerDiscounts = {};
  TextEditingController searchController = TextEditingController();

  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    fetchUniqueBrands();
    fetchIskontoData();
    fetchCustomers();
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
    searchController.dispose(); // Doğru isimlendirme
    connectivitySubscription.cancel(); // Aboneliği iptal et
    super.dispose();
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

  Future<void> fetchCustomers() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('veritabanideneme').get();
    var docs = querySnapshot.docs;

    setState(() {
      customers = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      for (var customer in customers) {
        if (customer.containsKey('iskonto')) {
          customerDiscounts[customer['Açıklama']] = customer['iskonto'];
        }
      }
    });
  }

  Future<void> saveIskonto() async {
    if (!_isConnected) {
      _showNoConnectionDialog(
        'Bağlantı Sorunu',
        'İnternet bağlantısı yok, iskonto kaydetme işlemi gerçekleştirilemiyor.',
      );
      return;
    }

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

    try {
      await batch.commit();

      setState(() {
        isEditable = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İskonto verileri başarıyla kaydedildi.')),
      );
    } catch (e) {
      print('İskonto kaydedilirken hata oluştu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İskonto kaydedilirken hata oluştu.')),
      );
    }
  }

  Future<void> saveCustomerDiscounts(String customerId, String description) async {
    if (!_isConnected) {
      _showNoConnectionDialog(
        'Bağlantı Sorunu',
        'İnternet bağlantısı yok, iskonto kaydetme işlemi gerçekleştirilemiyor.',
      );
      return;
    }

    var customerCollection = FirebaseFirestore.instance.collection('veritabanideneme');
    var selectedDiscount = customerDiscounts[description];

    try {
      // Belge mevcut değilse, oluştur
      var querySnapshot = await customerCollection.where('Açıklama', isEqualTo: description).get();
      if (querySnapshot.docs.isNotEmpty) {
        var docRef = querySnapshot.docs.first.reference;
        await docRef.update({
          'iskonto': selectedDiscount
        });
      } else {
        await customerCollection.add({
          'Açıklama': description,
          'iskonto': selectedDiscount
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İskonto kaydedildi')),
      );
    } catch (e) {
      print('İskonto kaydedilirken hata oluştu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İskonto kaydedilirken hata oluştu.')),
      );
    }
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
        try {
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
        } catch (e) {
          print('Seviye kaldırılırken hata oluştu: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Seviye kaldırılırken hata oluştu.')),
          );
        }
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
                icon: Icon(Icons.close, color: Colors.red),
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

  Widget buildCustomerList() {
    List<Map<String, dynamic>> filteredCustomers = customers.where((customer) {
      return customer['Açıklama']
          .toString()
          .toLowerCase()
          .contains(searchController.text.toLowerCase());
    }).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filteredCustomers.length,
      itemBuilder: (context, index) {
        var customer = filteredCustomers[index];
        var customerId = customer['Kodu'];
        var description = customer['Açıklama'];
        var discount = customerDiscounts[description] ?? '';
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                customer['Açıklama'] ?? '',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 2,
              child: DropdownButton<String>(
                value: discount.isEmpty ? null : discount,
                hint: Text('Seviye Seçin'),
                onChanged: (String? newValue) {
                  if (_isConnected) {  // İnternet bağlantısı kontrolü
                    setState(() {
                      customerDiscounts[description] = newValue ?? '';
                    });
                  } else {
                    _showNoConnectionDialog(
                      'Bağlantı Sorunu',
                      'İnternet bağlantısı yok, seviye seçimi yapılamaz.',
                    );
                  }
                },
                items: ['A Seviye', 'B Seviye', 'C Seviye', ...customLevels].map((String level) {
                  return DropdownMenuItem<String>(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
              ),

            ),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: () {
                  if (_isConnected) {
                    saveCustomerDiscounts(customerId, description);
                  } else {
                    _showNoConnectionDialog(
                      'Bağlantı Sorunu',
                      'İnternet bağlantısı yok, kaydetme işlemi gerçekleştirilemiyor.',
                    );
                  }
                },
                child: Text('Kaydet'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'İskonto'),
      endDrawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: [currentIndex == 0, currentIndex == 1],
              onPressed: (int index) {
                setState(() {
                  currentIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('İskonto Düzenle'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('İskonto Eşleştir'),
                ),
              ],
            ),
            if (currentIndex == 1)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Ünvan Ara...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            Expanded(
              child: currentIndex == 0
                  ? SingleChildScrollView(
                child: Column(
                  children: [
                    ExpansionPanelList(
                      expansionCallback: (int index, bool isExpanded) {
                        setState(() {
                          if (index == 0) isASeviyeOpen = !isASeviyeOpen;
                          if (index == 1) isBSeviyeOpen = !isBSeviyeOpen;
                          if (index == 2) isCSeviyeOpen = !isCSeviyeOpen;
                          if (index >= 3)
                            customIsExpanded[customLevels[index - 3]] =
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
                            body: buildIskontoList(customIskonto[customLevel]!, customLevel,
                                isCustom: true, level: customLevel),
                            isExpanded: customIsExpanded[customLevel] ?? false,
                          ),
                      ],
                    ),
                    SizedBox(height: 20),
                    if (isEditable)
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (_isConnected) {
                                saveIskonto();
                              } else {
                                _showNoConnectionDialog(
                                  'Bağlantı Sorunu',
                                  'İnternet bağlantısı yok, iskonto kaydetme işlemi gerçekleştirilemiyor.',
                                );
                              }
                            },
                            child: Text('Kaydet'),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              if (_isConnected) {
                                addNewLevel();
                              } else {
                                _showNoConnectionDialog(
                                  'Bağlantı Sorunu',
                                  'İnternet bağlantısı yok, seviye ekleme işlemi gerçekleştirilemiyor.',
                                );
                              }
                            },
                            child: Text('Seviye Ekle'),
                          ),
                        ],
                      ),
                    if (!isEditable)
                      ElevatedButton(
                        onPressed: () {
                          if (_isConnected) {
                            enableEditing();
                          } else {
                            _showNoConnectionDialog(
                              'Bağlantı Sorunu',
                              'İnternet bağlantısı yok, düzenleme işlemi gerçekleştirilemiyor.',
                            );
                          }
                        },
                        child: Text('Düzenle'),
                      ),
                    if (isEditable && isDeleting)
                      ElevatedButton(
                        onPressed: disableEditing,
                        child: Text('İptal'),
                      ),
                  ],
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    buildCustomerList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}

class FilterChipWidget extends StatefulWidget {
  final List<String> filterList;
  final String filterType;
  final ValueChanged<List<String>> onSelectionChanged;

  FilterChipWidget({required this.filterList, required this.filterType, required this.onSelectionChanged});

  @override
  _FilterChipWidgetState createState() => _FilterChipWidgetState();
}

class _FilterChipWidgetState extends State<FilterChipWidget> {
  List<String> selectedFilters = [];

  @override
  void initState() {
    super.initState();
    selectedFilters = widget.filterList;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('urunler').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        List<String> filters = [];
        snapshot.data!.docs.forEach((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String value = data[widget.filterType] ?? '';
          if (!filters.contains(value) && value.isNotEmpty) {
            filters.add(value);
          }
        });

        return Wrap(
          spacing: 8.0,
          children: filters.map((filter) {
            return FilterChip(
              label: Text(filter),
              selected: selectedFilters.contains(filter),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedFilters.add(filter);
                  } else {
                    selectedFilters.removeWhere((String name) {
                      return name == filter;
                    });
                  }
                });
                widget.onSelectionChanged(selectedFilters);
              },
            );
          }).toList(),
        );
      },
    );
  }
}
