import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DeliveryDateForm extends StatefulWidget {
  final List<Map<String, dynamic>> quoteProducts;
  final Function(List<Map<String, dynamic>>) onSave;

  DeliveryDateForm({required this.quoteProducts, required this.onSave});

  @override
  _DeliveryDateFormState createState() => _DeliveryDateFormState();
}

class _DeliveryDateFormState extends State<DeliveryDateForm> {
  List<Map<String, dynamic>> updatedProducts = [];

  @override
  void initState() {
    super.initState();
    updatedProducts = List<Map<String, dynamic>>.from(widget.quoteProducts);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Teslim Tarihi Seçin'),
      content: SingleChildScrollView(
        child: Column(
          children: updatedProducts.map((product) {
            int productIndex = updatedProducts.indexOf(product);
            DateTime? deliveryDate = product['deliveryDate'] is Timestamp
                ? (product['deliveryDate'] as Timestamp).toDate()
                : (product['deliveryDate'] as DateTime?);

            return ListTile(
              title: Text(product['Detay'] ?? 'Detay yok'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: deliveryDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              updatedProducts[productIndex]['deliveryDate'] = pickedDate;
                            });
                          }
                        },
                        child: Text(
                          deliveryDate != null
                              ? 'Teslim Tarihi: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(deliveryDate)}'
                              : 'Teslim Tarihi Seçin',
                        ),
                      ),
                      Checkbox(
                        value: product['isStock'] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            updatedProducts[productIndex]['isStock'] = value;
                          });
                        },
                      ),
                      Text('Bu ürün stokta mı?'),
                    ],
                  ),
                  if (product['isStock'] == true)
                    Text('Bu ürün stokta mevcut.')
                  else if (deliveryDate != null)
                    Text('Teslim Tarihi: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(deliveryDate)}'),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onSave(updatedProducts);
            Navigator.of(context).pop(); // Dialog'u kapatma
          },
          child: Text('Kaydet'),
        ),
      ],
    );
  }
}
