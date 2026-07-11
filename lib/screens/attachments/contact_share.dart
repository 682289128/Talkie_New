import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactShareScreen extends StatefulWidget {
  const ContactShareScreen({
    super.key,
  });

  @override
  State<ContactShareScreen> createState() => _ContactShareScreenState();
}

class _ContactShareScreenState extends State<ContactShareScreen> {
  Contact? selectedContact;

  Future<void> pickContact() async {
    final permission = await FlutterContacts.requestPermission();

    if (!permission) {
      return;
    }

    final contact = await FlutterContacts.openExternalPick();

    if (contact != null) {
      setState(() {
        selectedContact = contact;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    pickContact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Contact",
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: selectedContact == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: const Color(0XFF2563EB),
                          child: Text(
                            selectedContact!.displayName.isNotEmpty
                                ? selectedContact!.displayName[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          selectedContact!.displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selectedContact!.phones.isNotEmpty)
                          Text(
                            selectedContact!.phones.first.number,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Later:
                      // Send contact through ChatService
                    },
                    icon: const Icon(
                      Icons.send,
                    ),
                    label: const Text(
                      "Send Contact",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0XFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}
