import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/custom_header_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/awaited_products_screen.dart';
import 'screens/faturala_screen.dart';
import 'screens/yesterday_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/iskonto_screen.dart';
import 'screens/ZamGuncelleScreen.dart';
import 'screens/customers_screen.dart';
import 'screens/customer_details_screen.dart';  // Bu satırı ekliyoruz
import 'package:provider/provider.dart';
import 'providers/loading_provider.dart';
import 'screens/quotes_screen.dart';
import 'screens/products_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('tr', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoadingProvider()),
      ],
      child: MaterialApp(
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
          '/iskonto': (context) => IskontoScreen(),
          '/zam_guncelle': (context) => ZamGuncelleScreen(),
          '/customers': (context) => CustomersScreen(),
          '/customer_details': (context) => CustomerDetailsScreen(customerName: 'Example Customer'), // Bu satırı ekliyoruz
          '/quotes': (context) => QuotesScreen(),
          '/products': (context) => ProductsScreen(), // Yeni sayfa için rota
        },
      ),
    );
  }
}