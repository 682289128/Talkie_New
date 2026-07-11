import 'package:flutter/material.dart';

class UnknownContactCard extends StatelessWidget {
  final String phoneNumber;
  final String contactName;
  final VoidCallback? onSave;
  final VoidCallback? onDismiss;

  const UnknownContactCard({
    super.key,
    required this.phoneNumber,
    required this.contactName,
    this.onSave,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 👤 Avatar at the top
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(223, 221, 221, 221),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 80,
            ),
          ),

          const SizedBox(height: 4),

          // 📱 Phone number
          Text(
            phoneNumber,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),

          const SizedBox(height: 2),

          // 👤 Contact name
          Text(
            contactName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 10),

          // 📝 Message
          Text(
            "This number isn't saved in your contacts.\nSave it to easily recognize this person in future conversations.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          // 🔘 Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 20,
                  ),
                  label: const Text(
                    "Decline",
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(
                      color: Colors.red,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 20,
                  ),
                  label: const Text(
                    "Save",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0XFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
