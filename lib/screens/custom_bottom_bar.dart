import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomBottomBar extends StatelessWidget {
  const CustomBottomBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: colorTheme3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/');
            },
            child: const Text('ANASAYFA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTheme3,
              foregroundColor: colorTheme5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/faturala');
            },
            child: const Text('FATURALA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTheme3,
              foregroundColor: colorTheme5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/awaited_products');
            },
            child: const Text('MÜŞTERİLER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTheme3,
              foregroundColor: colorTheme5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
