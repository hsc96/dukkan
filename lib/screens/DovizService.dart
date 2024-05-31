import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

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
        return { 'dolar': dolarKur, 'euro': euroKur };
      } else {
        return { 'dolar': 'Hata: HTTP ${response.statusCode}', 'euro': 'Hata: HTTP ${response.statusCode}' };
      }
    } catch (e) {
      return { 'dolar': 'Hata: $e', 'euro': 'Hata: $e' };
    }
  }
}