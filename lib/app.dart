import 'package:flutter/material.dart';
import 'package:talkie_new/screens/auth/splash.dart';
   

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: "Poppins",
        scaffoldBackgroundColor: Color(0xFFF9F9FB),
        focusColor: Color.fromARGB(255, 235, 37, 186),
      ),
      debugShowCheckedModeBanner: false,
      home: Splash(),
    );
  }
}
