import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [

            /// ✅ RIVE ANIMATION (NEW VERSION)
            SizedBox(
              height: 300,
              child: RiveWidgetBuilder(
                file:
                    'assets/2244-7248-animated-login-character.riv',
                builder: (context, state) {

                  /// Loading animation
                  if (state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  /// Error handling
                  if (state.hasError) {
                    return const Center(
                      child: Text("Failed to load animation"),
                    );
                  }

                  /// Display animation
                  return RiveWidget(
                    controller: state.controller!,
                  );
                },
              ),
            ),

            /// ✅ LOGIN FORM
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [

                  /// EMAIL FIELD
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// PASSWORD FIELD
                  TextField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}