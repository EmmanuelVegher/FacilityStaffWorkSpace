import 'package:flutter/material.dart';
//import 'package:hexcolor/hexcolor.dart';

class ThemeHelper {


  // Helper function to convert hex string to Color (moved to class level)
  static Color colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      print('Invalid hex color string: $hexString');
      return Colors.transparent; // Or a more suitable default
    }
  }


  InputDecoration textInputDecoration([
    String lableText = "",
    String hintText = "",
    IconButton? icon,
  ]) {
    return InputDecoration(
      labelText: lableText,
      hintText: hintText,
      suffixIcon: icon,
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.black38)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.black38)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.grey, width: 2.0)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0)),
    );
  }

  BoxDecoration inputBoxDecorationShaddow() {
    return BoxDecoration(boxShadow: [
      BoxShadow(
        color: Colors.brown.withOpacity(0.1),
        //Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 5),
      )
    ]);
  }

  // BoxDecoration buttonBoxDecoration(BuildContext context,
  //     [String color1 = "", String color2 = ""]) {
  //   // Get.isDarkMode?Static.PrimaryColor.withOpacity(0.4):Static.PrimaryColor..withOpacity(0.4),
  //   //Colors.white..withOpacity(0.4),
  //   Color c1 = Colors.red;
  //   Color c2 = Colors.black;
  //   if (color1.isEmpty == false) {
  //     c1 = HexColor(color1);
  //   }
  //   if (color2.isEmpty == false) {
  //     c2 = HexColor(color2);
  //   }
  //
  //   return BoxDecoration(
  //     boxShadow: const [
  //       BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 5.0)
  //     ],
  //     gradient: LinearGradient(
  //       begin: Alignment.topLeft,
  //       end: Alignment.bottomRight,
  //       stops: const [0.0, 1.0],
  //       colors: [
  //         c1,
  //         c2,
  //       ],
  //     ),
  //     color: Colors.deepPurple.shade300,
  //     borderRadius: BorderRadius.circular(30),
  //   );
  // }
  BoxDecoration buttonBoxDecoration(BuildContext context, {
    String color1 = "#FF0000", // Default red,  named parameters
    String color2 = "#000000", // Default black, named parameters
  }) {
    Color c1 = colorFromHex(color1); // Use the helper function
    Color c2 = colorFromHex(color2);

    return BoxDecoration(
      boxShadow: const [
        BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 5.0)
      ],
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 1.0],
        colors: [c1, c2],
      ),
      // color: Colors.deepPurple.shade300, // Removed - gradient handles color
      borderRadius: BorderRadius.circular(30),
    );
  }

  ButtonStyle buttonStyle() {
    return ButtonStyle(
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
      minimumSize: WidgetStateProperty.all(const Size(50, 50)),
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  AlertDialog alartDialog(String title, String content, BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.black)),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            "OK",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// class LoginFormStyle {}
