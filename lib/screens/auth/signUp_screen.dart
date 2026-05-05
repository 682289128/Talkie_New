import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import 'package:talkie_new/screens/auth/login_screen.dart';
import 'package:talkie_new/screens/chats/contact_permission_screen.dart';
import '../../database/db_helper.dart';

//FullName
class FullName extends StatefulWidget {
  const FullName({Key? key}) : super(key: key);

  @override
  State<FullName> createState() => _FullNameState();
}

class _FullNameState extends State<FullName> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController fullname = TextEditingController();

  @override
  void dispose() {
    fullname.dispose();
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
                      Login(),
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
              "Sign In",
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
                        "Full Name.",
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
                      controller: fullname,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            width: 1,
                            color: Color.fromARGB(255, 122, 122, 122),
                          ),
                        ),
                        /* focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF2563EB),
                          width: 2,
                        ),
                      ),*/
                        floatingLabelStyle: TextStyle(color: Color(0xFF2563EB)),
                        prefixIcon: Icon(Icons.person),
                        labelText: "Enter Full name",
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Field is Required";
                        }
                        if (value.length < 2) {
                          return "Name must be atlest 2 characters";
                        }
                        if (!RegExp(r"^[a-zA-Z ]+$").hasMatch(value)) {
                          return "name must contain only alphabets";
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
                          : () {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _isLoading = true);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 10),
                                        Text("Name looks Okay!",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                );

                                Future.delayed(Duration(milliseconds: 300), () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EmailAddress(
                                          fullName: fullname.text.trim()),
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
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Continue",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 280),
              Image.asset("assets/images/logo_text.png", height: 17),
            ],
          ),
        ),
      ),
    );
  }
}

//Email Adress
class EmailAddress extends StatefulWidget {
  final String fullName;
  const EmailAddress({Key? key, required this.fullName}) : super(key: key);

  @override
  State<EmailAddress> createState() => _EmailAddress_State();
}

class _EmailAddress_State extends State<EmailAddress> {
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
                      Login(),
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
              "Sign In",
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
              SizedBox(height: 16),
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
                        "Email Address.",
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
                        prefixIcon: Icon(Icons.email),
                        labelText: "username@123gmail.com",
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Field Required";
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return "Invalid Email adress";
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
                          : () {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _isLoading = true);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 10),
                                        Text("Email is valid!",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                );

                                Future.delayed(Duration(milliseconds: 300), () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PhoneNumber(
                                        fullName: widget.fullName,
                                        email: email.text.trim(),
                                      ),
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
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Continue",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 280),
              Image.asset("assets/images/logo_text.png", height: 17),
            ],
          ),
        ),
      ),
    );
  }
}

//Phone Number
class PhoneNumber extends StatefulWidget {
  final String fullName;
  final String email;
  const PhoneNumber({Key? key, required this.fullName, required this.email})
      : super(key: key);

  @override
  State<PhoneNumber> createState() => _PhoneNumber_State();
}

class _PhoneNumber_State extends State<PhoneNumber> {
  String selectedCode = "+237"; // default Cameroon
  bool _isLoading = false;

  final List<Map<String, String>> countryCodes = [
    {"name": "Cameroon", "code": "+237"},
    {"name": "Nigeria", "code": "+234"},
    {"name": "USA", "code": "+1"},
    {"name": "UK", "code": "+44"},
    {"name": "France", "code": "+33"},
  ];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phone = TextEditingController();

  @override
  void dispose() {
    phone.dispose();
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
                      Login(),
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
              "Sign In",
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
              SizedBox(height: 16),
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
                        "Phone Number.",
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
                    Row(
                      children: [
                        // 🔹 COUNTRY CODE DROPDOWN
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Color.fromARGB(255, 122, 122, 122)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButton<String>(
                            value: selectedCode,
                            underline: SizedBox(),
                            items: countryCodes.map((country) {
                              return DropdownMenuItem<String>(
                                value: country["code"],
                                child: Text("${country["code"]}"),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCode = value!;
                              });
                            },
                          ),
                        ),

                        SizedBox(width: 10),

                        // 🔹 PHONE INPUT
                        Expanded(
                          child: TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  width: 1,
                                  color: Color.fromARGB(255, 122, 122, 122),
                                ),
                              ),
                              floatingLabelStyle:
                                  TextStyle(color: Color(0xFF2563EB)),
                              prefixIcon: Icon(Icons.phone_android),
                              labelText: "Enter Phone number",
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Field is Required";
                              }
                              if (!RegExp(r'^[0-9]{7,15}$').hasMatch(value)) {
                                return "Enter a valid phone number";
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
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
                          : () {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _isLoading = true);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 10),
                                        Text("Phone number Verified!",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                );

                                Future.delayed(Duration(milliseconds: 300), () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Password(
                                        fullName: widget.fullName,
                                        email: widget.email,
                                        phone: selectedCode + phone.text.trim(),
                                      ),
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
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Continue",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 280),
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
  final String fullName;
  final String email;
  final String phone;
  const Password(
      {Key? key,
      required this.fullName,
      required this.email,
      required this.phone})
      : super(key: key);

  @override
  State<Password> createState() => _Password_State();
}

class _Password_State extends State<Password> {
  final dbHelper = DBHelper();
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
                      Login(),
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
              "Sign In",
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
              SizedBox(height: 16),
              Container(
                width: double.infinity,
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
                  child: Text(
                    "Create a Password.",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "Password must be a combination of uppercase, lowercase, and numbers.",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
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
                                setState(() => _isLoading = true);

                                try {
                                  await _authService.registerUser(
                                    name: widget.fullName,
                                    email: widget.email,
                                    password: password.text.trim(),
                                    phone: widget.phone,
                                  );

                                  //Add this line
                                  await dbHelper.insertUser({
                                    'name': widget.fullName,
                                    'email': widget.email,
                                    'phone': widget.phone,
                                    'imagePath': null, // or "" for now
                                  });

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Successful()),
                                  );
                                } catch (e) {
                                  setState(() => _isLoading = false);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text("Error: $e"),
                                    ),
                                  );
                                }
                              } else {
                                HapticFeedback.heavyImpact();
                              }
                            },
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Create account",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
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

//Contact Permission Screen

//Successful Registration Page
class Successful extends StatefulWidget {
  const Successful({Key? key}) : super(key: key);

  @override
  State<Successful> createState() => _Successful_State();
}

class _Successful_State extends State<Successful> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final TextEditingController password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset("assets/images/logo.png", height: 70),
              SizedBox(height: 12),
              Image.asset("assets/images/logo_text.png", height: 20),
              SizedBox(height: 16),
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
                        " Welcome to Talkie!!!",
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
                    Text(
                      "Your Account is ready. Let's start talking.",
                      style: TextStyle(fontSize: 18, color: Colors.green),
                    ),
                    SizedBox(height: 12),
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
                          : () {
                              setState(() => _isLoading = true);

                              Future.delayed(Duration(milliseconds: 300), () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ContactPermissionScreen(),
                                  ),
                                  (route) => false,
                                );
                              });
                            },
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Start chatting",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
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
