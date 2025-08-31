import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Original imports from user code that might be needed
import 'package:attendanceappmailtool/screens/forgot_password_page.dart';
import 'package:attendanceappmailtool/screens/loading_screen.dart';

// <<<--- ADD THIS IMPORT
import 'package:attendanceappmailtool/main.dart';


// --- Helper Classes for Custom Shapes ---

// Clipper for the top maroon wave
class TopWaveClipper extends CustomClipper<Path> {
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

// Clipper for the gold wave underneath
class GoldWaveClipper extends CustomClipper<Path> {
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

// Clipper for the bottom-left maroon shape
class FooterWaveClipper extends CustomClipper<Path> {
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

// --- Main Login Page Widget ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  // --- ADD THIS STATE VARIABLE ---
  bool _obscurePassword = true;

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
    setState(() => _isLoading = true);
    try {
      final googleProvider = GoogleAuthProvider();
      await _auth.signInWithPopup(googleProvider);

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoadingScreen()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? "An unknown error occurred.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  // Define colors from the image
  static const Color maroonColor = Color(0xFF5C1A2E);
  static const Color goldColor = Color(0xFFD4A03C);
  static const Color darkMaroonButtonColor = Color(0xFF4a1021);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            // Main content area
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.08,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    SizedBox(height: screenSize.height * 0.25), // Space for header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side logo and text
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/image/service_delivery1.png', // Assuming this path is correct
                                height: 400,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                        const Spacer(flex: 1),
                        // Right side login form
                        Expanded(
                          flex: 5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              _buildTextField(
                                  controller: _emailController,
                                  hintText: 'Email'),
                              const SizedBox(height: 20),
                              // --- UPDATED THIS WIDGET CALL ---
                              _buildPasswordField(), // Using a dedicated widget for the password field
                              const SizedBox(height: 30),
                              _buildLoginButton(
                                text: 'Login',
                                color: Colors.grey.shade700,
                                onPressed: _isLoading ? null : _signIn,
                                isLoading: _isLoading,
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: Colors.grey.shade800),
                                ),
                              ),
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
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Text(
                                "Don't have an account? Contact the Program Team",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(height: 20),
                              Text(
                                'Powered By',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Center(
                                child: Image.asset(
                                  'assets/image/caritaslogo1.png', // Assuming this path is correct
                                  height: 90,
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenSize.height * 0.25), // Space for footer
                  ],
                ),
              ),
            ),

            // Header shapes and content
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 250,
                child: Stack(
                  children: [
                    _buildHeaderShape(clipper: GoldWaveClipper(), color: goldColor, height: 200, hasShadow: true),
                    _buildHeaderShape(clipper: TopWaveClipper(), color: maroonColor, height: 180, child: _buildHeaderContent()),
                  ],
                ),
              ),
            ),

            // Footer shape and content
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
            )
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets for UI ---

  // Generic TextField for email
  Widget _buildTextField(
      {required TextEditingController controller,
        required String hintText}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  // --- ADDED THIS DEDICATED PASSWORD FIELD WIDGET ---
  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword, // Controlled by state
      decoration: InputDecoration(
        hintText: 'Password',
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        // Suffix icon for toggling visibility
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
          onPressed: () {
            // Toggle the state of password visibility
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
    );
  }


  Widget _buildLoginButton(
      {required String text,
        required Color color,
        required VoidCallback? onPressed,
        bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        )
            : Text(text,
            style: const TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }

  Widget _buildHeaderShape({
    required CustomClipper<Path> clipper,
    required Color color,
    required double height,
    Widget? child,
    bool hasShadow = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: hasShadow
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ]
            : [],
      ),
      child: ClipPath(
        clipper: clipper,
        child: Container(
          height: height,
          color: color,
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
