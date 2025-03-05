import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String label;
  final Function()? onTap;
  const MyButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        //alignment: Alignment.center,
        width: 120,
        height: 50,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red,
              Colors.black,
            ],
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(20),
          ),
        ),

        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
