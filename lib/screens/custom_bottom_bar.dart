import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomBottomBar extends StatelessWidget {
  const CustomBottomBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: colorTheme3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10), // Dikey padding'i ekran boyutuna göre ayarla
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/home');
                  },
                  child: const FittedBox(
                    child: Text('ANASAYFA'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTheme3,
                    foregroundColor: colorTheme5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12), // Yükseklik ayarlamak için padding
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/faturala');
                  },
                  child: const FittedBox(
                    child: Text('FATURALA'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTheme3,
                    foregroundColor: colorTheme5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12), // Yükseklik ayarlamak için padding
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/customers');
                  },
                  child: const FittedBox(
                    child: Text('MÜŞTERİLER'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTheme3,
                    foregroundColor: colorTheme5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12), // Yükseklik ayarlamak için padding
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
