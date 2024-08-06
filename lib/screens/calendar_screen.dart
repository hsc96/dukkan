import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  Map<String, List<Map<String, dynamic>>> _salesForSelectedDay = {};

  bool _showPendingProducts = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingProducts();
    _fetchSalesDataForSelectedDay(_focusedDay);
  }

  void _fetchPendingProducts() async {
    var querySnapshot =
    await FirebaseFirestore.instance.collection('pendingProducts').get();

    setState(() {
      _events.clear();
      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime? deliveryDate;
        try {
          if (data['deliveryDate'] != null) {
            deliveryDate = (data['deliveryDate'] as Timestamp).toDate();
          }
        } catch (e) {
          print("Error converting deliveryDate: $e");
          continue;
        }
        if (deliveryDate != null) {
          DateTime deliveryDateOnly =
          DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
          if (_events[deliveryDateOnly] == null) {
            _events[deliveryDateOnly] = [];
          }
          _events[deliveryDateOnly]!.add(data);
        }
      }
    });
  }

  void _fetchSalesDataForSelectedDay(DateTime selectedDay) async {
    String formattedDate = DateFormat('dd.MM.yyyy').format(selectedDay);

    var salesSnapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('date', isEqualTo: formattedDate)
        .get();

    var usersSnapshot =
    await FirebaseFirestore.instance.collection('users').get();

    Map<String, String> userIdToNameMap = {};
    for (var userDoc in usersSnapshot.docs) {
      var userData = userDoc.data();
      userIdToNameMap[userDoc.id] =
          userData['fullName'] ?? 'Bilinmeyen Satış Elemanı';
    }

    setState(() {
      _salesForSelectedDay.clear();
      for (var saleDoc in salesSnapshot.docs) {
        var saleData = saleDoc.data();

        String salesmanName =
            userIdToNameMap[saleData['userId']] ?? 'Bilinmeyen Satış Elemanı';

        List<Map<String, dynamic>> products =
        (saleData['products'] as List<dynamic>).map((product) {
          return {
            'Detay': product['Detay'] ?? 'Ürün İsmi Yok',
            'Adet Fiyatı': _parseDouble(product['Adet Fiyatı']),
            'Adet': _parseInt(product['Adet']),
            'Toplam Fiyat': _parseDouble(product['Toplam Fiyat']),
            'salesmanName': salesmanName,
          };
        }).toList();

        products.removeWhere((product) =>
        product['Detay'].toString().toLowerCase().contains('toplam') ||
            product['Adet Fiyatı'] == 0.0);

        String customerName = saleData['customerName'] ?? 'Bilinmeyen Müşteri';

        if (_salesForSelectedDay.containsKey(customerName)) {
          _salesForSelectedDay[customerName]!.addAll(products);
        } else {
          _salesForSelectedDay[customerName] = products;
        }
      }
    });
  }

  double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    double toplamSatisTutari = 0.0;
    _salesForSelectedDay.values.forEach((products) {
      products.forEach((product) {
        toplamSatisTutari += product['Toplam Fiyat'];
      });
    });

    return Scaffold(
      appBar: CustomAppBar(title: 'Takvim'),
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _focusedDay,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialEntryMode: DatePickerEntryMode.calendarOnly,
                  );
                  if (picked != null && picked != _focusedDay) {
                    setState(() {
                      _focusedDay = DateTime(
                          picked.year, _focusedDay.month, _focusedDay.day);
                      _fetchSalesDataForSelectedDay(_focusedDay);
                    });
                  }
                },
                child: Text('${_focusedDay.year}'),
              ),
            ],
          ),
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _fetchSalesDataForSelectedDay(selectedDay);
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${events.length}',
                          style: TextStyle().copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Container();
              },
              defaultBuilder: (context, date, focusedDay) {
                if (_events[date] != null && _events[date]!.isNotEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle().copyWith(
                        fontSize: 16.0,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          Expanded(
            child: _selectedDay == null
                ? Center(child: Text('Lütfen bir tarih seçiniz.'))
                : Column(
              children: [
                ToggleButtons(
                  isSelected: [
                    _showPendingProducts,
                    !_showPendingProducts
                  ],
                  onPressed: (index) {
                    setState(() {
                      _showPendingProducts = index == 0;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Beklenen Ürünler'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Satışlar'),
                    ),
                  ],
                ),
                Expanded(
                  child: _showPendingProducts
                      ? ListView(
                    children: _getEventsForDay(
                        _selectedDay ?? _focusedDay)
                        .map((event) {
                      return ListTile(
                        title: Text(
                            event['Detay'] ?? 'Detay bilgisi yok'),
                        subtitle: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Müşteri: ${event['Müşteri Ünvanı'] ?? 'Müşteri bilgisi yok'}'),
                            Text(
                                'Teklif No: ${event['Teklif No'] ?? 'Teklif numarası yok'}'),
                            Text(
                                'Teklif Tarihi: ${event['Teklif Tarihi'] ?? 'Tarih yok'}'),
                            Text(
                                'Sipariş No: ${event['Sipariş No'] ?? 'Sipariş numarası yok'}'),
                            Text(
                                'Sipariş Tarihi: ${event['Sipariş Tarihi'] ?? 'Tarih yok'}'),
                            Text(
                                'İşleme Alan: ${event['İşleme Alan'] ?? 'admin'}'),
                            Text(
                                'Adet: ${event['Adet'] ?? 'Adet bilgisi yok'}'),
                            Text(
                                'Adet Fiyatı: ${event['Adet Fiyatı'] ?? 'Adet fiyatı yok'}'),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                      : ListView(
                    children:
                    _salesForSelectedDay.entries.map((entry) {
                      String customerName = entry.key;
                      List<Map<String, dynamic>> products =
                          entry.value;

                      double totalAmount = products.fold(
                          0.0,
                              (sum, product) =>
                          sum + product['Toplam Fiyat']);

                      return Card(
                        margin: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: ExpansionTile(
                          title: Text(
                              '$customerName - Toplam: ${totalAmount.toStringAsFixed(2)} TL'),
                          children: products.map((product) {
                            return ListTile(
                              title: Text(product['Detay']),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Adet Fiyatı: ${product['Adet Fiyatı'].toStringAsFixed(2)} TL'),
                                  Text(
                                      'Adet: ${product['Adet']}'),
                                  Text(
                                      'Toplam Fiyat: ${product['Toplam Fiyat'].toStringAsFixed(2)} TL'),
                                  Text(
                                      'Satış Elemanı: ${product['salesmanName']}'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Toplam Satış Tutarı: ${toplamSatisTutari.toStringAsFixed(2)} TL',
                    style: TextStyle(fontSize: 16, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
