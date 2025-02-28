import 'package:flutter/material.dart';

class ProgressDialog extends StatelessWidget {
  String message;
  ProgressDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    Color primary = const Color(0xffeef444c);
    return Dialog(
      //backgroundColor: primary,
      child: Container(
        margin: const EdgeInsets.all(0.0),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 1.0],
            colors: [Colors.red, Colors.black],
          ),
          //color:  Get.isDarkMode?Colors.white:Colors.red,
          //borderRadius: BorderRadius.circular(6.0)
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const SizedBox(
                width: 6.0,
              ),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(
                width: 26.0,
              ),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontFamily: "NexaBold"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
