import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'database/db_helper.dart'; // 👈 IMPORT THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // 👇 ADD THIS LINE
  final dbHelper = DBHelper();
  await dbHelper.database;

  runApp(const MyApp());
}