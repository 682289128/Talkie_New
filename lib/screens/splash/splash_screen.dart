import 'package:flutter/material.dart';
import 'package:talkie_new/screens/auth/signUp_screen.dart';
import 'package:talkie_new/screens/auth/login_screen.dart';

class Welcome_Talkie extends StatefulWidget {
  const Welcome_Talkie({Key? key}) : super(key: key);

  @override
  State createState() => _Welcome_Talkie_State();
}

class _Welcome_Talkie_State extends State<Welcome_Talkie> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset("assets/images/logo.png", height: 40),
            SizedBox(width: 8),
            Image.asset("assets/images/logo_text.png", height: 18),
          ],
        ),
      ),
      endDrawer: Drawer(
        //End drawer content here
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Color(0xFFF9F9FB),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                //width: double.infinity,
                height: 335,

                decoration: BoxDecoration(
                  color: Colors.red,
                  image: DecorationImage(
                    image: AssetImage("assets/images/hero_image.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                width: double.infinity,

                padding: EdgeInsets.only(left: 16, right: 16),
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
                        "Welcome to Talkie",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      Text(
                        "Where Conversations feels alive!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "A smarter way to chat, connect, and share moments instantly.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          //fontFamily: "Poppins",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2563EB),
                        fixedSize: Size(400, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: Duration(milliseconds: 500),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    Register(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  final offsetAnimation =
                                      Tween<Offset>(
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
                        "Let's get started",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 12),
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
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Welcome Page
class Register extends StatelessWidget {
  const Register({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF9F9FB),
        actions: [
          TextButton(
            onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: Duration(milliseconds: 500),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    Login(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  final offsetAnimation =
                                      Tween<Offset>(
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
              "Sign In",
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontFamily: "Poppins",
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: Color(0xFFF9F9FB),
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset("assets/images/logo.png", height: 70),
                    SizedBox(height: 12),
                    Image.asset("assets/images/logo_text.png", height: 20),
                  ],
                ),
              ),
              SizedBox(height: 30),
              Container(
                width: double.infinity,
                color: Color(0xFFF9F9FB),
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
                        "Let's Get Started",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: Color(0xFFF9F9FB),
                height: 470,
                padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  children: [
                    Text(
                      "Create Your Talkie Acoount in just a few steps",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF06060E),
                        //fontFamily: "Poppins",
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2563EB),
                        fixedSize: Size(400, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FullName()),
                        );
                      },
                      child: Text(
                        "Get Started",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: "Poppins",
                        ),
                      ),
                    ),
                    SizedBox(height: 280),
                    Image.asset("assets/images/logo_text.png", height: 17),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
