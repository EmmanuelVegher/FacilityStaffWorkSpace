import 'package:flutter/material.dart';

class MyInputField extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController? controller;
  final Widget? widget;

  const MyInputField({
    Key? key,
    required this.title,
    required this.hint,
    this.controller,
    this.widget,
    TextInputType? keyboardType,
    String? Function(dynamic value)? validator,
    IconData? icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Aligns title to start
        //mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontFamily: "NexaBold",
              fontSize: 15,
            ),
          ),
          Container(
            height:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.13 : 0.065),

            width: MediaQuery.of(context).size.width*1,
           // margin: const EdgeInsets.only(top: 8.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: widget == null ? false : true, // Makes field editable unless there's a widget
                    autofocus: false,
                    cursorColor: Colors.grey[700],
                    controller: controller,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: "NexaBold",
                      color: Colors.grey[600],
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        fontFamily: "NexaBold",
                        color: Colors.black,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0), // Ensures text starts from the left
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                widget ?? Container(), // Uses widget or empty container if no widget provided
              ],
            ),
          ),
        ],
      ),
    );
  }
}
