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
import 'screens/customer_details_screen.dart';
import 'package:provider/provider.dart';
import 'providers/loading_provider.dart';
import 'screens/quotes_screen.dart';
import 'screens/products_screen.dart';
import 'screens/purchase_history_screen.dart';
import 'screens/users_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/settings_screen.dart';
import 'screens/backup_restore_screen.dart';
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

  void onCustomerSelected(Map<String, dynamic> customerData) {
    // Burada müşteri seçildiğinde yapılacak işlemleri tanımlayabilirsiniz.
    // Örneğin, müşteri bilgilerini bir listeye ekleyebilir veya ekranda gösterebilirsiniz.
    print('Seçilen müşteri: ${customerData['customerName']}, Tutar: ${customerData['amount']}');
  }
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
        home: AuthCheck(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/home': (context) => CustomHeaderScreen(),
          '/scan': (context) => ScanScreen(
            onCustomerProcessed: onCustomerSelected,
            documentId: 'current1', // Pass the appropriate document ID here
          ),

          '/awaited_products': (context) => AwaitedProductsScreen(),
          '/faturala': (context) => FaturalaScreen(),
          '/yesterday': (context) => YesterdayScreen(),
          '/calendar': (context) => CalendarScreen(),
          '/iskonto': (context) => IskontoScreen(),
          '/zam_guncelle': (context) => ZamGuncelleScreen(),
          '/customers': (context) => CustomersScreen(),
          '/customer_details': (context) => CustomerDetailsScreen(customerName: 'Example Customer'),
          '/quotes': (context) => QuotesScreen(),
          '/products': (context) => ProductsScreen(),
          '/purchase_history': (context) => PurchaseHistoryScreen(productId: '', productDetail: ''),
          '/users': (context) => UsersScreen(),
          '/user_management': (context) => UserManagementScreen(),
          '/settings': (context) => SettingsScreen(),
          '/backup_restore': (context) => BackupRestoreScreen(),
        },
      ),
    );
  }
}

class AuthCheck extends StatefulWidget {
  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isLoggedIn = prefs.getBool('remember_me') ?? false;
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn ? CustomHeaderScreen() : LoginScreen();
  }

}