import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

class ProcessedExcel {
  static Future<void> generateProcessedExcel(List<Map<String, dynamic>> products, String customerName, String processName) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    // Başlık satırı ekleniyor
    sheet.getRangeByName('A1').setText('Kodu');
    sheet.getRangeByName('B1').setText('Detay');
    sheet.getRangeByName('C1').setText('Adet');
    sheet.getRangeByName('D1').setText('Adet Fiyatı');
    sheet.getRangeByName('E1').setText('Toplam Fiyat');
    sheet.getRangeByName('F1').setText('Buton Adı');
    sheet.getRangeByName('G1').setText('Sipariş No');

    // Ürün satırları ekleniyor
    for (int i = 0; i < products.length; i++) {
      var product = products[i];
      int rowIndex = i + 2;  // Başlık satırından sonra geliyor

      sheet.getRangeByName('A$rowIndex').setText(product['Kodu']?.toString() ?? '');
      sheet.getRangeByName('B$rowIndex').setText(product['Detay']?.toString() ?? '');
      sheet.getRangeByName('C$rowIndex').setText(product['Adet']?.toString() ?? '');
      sheet.getRangeByName('D$rowIndex').setText(product['Adet Fiyatı']?.toString() ?? '');
      sheet.getRangeByName('E$rowIndex').setText(product['Toplam Fiyat']?.toString() ?? '');
      sheet.getRangeByName('F$rowIndex').setText(product['buttonInfo'] ?? '');
      if (product['buttonInfo'] == 'Teklif' || product['buttonInfo'] == 'B.sipariş') {
        sheet.getRangeByName('G$rowIndex').setText(product['Sipariş Numarası']?.toString() ?? '');
      }
    }

    // Dosya yolu ve ismi
    try {
      final output = await getExternalStorageDirectory();
      final path = '${output!.path}/islem_adi_${processName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File(path);

      // Dosya oluşturuluyor
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      await file.writeAsBytes(bytes, flush: true);

      // Dosya oluşturulduğunu doğrulamak için konsola yazdır
      if (await file.exists()) {
        print('Excel dosyası oluşturuldu: $path');
        final result = await OpenFile.open(file.path);
        print(result.message);
      } else {
        print('Excel dosyası oluşturulamadı.');
      }
    } catch (e) {
      print('Excel dosyası oluşturulurken hata oluştu: $e');
    }
  }
}
