import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showYesterdayButton;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showYesterdayButton = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(100.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: colorTheme3,
      flexibleSpace: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 24.0,
                  child: ClipOval(
                    child: Image(
                      image: AssetImage('assets/logo.png'),
                      fit: BoxFit.cover,
                      width: 48.0,
                      height: 48.0,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showYesterdayButton)
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/yesterday');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: colorTheme2,
                      foregroundColor: colorTheme5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadowColor: Colors.black,
                      elevation: 5,
                    ),
                    child: const Text(
                      'dün',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                const VerticalDivider(
                  color: Colors.black,
                  thickness: 1.0,
                  width: 20.0,
                  indent: 10.0,
                  endIndent: 10.0,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 20.0,
                  ),
                ),
                const VerticalDivider(
                  color: Colors.black,
                  thickness: 1.0,
                  width: 20.0,
                  indent: 10.0,
                  endIndent: 10.0,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/calendar');
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colorTheme2,
                    foregroundColor: colorTheme5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    shadowColor: Colors.black,
                    elevation: 5,
                  ),
                  child: const Text(
                    'takvim',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
