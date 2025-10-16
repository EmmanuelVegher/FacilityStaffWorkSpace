import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:service_delivery_workspace/screens/forgot_password_page.dart';
import 'package:service_delivery_workspace/screens/loading_screen.dart';

// <<<--- ADD THIS IMPORT (As in original code)


// --- Helper Classes for Custom Shapes (Keep these as they were) ---

class TopWaveClipper extends CustomClipper<Path> {
  // ... (no changes needed here)
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.6); // Start point
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.2, size.height - 30.0);
    path.quadraticBezierTo(
        firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint =
    Offset(size.width - (size.width / 3.2), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0); // Go to top right
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class GoldWaveClipper extends CustomClipper<Path> {
  // ... (no changes needed here)
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.75); // Start
    var controlPoint1 = Offset(size.width * 0.25, size.height);
    var endPoint1 = Offset(size.width * 0.45, size.height - 50);
    path.quadraticBezierTo(
        controlPoint1.dx, controlPoint1.dy, endPoint1.dx, endPoint1.dy);

    var controlPoint2 = Offset(size.width * 0.75, size.height - 130);
    var endPoint2 = Offset(size.width, size.height - 80);
    path.quadraticBezierTo(
        controlPoint2.dx, controlPoint2.dy, endPoint2.dx, endPoint2.dy);

    path.lineTo(size.width, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class FooterWaveClipper extends CustomClipper<Path> {
  // ... (no changes needed here)
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(size.width * 0.1, size.height); // Start at bottom
    path.lineTo(0, size.height);
    path.lineTo(0, size.height * 0.3);

    var firstControlPoint = Offset(size.width * 0.4, 0);
    var firstEndPoint = Offset(size.width * 0.7, size.height * 0.4);
    path.quadraticBezierTo(
        firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint = Offset(size.width, size.height * 0.6);
    var secondEndPoint = Offset(size.width, size.height);
    path.quadraticBezierTo(
        secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


// --- REWRITTEN Main Login Page Widget ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // --- State and Controllers (No changes needed) ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  // --- Authentication Methods (No changes needed) ---
  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoadingScreen()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message ?? "An unknown error occurred.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // ... (logic is the same)
  }

  // --- Constants (No changes needed) ---
  static const Color maroonColor = Color(0xFF5C1A2E);
  static const Color goldColor = Color(0xFFD4A03C);
  static const Color darkMaroonButtonColor = Color(0xFF4a1021);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Use a LayoutBuilder to check the screen width at the top level
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double breakpoint = 768.0;
          final bool isNarrow = constraints.maxWidth < breakpoint;

          return Stack(
            children: [
              // Main content area
              Positioned.fill(
                child: SingleChildScrollView(
                  // Select the layout based on the screen width
                  child: isNarrow
                      ? _buildNarrowLayout(context)
                      : _buildWideLayout(context),
                ),
              ),

              // Conditionally add Header shapes ONLY for wide screens
              if (!isNarrow)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 250,
                    child: Stack(
                      children: [
                        _buildHeaderShape(clipper: GoldWaveClipper(), color: goldColor, height: 200, hasShadow: true),
                        _buildHeaderShape(clipper: TopWaveClipper(), color: maroonColor, height: 180),
                      ],
                    ),
                  ),
                ),

              // Conditionally add Footer shape ONLY for wide screens
              if (!isNarrow)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: ClipPath(
                    clipper: FooterWaveClipper(),
                    child: Container(
                      width: 450,
                      height: 220,
                      color: maroonColor,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildNarrowLayout(BuildContext context) {
    // Get viewport height to ensure content can be centered vertically
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: screenHeight, // Ensure the column can fill the screen
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center the content
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/image/service_delivery1.png',
              height: 120,
              semanticLabel: 'Caritas Nigeria Service Delivery Logo',
            ),
            const SizedBox(height: 32),
            _buildTextField(controller: _emailController, hintText: 'Email'),
            const SizedBox(height: 16),
            _buildPasswordField(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                child: Text('Forgot Password?', style: TextStyle(color: Colors.grey.shade800)),
              ),
            ),
            const SizedBox(height: 16),
            _buildLoginButton(
              text: 'Login',
              color: Colors.grey.shade700,
              onPressed: _isLoading ? null : _signIn,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('or', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            _buildLoginButton(
              text: 'Sign in with Google',
              color: darkMaroonButtonColor,
              onPressed: _isLoading ? null : _signInWithGoogle,
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 12),
            const Text(
              "Don't have an account? Contact the Program Team",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              'Powered By',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
            const SizedBox(height: 10),
            Image.asset('assets/image/caritaslogo1.png', height: 30),
          ],
        ),
      ),
    );
  }

  /// Builds the layout for wide screens (Tablet/Desktop).
  Widget _buildWideLayout(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.08,
        vertical: screenHeight * 0.26,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/image/service_delivery1.png',
                  height: 300,
                  semanticLabel: 'Caritas Nigeria Service Delivery Logo',
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTextField(controller: _emailController, hintText: 'Email'),
                const SizedBox(height: 20),
                _buildPasswordField(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                    child: Text('Forgot Password?', style: TextStyle(color: Colors.grey.shade800)),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLoginButton(
                  text: 'Login',
                  color: Colors.grey.shade700,
                  onPressed: _isLoading ? null : _signIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                _buildLoginButton(
                  text: 'Sign in with Google',
                  color: darkMaroonButtonColor,
                  onPressed: _isLoading ? null : _signInWithGoogle,
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 40),
                const Text(
                  "Don't have an account? Contact the Program Team",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Text(
                  'Powered By',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 15),
                Image.asset('assets/image/caritaslogo1.png', height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets for UI (with styling improvements) ---


  Widget _buildTextField({required TextEditingController controller, required String hintText}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade200, // Solid grey fill
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // No border for a cleaner look
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Password',
        filled: true,
        fillColor: Colors.white, // White fill to stand out
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300), // Light border when not focused
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: maroonColor, width: 2), // Highlight border on focus
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required String text,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        )
            : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildHeaderShape({
    required CustomClipper<Path> clipper,
    required Color color,
    required double height,
    bool hasShadow = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: hasShadow
            ? [BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5))]
            : [],
      ),
      child: ClipPath(clipper: clipper, child: Container(height: height, color: color)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}