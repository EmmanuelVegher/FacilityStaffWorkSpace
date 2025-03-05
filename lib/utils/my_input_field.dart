import 'package:flutter/material.dart';

class MyInputField extends StatelessWidget {
  final String title;
  final String hint;
  final Widget widget; // This will hold the DropdownButtonFormField

  const MyInputField({super.key, required this.title, required this.hint, required this.widget});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.black87, fontSize: 15)),
        const SizedBox(height: 10),
        Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: widget, // The DropdownButtonFormField goes here
        ),
      ],
    );
  }
}