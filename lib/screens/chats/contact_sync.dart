import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<List> syncContacts(BuildContext context) async {
  var status = await Permission.contacts.status;

  if (!status.isGranted) {
    status = await Permission.contacts.request();
  }

  if (!status.isGranted) return [];

  List<Contact> contacts =
      await FlutterContacts.getContacts(withProperties: true);

  List<String> numbers = [];

  for (var c in contacts) {
    for (var p in c.phones) {
      numbers.add(p.number);
    }
  }

  final snapshot = await FirebaseFirestore.instance.collection('users').get();

  List matchedUsers = [];

  for (var doc in snapshot.docs) {
    final data = doc.data();

    String dbPhone = data['phone'] ?? '';

    if (numbers.contains(dbPhone)) {
      matchedUsers.add(data);
    }
  }

  return matchedUsers;
}
