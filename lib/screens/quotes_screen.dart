import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pdf_template.dart';
import 'custom_app_bar.dart';
import 'custom_bottom_bar.dart';

class QuotesScreen extends StatefulWidget {
  @override
  _QuotesScreenState createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  List<Map<String, dynamic>> quotes = [];
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    fetchQuotes();
  }

  Future<void> fetchQuotes() async {
    var querySnapshot = await FirebaseFirestore.instance.collection('quotes').get();

    setState(() {
      quotes = querySnapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'customerName': data['customerName'] ?? '',
          'quoteNumber': data['quoteNumber'] ?? '',
          'products': List<Map<String, dynamic>>.from(data['products'] ?? []),
          'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    });
  }

  List<Map<String, dynamic>> getQuotesForSelectedMonth() {
    return quotes.where((quote) {
      return DateFormat('MMMM').format(quote['date']) == selectedMonth;
    }).toList();
  }

  void saveQuoteAsPDF(int quoteIndex) async {
    var quote = quotes[quoteIndex];
    var quoteProducts = quote['products'] as List<Map<String, dynamic>>;

    double total = quoteProducts.fold(0, (sum, item) => sum + (double.tryParse(item['Toplam Fiyat'].toString()) ?? 0.0));
    double vat = total * 0.20;
    double grandTotal = total + vat;

    DateTime quoteDate;
    if (quote['date'] is Timestamp) {
      quoteDate = (quote['date'] as Timestamp).toDate();
    } else if (quote['date'] is DateTime) {
      quoteDate = quote['date'];
    } else {
      quoteDate = DateTime.now();
    }

    final pdf = await PDFTemplate.generateQuote(
      quote['customerName'],
      quoteProducts,
      total,
      vat,
      grandTotal,
      '', // Teslim tarihi
      '', // Teklif süresi
      quote['quoteNumber'], // Yeni parametreler
      quoteDate, // Yeni parametreler
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${quote['customerName']}_teklif_${quote['quoteNumber']}.pdf");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print('PDF kaydedilirken hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Tüm Teklifler'),
      body: Column(
        children: [
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(12, (index) {
                String monthName = DateFormat('MMMM').format(DateTime(0, index + 1));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedMonth = monthName;
                      });
                    },
                    child: Text(monthName),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: getQuotesForSelectedMonth().length,
              itemBuilder: (context, index) {
                var quote = getQuotesForSelectedMonth()[index];
                return ExpansionTile(
                  title: Text('Teklif No: ${quote['quoteNumber']} - ${quote['customerName']}'),
                  subtitle: Text('Tarih: ${DateFormat('dd MMMM yyyy').format(quote['date'])}'),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Kodu')),
                          DataColumn(label: Text('Detay')),
                          DataColumn(label: Text('Adet')),
                          DataColumn(label: Text('Adet Fiyatı')),
                          DataColumn(label: Text('İskonto')),
                          DataColumn(label: Text('Toplam Fiyat')),
                        ],
                        rows: (quote['products'] as List<dynamic>).map((product) {
                          return DataRow(cells: [
                            DataCell(Text(product['Kodu']?.toString() ?? '')),
                            DataCell(Text(product['Detay']?.toString() ?? '')),
                            DataCell(Text(product['Adet']?.toString() ?? '')),
                            DataCell(Text(product['Adet Fiyatı']?.toString() ?? '')),
                            DataCell(Text(product['İskonto']?.toString() ?? '')),
                            DataCell(Text(product['Toplam Fiyat']?.toString() ?? '')),
                          ]);
                        }).toList(),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            saveQuoteAsPDF(index);
                          },
                          child: Text('PDF\'e Dönüştür'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(), // Alt navigasyon çubuğunu ekleyelim
    );
  }
}
