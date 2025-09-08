import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'therapy_home_screen.dart'; 

// Key for storing the user's last used model

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MaterialApp(
      title: 'Pose Vision AI',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF455A64), // Slate Blue
        scaffoldBackgroundColor: const Color(0xFFECEFF1), // Light Grey Background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF455A64), // Slate Blue Seed
          brightness: Brightness.light,
          primary: const Color(0xFF455A64),
          secondary: const Color(0xFF78909C),
          background: const Color(0xFFECEFF1),
          error: const Color(0xFFD32F2F),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(textTheme).apply(
          bodyColor: const Color(0xFF37474F),
          displayColor: const Color(0xFF263238),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFECEFF1), // Match background
          foregroundColor: const Color(0xFF263238),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: const Color(0xFF263238),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade100),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238)),
          dataRowColor: MaterialStateProperty.all(Colors.white),
          dividerThickness: 1,
        )
      ),
      home: const TherapyHomeScreen(), // Was VisionScreen()
    );
  }
}