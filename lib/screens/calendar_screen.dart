import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';
import 'custom_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _fetchPendingProducts();
  }

  void _fetchPendingProducts() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('pendingProducts').get();

    setState(() {
      _events.clear();
      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime? deliveryDate;
        try {
          deliveryDate = (data['deliveryDate'] as Timestamp).toDate();
        } catch (e) {
          print("Error converting deliveryDate: $e");
          continue;
        }
        DateTime deliveryDateOnly = DateTime(deliveryDate!.year, deliveryDate.month, deliveryDate.day);
        if (_events[deliveryDateOnly] == null) {
          _events[deliveryDateOnly] = [];
        }
        _events[deliveryDateOnly]!.add(data);
      }
    });
  }

  void _selectYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && picked != _focusedDay) {
      setState(() {
        _focusedDay = DateTime(picked.year, _focusedDay.month, _focusedDay.day);
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Takvim'),
      endDrawer: CustomDrawer(),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _selectYear(context),
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
            child: ListView(
              children: _getEventsForDay(_selectedDay ?? _focusedDay).map((event) {
                return ListTile(
                  title: Text(event['Detay'] ?? 'Detay yok'), // Ürünün detayı başlıkta
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Müşteri: ${event['Müşteri Ünvanı'] ?? 'Müşteri bilgisi yok'}'),
                      Text('Teklif No: ${event['Teklif No'] ?? 'Teklif numarası yok'}'),
                      Text('Teklif Tarihi: ${event['Teklif Tarihi'] ?? 'Tarih yok'}'),
                      Text('Sipariş No: ${event['Sipariş No'] ?? 'Sipariş numarası yok'}'),
                      Text('Sipariş Tarihi: ${event['Sipariş Tarihi'] ?? 'Tarih yok'}'),
                      Text('İşleme Alan: ${event['İşleme Alan'] ?? 'admin'}'),
                      Text('Adet: ${event['Adet'] ?? 'Adet yok'}'),
                      Text('Adet Fiyatı: ${event['Adet Fiyatı'] ?? 'Adet fiyatı yok'}'),
                    ],
                  ),
                );


              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(),
    );
  }
}
