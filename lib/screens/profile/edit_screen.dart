import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditFieldScreen extends StatefulWidget {
  final String title;
  final String field;
  final String initialValue;

  const EditFieldScreen({
    Key? key,
    required this.title,
    required this.field,
    required this.initialValue,
  }) : super(key: key);

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  final TextEditingController controller = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    controller.text = widget.initialValue;
  }

  Future<void> saveField() async {
    final user = _auth.currentUser;

    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      widget.field: controller.text.trim(),
    });

    Navigator.pop(context); // go back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: widget.title,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveField,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Color(0xFF2563EB),
              ),
              child: Text("Save", style:TextStyle(color: Colors.white),
            ),
            )
          ],
        ),
      ),
    );
  }
}