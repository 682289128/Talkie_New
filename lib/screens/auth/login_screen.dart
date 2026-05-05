import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'package:talkie_new/screens/chats/contact_permission_screen.dart';
import 'package:talkie_new/screens/splash/splash_screen.dart';
import 'package:talkie_new/services/user_service.dart';
import 'package:talkie_new/services/contact_syn_service.dart';

//Email or Phone Page
class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final TextEditingController email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: Duration(milliseconds: 500),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      Register(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    final offsetAnimation = Tween<Offset>(
                      begin: Offset(0.0, 1.0), // From bottom
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Text(
              "Sign Up",
              style: TextStyle(color: Color(0xFF2563EB), fontSize: 16),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset("assets/images/logo.png", height: 70),
              SizedBox(height: 12),
              Image.asset("assets/images/logo_text.png", height: 20),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                //color: Color(0xFFF9F9FB),
                padding: EdgeInsets.all(16),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF2563EB), // Blue
                      Color(0xFFA855F7), // Purple
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sign into Talkie.",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                child: Column(
                  children: [
                    SizedBox(height: 0),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            width: 1,
                            color: Color.fromARGB(255, 122, 122, 122),
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFF2563EB)),
                        prefixIcon: Icon(Icons.phone_android),
                        labelText: "Enter email or phone number",
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Field is required";
                        }

                        final input = value.trim();

                        // Email pattern
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );

                        // Phone pattern (digits only, 7–15 numbers)
                        final phoneRegex = RegExp(r'^[0-9]{7,15}$');

                        if (emailRegex.hasMatch(input) ||
                            phoneRegex.hasMatch(input)) {
                          return null; // ✅ valid
                        } else {
                          return "Enter a valid email or phone number";
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2563EB),
                        disabledBackgroundColor:
                            Color.fromARGB(255, 218, 229, 251).withOpacity(1.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        fixedSize: Size(400, 48),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                setState(() {
                                  _isLoading = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    duration: Duration(milliseconds: 1000),
                                    content: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 10),
                                        Text(
                                          "Verified Successfully!",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                // 👇 Delay navigation slightly
                                Future.delayed(Duration(milliseconds: 200), () {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          Password(email: email.text.trim()),
                                    ),
                                  );
                                });
                              } else {
                                HapticFeedback.heavyImpact();
                              }
                            },
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFF2563EB),
                                strokeWidth: 2,
                              ))
                          : Text(
                              "Continue",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      // color: Colors.amberAccent,
                      height: 18,
                      //padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              color: Color.fromARGB(255, 122, 122, 122),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "OR",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color.fromARGB(255, 97, 97, 97),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              thickness: 1,
                              color: Color.fromARGB(255, 122, 122, 122),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFFFFF),
                        fixedSize: Size(400, 48),
                        side: BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: Image.asset(
                        "assets/images/google_logo.png",
                        height: 24,
                      ),
                      onPressed: () {},
                      label: Text(
                        "Continue with Google",
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      style: ElevatedButton.styleFrom(
                          // backgroundColor: Colors.amber,
                          ),
                      onPressed: () {},
                      child: Text(
                        "Fogot email?",
                        style: TextStyle(color: Color(0XFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 130),
              Image.asset("assets/images/logo_text.png", height: 17),
            ],
          ),
        ),
      ),
    );
  }
}

//Password
class Password extends StatefulWidget {
  final String email;
  const Password({Key? key, required this.email}) : super(key: key);

  @override
  State<Password> createState() => _PasswordState();
}

class _PasswordState extends State<Password> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final TextEditingController password = TextEditingController();
  bool _obscureText = true; // initially hide password

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: Duration(milliseconds: 500),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      Register(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    final offsetAnimation = Tween<Offset>(
                      begin: Offset(0.0, 1.0), // From bottom
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Text(
              "Sign UP",
              style: TextStyle(color: Color(0xFF2563EB), fontSize: 16),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset("assets/images/logo.png", height: 70),
              SizedBox(height: 12),
              Image.asset("assets/images/logo_text.png", height: 20),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                //color: Color(0xFFF9F9FB),
                padding: EdgeInsets.all(16),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF2563EB), // Blue
                      Color(0xFFA855F7), // Purple
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Your Password.",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(height: 0),
                    TextFormField(
                      controller: password,
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            width: 1,
                            color: Color.fromARGB(255, 122, 122, 122),
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFF2563EB)),
                        prefixIcon: Icon(Icons.lock),
                        labelText: "********",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Field Required";
                        }
                        if (value.trim().length < 6) {
                          return "Password must be atleast 6 characters long";
                        }
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return "Password must include atleast one number";
                        }
                        if (!RegExp(r"[a-z]").hasMatch(value)) {
                          return "Password must include at least one lowercase character";
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return "Password must contain atleast one uppercase character";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        fixedSize: Size(400, 48),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() {
                                  _isLoading = true;
                                });

                                try {
                                  await _authService.loginUser(
                                    widget.email,
                                    password.text.trim(),
                                  );

                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  final syncService = ContactSyncService();

                                  if (user == null) return;

                                  final doc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get();

                                  if (doc.exists) {
                                    final data = doc.data();

                                    await UserService().saveUser(
                                      data?['name'] ?? "",
                                      data?['email'] ?? "",
                                      data?['phone'] ?? "",
                                      data?['image'] ?? "",
                                    );
                                  }
                                  syncService.syncContacts();
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ContactPermissionScreen(
                                              fromLogin: true),
                                    ),
                                    (route) => false,
                                  );
                                } catch (e) {
                                  setState(() {
                                    _isLoading = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.red,
                                      content:
                                          Text("Login failed: ${e.toString()}"),
                                    ),
                                  );
                                }
                              }
                            },
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Color.fromARGB(186, 37, 100, 235),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Login",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "Fogot password?",
                        style:
                            TextStyle(color: Color(0XFF2563EB), fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 220),
              Image.asset("assets/images/logo_text.png", height: 17),
            ],
          ),
        ),
      ),
    );
  }
}
