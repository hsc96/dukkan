import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class DovizService {
  Future<Map<String, String>> fetchDovizKur() async {
    try {
      final response = await http.get(Uri.parse('https://www.tcmb.gov.tr/kurlar/today.xml'));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        String dolarKur = 'Veri yok';
        String euroKur = 'Veri yok';

        final currencies = document.findAllElements('Currency');
        for (var currency in currencies) {
          final currencyCode = currency.getAttribute('CurrencyCode');
          if (currencyCode == 'USD') {
            dolarKur = currency.findElements('ForexSelling').single.text;
          } else if (currencyCode == 'EUR') {
            euroKur = currency.findElements('ForexSelling').single.text;
          }
        }

        // Döviz kurlarını SharedPreferences'a kaydet
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('dolarKur', dolarKur);
        prefs.setString('euroKur', euroKur);
        prefs.setString('lastUpdate', DateTime.now().toString());

        return {'dolar': dolarKur, 'euro': euroKur};
      } else {
        return {
          'dolar': 'Hata: HTTP ${response.statusCode}',
          'euro': 'Hata: HTTP ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'dolar': 'Hata: $e', 'euro': 'Hata: $e'};
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
        return {'dolar': dolarKur, 'euro': euroKur};
      }
    }

    return await fetchDovizKur();
  }

  void scheduleDailyUpdate() {
    Timer.periodic(Duration(hours: 1), (timer) async {
      DateTime now = DateTime.now();
      if (now.hour == 15 && now.minute >= 30 && now.minute < 31) {
        await fetchDovizKur();
      }
    });
  }

  Future<void> initializeDovizKur() async {
    await fetchDovizKur();
    scheduleDailyUpdate();
  }
}
