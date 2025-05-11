import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomBottomBar extends StatelessWidget {
  const CustomBottomBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return BottomAppBar(
      color: colorTheme3,
      elevation: 6,
      shape: const CircularNotchedRectangle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Row(
          children: [
            _buildNavButton(context, 'ANASAYFA', '/home', Icons.home, currentRoute),
            _buildNavButton(context, 'FATURALA', '/faturala', Icons.receipt_long, currentRoute),
            _buildNavButton(context, 'MÜŞTERİLER', '/customers', Icons.people_alt, currentRoute),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, String label, String route, IconData icon, String? currentRoute) {
    final bool isActive = currentRoute == route;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          onPressed: () {
            if (!isActive) Navigator.pushNamed(context, route);
          },
          icon: Icon(
            icon,
            size: 20,
            color: isActive ? Colors.white : colorTheme5,
          ),
          label: FittedBox(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : colorTheme5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            backgroundColor: isActive ? colorTheme5 : colorTheme3,
            foregroundColor: isActive ? Colors.white : colorTheme5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isActive ? 8 : 3,
            shadowColor: isActive ? Colors.black54 : Colors.black26,
          ),
        ),
      ),
    );
  }
}
