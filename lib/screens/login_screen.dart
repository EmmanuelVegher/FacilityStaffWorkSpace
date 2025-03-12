import 'package:attendanceappmailtool/screens/staff_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'facial_recognition/Facial_recognition_page.dart';
import 'forgot_password_page.dart';
import 'loading_screen.dart';
import 'registration_page.dart';
// Other dashboard imports if needed

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}


class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentCharIndex = 0;
  final String _title = "Facility Staff WorkSpace";
  String _animatedText = "";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward();
    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_currentCharIndex < _title.length) {
        setState(() {
          _animatedText += _title[_currentCharIndex];
          _currentCharIndex++;
        });
        _startTypewriterAnimation();
      }
    });
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // Sign in with email and password
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Navigate to your desired page (e.g., FacialRecognitionPage)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoadingScreen()),
      );
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // For web, use FirebaseAuth's signInWithPopup with GoogleAuthProvider.
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      UserCredential userCredential =
      await _auth.signInWithPopup(googleProvider);
      // Navigate to your desired page (e.g., FacialRecognitionPage)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoadingScreen()),
      );
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade600,
                Colors.black87,
                Colors.white,
                Colors.yellow.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/image/caritaslogo1.png',
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _animatedText,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to your account',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.black54,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 20),
                    _errorMessage.isNotEmpty
                        ? Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    )
                        : const SizedBox.shrink(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        // Navigate to forgot password page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.grey),
                    Text(
                      'Or',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    // Sign Up with Outlook Button
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: ElevatedButton.icon(
                    //     onPressed: () {
                    //       // Implement Outlook signup if needed
                    //     },
                    //     icon: const Icon(Icons.mail_outline, color: Colors.white),
                    //     label: const Text(
                    //       'Sign up with Outlook',
                    //       style: TextStyle(color: Colors.white),
                    //     ),
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor: Colors.blue.shade800,
                    //       padding: const EdgeInsets.symmetric(vertical: 14),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(8),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 10),
                    // Google Sign-In Button for web
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.account_circle, color: Colors.white),
                        label: const Text(
                          'Sign in with Google',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to registration page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const RegistrationPageWeb()),
                            );
                          },
                          child: const Text(
                            'Register here',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     Text(
                    //       'Need a different account?',
                    //       style: TextStyle(color: Colors.grey.shade600),
                    //     ),
                    //     TextButton(
                    //       onPressed: () {
                    //         // Navigate to alternative account registration if needed
                    //         Navigator.push(
                    //           context,
                    //           MaterialPageRoute(
                    //               builder: (context) => const RegistrationPage()),
                    //         );
                    //       },
                    //       child: const Text(
                    //         'Register here',
                    //         style: TextStyle(color: Colors.redAccent),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
