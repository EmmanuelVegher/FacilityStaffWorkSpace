import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Custom Painter for Drawing Background Lines ---
class LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1) // Very faint lines
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw a few long, angled lines across the screen
    canvas.drawLine(
      Offset(size.width * 0.1, -10),
      Offset(size.width * 0.6, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.3, size.height + 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  bool _isError = false;

  // Define colors from the image
  static const Color bgColor = Color(0xFF5C1A2E); // Dark Maroon
  static const Color cardColor = Colors.white;
  static const Color buttonColor = Color(0xFFFDD835); // Yellow
  static const Color textColor = Color(0xFF333333); // Dark Grey

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _message = 'Please enter your email address.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
      _isError = false;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        setState(() {
          _message = 'Password reset link sent! Please check your email.';
          _isError = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _message = e.message ?? 'An error occurred. Please try again.';
          _isError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // New, more dynamic background
            _buildDynamicBackground(),

            // Main content card
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 30),
                    const Text(
                      'Reset Your Password',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLabeledTextField(
                      label: 'Your email:',
                      controller: _emailController,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your email address and we will send you a link to reset your password.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                    if (_message.isNotEmpty)
                      Center(
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _isError ? Colors.red : Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Check screen width for responsive layout
    final bool isMobile = MediaQuery.of(context).size.width < 650;

    final titleWidget = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Text(
          'Forgot Password',
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    final backButton = TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text(
        'Back to Login',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (isMobile) {
      // For mobile: Stack title and button vertically
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: backButton,
          ),
        ],
      );
    } else {
      // For desktop/tablet: Show title and button in a row
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          titleWidget,
          backButton,
        ],
      );
    }
  }

  Widget _buildLabeledTextField({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.black,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2.5,
            ),
          )
              : const Text(
            'Send Reset Link',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // --- New and Improved Background Widget ---
  Widget _buildDynamicBackground() {
    return Stack(
      children: [
        // Layer 1: Subtle Radial Gradient for depth
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [
                bgColor.withOpacity(0.8),
                bgColor,
              ],
            ),
          ),
        ),

        // Layer 2: The original "patched" white circles
        _buildBackgroundShape(size: 400, top: -150, left: -100, opacity: 0.08),
        _buildBackgroundShape(size: 300, top: 100, right: -150, opacity: 0.06),
        _buildBackgroundShape(size: 500, bottom: -250, right: -120, opacity: 0.09),
        _buildBackgroundShape(size: 250, bottom: -50, left: -80, opacity: 0.07),
        _buildBackgroundShape(size: 200, bottom: 200, left: 50, opacity: 0.05),

        // Layer 3: Faint Angled Lines using CustomPainter
        Positioned.fill(
          child: CustomPaint(
            painter: LinePainter(),
          ),
        ),

        // Layer 4: Small Accent Shapes
        _buildAccentShape(icon: Icons.add, size: 12, top: 50, left: 100, opacity: 0.2),
        _buildAccentShape(icon: Icons.circle_outlined, size: 8, top: 150, right: 80, opacity: 0.15),
        _buildAccentShape(icon: Icons.close, size: 10, bottom: 100, left: 120, opacity: 0.2),
        _buildAccentShape(icon: Icons.square_outlined, size: 7, bottom: 40, right: 150, opacity: 0.1),
      ],
    );
  }

  Widget _buildBackgroundShape(
      {double? top, double? bottom, double? left, double? right, required double size, required double opacity}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildAccentShape(
      {IconData? icon, double? top, double? bottom, double? left, double? right, required double size, required double opacity}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Icon(
        icon,
        size: size,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}