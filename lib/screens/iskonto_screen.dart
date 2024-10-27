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
  bool isEditable = false;
  bool isDeleting = false;
  List<String> customLevels = [];
  int currentIndex = 0;
  Map<String, String> customerDiscounts = {};
  TextEditingController searchController = TextEditingController();
  bool isCustomerEditable = false;

  // Yeni eklediklerimiz
  Map<String, Map<String, TextEditingController>> iskontoControllers = {};

  // İnternet bağlantısı kontrolü için değişkenler
  bool _isConnected = true; // İnternet bağlantısı durumu
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  // Harfler listesi
  List<String> letters = List.generate(26, (index) => String.fromCharCode(65 + index)); // A'dan Z'ye harfler

  // Her harf için müşteri sayıları
  Map<String, int> customerCounts = {};

  @override
  void initState() {
    super.initState();
    fetchUniqueBrands();
    fetchIskontoData();
    fetchCustomerCounts(); // Her harf için müşteri sayısını çekiyoruz
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
    // Kontrolörleri dispose edelim
    iskontoControllers.forEach((level, controllers) {
      controllers.forEach((brand, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }

  Future<void> fetchUniqueBrands() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('urunler').get();
    var allBrandsSet = <String>{};

    querySnapshot.docs.forEach((doc) {
      var data = doc.data() as Map<String, dynamic>;
      var brand = data['Marka'] as String?;
      if (brand != null && brand.isNotEmpty) {
        allBrandsSet.add(brand);
      }
    });

    setState(() {
      brands = allBrandsSet.toList();
    });
  }

  Future<void> fetchIskontoData() async {
    var iskontoDocs = await FirebaseFirestore.instance.collection('iskonto').get();

    setState(() {
      // Tüm iskonto verilerini markaya göre bir haritada tutalım
      Map<String, Map<String, dynamic>> iskontoData = {};
      iskontoDocs.docs.forEach((doc) {
        iskontoData[doc.id] = doc.data();
      });

      // 'brands' listesindeki her marka için iskonto verilerini ayarlayalım
      brands.forEach((brand) {
        var data = iskontoData[brand];

        // Eğer iskonto verisi varsa, ilgili seviyelerin iskonto oranlarını alalım
        if (data != null) {
          aSeviyeIskonto[brand] = (data['a_seviye'] ?? 0).toDouble();
          bSeviyeIskonto[brand] = (data['b_seviye'] ?? 0).toDouble();
          cSeviyeIskonto[brand] = (data['c_seviye'] ?? 0).toDouble();

          // Özel seviyeleri ekleyelim
          data.keys.forEach((key) {
            if (!['a_seviye', 'b_seviye', 'c_seviye'].contains(key)) {
              if (!customLevels.contains(key)) {
                customLevels.add(key);
                customIsExpanded[key] = false;
              }
              customIskonto[key] ??= {};
              customIskonto[key]![brand] = (data[key] ?? 0).toDouble();
            }
          });
        } else {
          // Eğer iskonto verisi yoksa, varsayılan olarak 0 değerini atayalım
          aSeviyeIskonto[brand] = 0.0;
          bSeviyeIskonto[brand] = 0.0;
          cSeviyeIskonto[brand] = 0.0;

          // Özel seviyeler için de 0 atayalım
          customLevels.forEach((level) {
            customIskonto[level] ??= {};
            customIskonto[level]![brand] = 0.0;
          });
        }
      });

      // Kontrolörleri başlatalım
      // A Seviye
      aSeviyeIskonto.forEach((brand, value) {
        iskontoControllers['A Seviye'] ??= {};
        iskontoControllers['A Seviye']![brand] = TextEditingController(text: value.toString());
      });

      // B Seviye
      bSeviyeIskonto.forEach((brand, value) {
        iskontoControllers['B Seviye'] ??= {};
        iskontoControllers['B Seviye']![brand] = TextEditingController(text: value.toString());
      });

      // C Seviye
      cSeviyeIskonto.forEach((brand, value) {
        iskontoControllers['C Seviye'] ??= {};
        iskontoControllers['C Seviye']![brand] = TextEditingController(text: value.toString());
      });

      // Özel Seviyeler
      for (var level in customLevels) {
        customIskonto[level]?.forEach((brand, value) {
          iskontoControllers[level] ??= {};
          iskontoControllers[level]![brand] = TextEditingController(text: value.toString());
        });
      }
    });
  }

  Future<void> fetchCustomerCounts() async {
    // Her harf için müşteri sayısını hesaplayalım
    for (var letter in letters) {
      String nextLetter = String.fromCharCode(letter.codeUnitAt(0) + 1);
      var querySnapshot = await FirebaseFirestore.instance
          .collection('veritabanideneme')
          .where('Açıklama', isGreaterThanOrEqualTo: letter)
          .where('Açıklama', isLessThan: nextLetter)
          .get();

      setState(() {
        customerCounts[letter] = querySnapshot.docs.length;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomersByLetter(String letter) async {
    String nextLetter = String.fromCharCode(letter.codeUnitAt(0) + 1);
    var querySnapshot = await FirebaseFirestore.instance
        .collection('veritabanideneme')
        .where('Açıklama', isGreaterThanOrEqualTo: letter)
        .where('Açıklama', isLessThan: nextLetter)
        .get();

    var customers = querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;

      // İskonto verilerini güncelle
      var description = data['Açıklama'] ?? '';
      if (data.containsKey('iskonto')) {
        String discount = data['iskonto'];
        customerDiscounts[description] = discount;

        // Özel iskonto seviyelerini ekle
        if (!['A Seviye', 'B Seviye', 'C Seviye'].contains(discount) && !customLevels.contains(discount)) {
          customLevels.add(discount);
          customIsExpanded[discount] = false;

          // Yeni seviye için customIskonto haritasını başlatın
          customIskonto[discount] = {};
          brands.forEach((brand) {
            customIskonto[discount]![brand] = 0.0;
          });
        }
      }

      return data;
    }).toList();

    // Müşterileri 'Açıklama' alanına göre alfabetik olarak sıralayalım
    customers.sort((a, b) => (a['Açıklama'] ?? '').compareTo(b['Açıklama'] ?? ''));

    return customers;
  }

  Widget buildCustomerListByLetter(String letter) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchCustomersByLetter(letter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Bu harfle başlayan müşteri yok.'));
        } else {
          List<Map<String, dynamic>> customerList = snapshot.data!;
          return ListView.builder(
            itemCount: customerList.length,
            itemBuilder: (context, index) {
              var customer = customerList[index];
              var customerId = customer['Kodu'];
              var description = customer['Açıklama'];
              var discount = customerDiscounts[description] ?? '';

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      description,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: DropdownButton<String>(
                      value: discount.isEmpty ? null : discount,
                      hint: Text('Seviye Seçin'),
                      onChanged: isCustomerEditable
                          ? (String? newValue) {
                        if (_isConnected) {
                          setState(() {
                            customerDiscounts[description] = newValue ?? '';
                          });
                        } else {
                          _showNoConnectionDialog(
                            'Bağlantı Sorunu',
                            'İnternet bağlantısı yok, seviye seçimi yapılamaz.',
                          );
                        }
                      }
                          : null,
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
                    child: isCustomerEditable
                        ? ElevatedButton(
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
                    )
                        : Container(),
                  ),
                ],
              );
            },
          );
        }
      },
    );
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
      var data = {
        'a_seviye': aSeviyeIskonto[brand] ?? 0,
        'b_seviye': bSeviyeIskonto[brand] ?? 0,
        'c_seviye': cSeviyeIskonto[brand] ?? 0,
        for (var customLevel in customLevels)
          customLevel: customIskonto[customLevel]?[brand] ?? 0,
      };
      batch.set(docRef, data);
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
        SnackBar(content: Text('İskonto kaydedilirken hata oluştu: $e')),
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
            iskontoControllers.remove(level);
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
        return StatefulBuilder( // StatefulBuilder ekledik
          builder: (context, setState) {
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
                    items: ['A Seviye', 'B Seviye', 'C Seviye', ...customLevels].map((String level) {
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
                  onPressed: () async {
                    String newLevel = newLevelController.text.trim();
                    if (newLevel.isNotEmpty) {
                      setState(() {
                        customLevels.add(newLevel);
                        customIsExpanded[newLevel] = false;
                        customIskonto[newLevel] = {};

                        Map<String, double> sourceMap = {};
                        if (selectedLevel != null) {
                          if (selectedLevel == 'A Seviye') {
                            sourceMap = aSeviyeIskonto;
                          } else if (selectedLevel == 'B Seviye') {
                            sourceMap = bSeviyeIskonto;
                          } else if (selectedLevel == 'C Seviye') {
                            sourceMap = cSeviyeIskonto;
                          } else {
                            sourceMap = customIskonto[selectedLevel] ?? {};
                          }
                          brands.forEach((brand) {
                            customIskonto[newLevel]![brand] = sourceMap[brand] ?? 0;
                          });
                        } else {
                          brands.forEach((brand) {
                            customIskonto[newLevel]![brand] = 0.0;
                          });
                        }

                        // Yeni seviye için kontrolörleri başlat
                        iskontoControllers[newLevel] = {};
                        customIskonto[newLevel]!.forEach((brand, value) {
                          iskontoControllers[newLevel]![brand] = TextEditingController(text: value.toString());
                        });
                      });

                      // Yeni iskonto seviyesini veritabanına kaydediyoruz
                      await saveIskonto();
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text('Ekle'),
                ),
              ],
            );
          },
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

        // Kontrolörü al
        iskontoControllers[label] ??= {};
        iskontoControllers[label]![brand] ??= TextEditingController(text: iskontoMap[brand]?.toString() ?? '0');

        TextEditingController controller = iskontoControllers[label]![brand]!;

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
                controller: controller,
                onChanged: (value) {
                  iskontoMap[brand] = double.tryParse(value) ?? 0;
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
              Expanded(
                child: DefaultTabController(
                  length: letters.length,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isCustomerEditable)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isCustomerEditable = true;
                                });
                              },
                              child: Text('Düzenle'),
                            ),
                          if (isCustomerEditable)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isCustomerEditable = false;
                                });
                              },
                              child: Text('İptal'),
                            ),
                        ],
                      ),
                      TabBar(
                        isScrollable: true,
                        tabs: letters.map((letter) {
                          int count = customerCounts[letter] ?? 0;
                          return Tab(
                            text: '$letter ($count)',
                          );
                        }).toList(),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: letters.map((letter) {
                            return buildCustomerListByLetter(letter);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (currentIndex == 0)
              Expanded(
                child: SingleChildScrollView(
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
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
