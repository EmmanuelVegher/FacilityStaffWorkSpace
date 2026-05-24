import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_delivery_workspace/screens/forgot_password_page.dart';
import 'package:service_delivery_workspace/screens/loading_screen.dart';

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
  bool _obscurePassword = true;

  // Modern Corporate Theme Colors
  static const Color primaryMaroon = Color(0xFF5C1A2E);
  static const Color accentGold = Color(0xFFD4A03C);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF666666);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFill = Color(0xFFFAFAFA);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous error messages
    });
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
        // Show dialog instead of setting _errorMessage state for inline display
        _showErrorDialog(e.message ?? "An unknown error occurred.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Login Failed", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryMaroon)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("OK", style: GoogleFonts.poppins(color: primaryMaroon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
     // Implement Google Sign-In logic here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SelectionArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Branding Panel
        Expanded(
          flex: 4, // 40% width
          child: Container(
            decoration: const BoxDecoration(
              color: primaryMaroon,
              image: DecorationImage(
                image: AssetImage('assets/image/service_delivery1.png'),
                opacity: 0.05,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            child: Container(
               decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryMaroon,
                    const Color(0xFF2E0215), // Darker shade
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/image/service_delivery1.png',
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Service Delivery\nWorkspace",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: accentGold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Efficient. Reliable. Connected.",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Right Login Form Panel
        Expanded(
          flex: 6, // 60% width
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Image.asset(
                'assets/image/service_delivery1.png',
                height: 80,
              ),
              const SizedBox(height: 24),
              Text(
                "Welcome Back",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryMaroon,
                ),
              ),
              const SizedBox(height: 40),
              _buildLoginForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        if (MediaQuery.of(context).size.width > 900) ...[
          Text(
            "Welcome Back",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Please enter your details to sign in",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: textGrey,
            ),
          ),
          const SizedBox(height: 40),
        ],

        // Email Input
        Text(
          "Email Address",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _emailController,
          hintText: "Enter your email",
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 24),

        // Password Input
        Text(
          "Password",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _passwordController,
          hintText: "Enter your password",
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        
        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.poppins(
                color: primaryMaroon,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Login Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    "Sign In",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 24),
        
        // Divider
         Row(
          children: [
            const Expanded(child: Divider(color: inputBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("OR", style: GoogleFonts.poppins(color: textGrey, fontSize: 13)),
            ),
            const Expanded(child: Divider(color: inputBorder)),
          ],
        ),
        const SizedBox(height: 24),

        // Google Sign In
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: Icon(Icons.g_mobiledata, size: 28, color: textDark),
            label: Text(
              "Sign in with Google",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: inputBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
            ),
          ),
        ),

        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                _errorMessage,
                style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13),
                 textAlign: TextAlign.center,
              ),
            ),
          ),

        const SizedBox(height: 48),

        // Footer
        Column(
          children: [
            Text(
              "Don't have an account? Contact the Program Team",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Powered By',
                  style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: 0.5,
                  child: Image.asset('assets/image/caritaslogo1.png', height: 20),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        style: GoogleFonts.poppins(color: textDark),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.grey.shade500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
        ),
      ),
    );
  }
}