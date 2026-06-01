import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ChurchExpenseApp());
}

class ChurchExpenseApp extends StatelessWidget {
  const ChurchExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: '교회 지출 관리',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          fontFamily: 'NotoSansKR',
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 18, color: Color(0xFF1F2937)),
            bodyLarge: TextStyle(fontSize: 20, color: Color(0xFF1F2937)),
            titleLarge: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              textStyle: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
