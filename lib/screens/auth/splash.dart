import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkie_new/screens/splash/splash_screen.dart';
import 'package:talkie_new/screens/chats/chat_screen.dart';

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {

  @override
  void initState() {
    super.initState();
    checkUser();
  }

  void checkUser() async {
    await Future.delayed(const Duration(seconds: 2));

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // ✅ Already logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Chat()),
      );
    } else {
      // ❌ Not logged in → go to Welcome screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Welcome_Talkie()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}