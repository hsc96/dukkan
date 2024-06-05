import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';  // Intl paketi
import 'firebase_options.dart';
import 'screens/custom_header_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/awaited_products_screen.dart';
import 'screens/faturala_screen.dart';
import 'screens/yesterday_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/iskonto_screen.dart';  // Yeni sayfa import edildi
import 'screens/ZamGuncelleScreen.dart'; // Zam Güncelle sayfası import edildi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('tr', null);  // 'tr' locale'i için initialize
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => CustomHeaderScreen(),
        '/scan': (context) => ScanScreen(),
        '/awaited_products': (context) => AwaitedProductsScreen(),
        '/faturala': (context) => FaturalaScreen(),
        '/yesterday': (context) => YesterdayScreen(),
        '/calendar': (context) => CalendarScreen(),
        '/iskonto': (context) => IskontoScreen(),  // Yeni rota eklendi
        '/zam_guncelle': (context) => ZamGuncelleScreen(), // Zam Güncelle rotası eklendi
      },
    );
  }
}
