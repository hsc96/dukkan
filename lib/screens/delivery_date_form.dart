import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryDateForm extends StatefulWidget {
  final List<Map<String, dynamic>> quoteProducts;
  final Function(List<Map<String, dynamic>>) onSave;
  final Set<int> selectedProductIndexes;

  DeliveryDateForm({
    required this.quoteProducts,
    required this.onSave,
    required this.selectedProductIndexes,
  });

  @override
  _DeliveryDateFormState createState() => _DeliveryDateFormState();
}

class _DeliveryDateFormState extends State<DeliveryDateForm> {
  List<Map<String, dynamic>> updatedProducts = [];

  @override
  void initState() {
    super.initState();
    updatedProducts = widget.quoteProducts.where((product) {
      int productIndex = widget.quoteProducts.indexOf(product);
      return widget.selectedProductIndexes.contains(productIndex);
    }).toList();
  }

  void validateAndSave() {
    bool allProductsValid = true;

    for (var product in updatedProducts) {
      if (product['isStock'] != true && product['deliveryDate'] == null) {
        allProductsValid = false;
        break;
      }
    }

    if (allProductsValid) {
      widget.onSave(updatedProducts);
      Navigator.of(context).pop();
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Hata'),
            content: Text('Lütfen tüm ürünler için teslim bilgisi giriniz (tarih veya stok olarak işaretleyin).'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Tamam'),
              ),
            ],
          );
        },
      );
    }
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
                        onPressed: product['isStock'] == true
                            ? null
                            : () async {
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
                              ? 'Teslim Tarihi: ${DateFormat('dd MMMM yyyy').format(deliveryDate)}'
                              : 'Teslim Tarihi Seç',
                        ),
                      ),
                      Checkbox(
                        value: product['isStock'] ?? false,
                        onChanged: (bool? value) {
                          setState(() {
                            updatedProducts[productIndex]['isStock'] = value;
                            if (value == true) {
                              updatedProducts[productIndex].remove('deliveryDate');
                            }
                          });
                        },
                      ),
                      Text('Bu ürün stokta mı?'),
                    ],
                  ),
                  if (product['isStock'] == true)
                    Text('Bu ürün stokta.')
                  else if (deliveryDate != null)
                    Text('Teslim Tarihi: ${DateFormat('dd MMMM yyyy').format(deliveryDate)}'),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: validateAndSave,
          child: Text('Kaydet'),
        ),
      ],
    );
  }
}
