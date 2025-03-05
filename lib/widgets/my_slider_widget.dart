import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

class MySlideAction extends StatefulWidget {
  final String text;
  final VoidCallback onSubmit;


  const MySlideAction({super.key, required this.text, required this.onSubmit});

  @override
  _MySlideActionState createState() => _MySlideActionState();
}

class _MySlideActionState extends State<MySlideAction> {
  bool _isEnabled = true;

  @override
  Widget build(BuildContext context) {
    return SlideAction(
      text: widget.text,
      // ... other SlideAction properties
      textStyle: TextStyle(
        color: Colors.black54,
        fontSize: MediaQuery.of(context).size.width/ 20,
        fontFamily: "NexaLight",
      ),
      outerColor: Colors.white,
      innerColor: Colors.red,
      onSubmit: () async { // The async is fine here if anything inside needs to be awaited.
        if (_isEnabled) {
          setState(() => _isEnabled = false);
          try {
            widget.onSubmit(); // Remove await if widget.onSubmit returns void
          } finally {
            setState(() => _isEnabled = true);
          }
        }
      },
      sliderButtonIcon: _isEnabled ? const Icon(Icons.arrow_forward_ios_rounded) : const CircularProgressIndicator(strokeWidth: 2,), // Show a loading indicator if disabled
    );
  }
}