import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class DovizService {
  Future<Map<String, String>> fetchDovizKur() async {
    try {
      final response = await http.get(Uri.parse('https://www.turkiye.gov.tr/doviz-kurlari'));
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var rows = document.querySelectorAll('tr');
        String dolarKur = 'Veri yok';
        String euroKur = 'Veri yok';

        for (var row in rows) {
          var cells = row.querySelectorAll('td');
          if (cells.length >= 4) {
            if (cells[0].text.contains('1 ABD DOLARI')) {
              dolarKur = cells[2].text.trim();  // Döviz Satış
            } else if (cells[0].text.contains('1 EURO')) {
              euroKur = cells[2].text.trim();  // Döviz Satış
            }
          }
        }
        // Döviz kurlarını SharedPreferences'a kaydet
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('dolarKur', dolarKur);
        prefs.setString('euroKur', euroKur);
        prefs.setString('lastUpdate', DateTime.now().toString());

        return { 'dolar': dolarKur, 'euro': euroKur };
      } else {
        return { 'dolar': 'Hata: HTTP ${response.statusCode}', 'euro': 'Hata: HTTP ${response.statusCode}' };
      }
    } catch (e) {
      return { 'dolar': 'Hata: $e', 'euro': 'Hata: $e' };
    }
  }

  Future<Map<String, String>> getDovizKur() async {
    final prefs = await SharedPreferences.getInstance();
    String? dolarKur = prefs.getString('dolarKur');
    String? euroKur = prefs.getString('euroKur');
    String? lastUpdate = prefs.getString('lastUpdate');

    if (dolarKur != null && euroKur != null && lastUpdate != null) {
      DateTime lastUpdateTime = DateTime.parse(lastUpdate);
      if (DateTime.now().difference(lastUpdateTime).inHours < 24) {
        return { 'dolar': dolarKur, 'euro': euroKur };
      }
    }

    return await fetchDovizKur();
  }

  void scheduleDailyUpdate() {
    Timer.periodic(Duration(minutes: 1), (timer) async {
      DateTime now = DateTime.now();
      if (now.hour == 15 && now.minute == 31) {
        await fetchDovizKur();
      }
    });
  }

  Future<void> initializeDovizKur() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastUpdate = prefs.getString('lastUpdate');

    if (lastUpdate != null) {
      DateTime lastUpdateTime = DateTime.parse(lastUpdate);
      if (lastUpdateTime.hour < 15 || (lastUpdateTime.hour == 15 && lastUpdateTime.minute < 31)) {
        await fetchDovizKur();
      }
    } else {
      await fetchDovizKur();
    }

    scheduleDailyUpdate();
  }
}
