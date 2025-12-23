import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/home_screen.dart';
// ADDED: Import for your custom 08 loader
import 'package:eight_express/widgets/custom_loader.dart';

enum AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _identityController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // State
  AuthMode _authMode = AuthMode.login; 
  bool _isLoading = false;
  String? _errorMessage;

  // Background Animation
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
    Timer(const Duration(seconds: 4), () {
      if(mounted) setState(() => _errorMessage = null);
    });
  }

  void _skipAsGuest() {
    Provider.of<UserProvider>(context, listen: false).enterGuestMode();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  // --- FORGOT PASSWORD DIALOG ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    // Pre-fill if they typed an email
    if(_identityController.text.contains('@')) {
      resetEmailController.text = _identityController.text;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email address to receive a password reset link.", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFE7F2D)),
            onPressed: () async {
              if(resetEmailController.text.isEmpty) return;
              try {
                 Navigator.pop(ctx); // Close dialog
                 await Provider.of<UserProvider>(context, listen: false)
                     .resetPassword(resetEmailController.text.trim());
                 if(mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Reset link sent! Check your email."), backgroundColor: Colors.green)
                   );
                 }
              } catch (e) {
                 if(mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Failed to send reset link. Check the email."), backgroundColor: Colors.red)
                   );
                 }
              }
            },
            child: const Text("Send Link", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    FocusScope.of(context).unfocus();

    setState(() { _isLoading = true; _errorMessage = null; });

    final provider = Provider.of<UserProvider>(context, listen: false);
    final identity = _identityController.text.trim();
    final pass = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_authMode == AuthMode.login) {
        // LOGIN
        await provider.login(identity, pass);
        // FIX: Manually navigate on success
        if (mounted) {
           Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        }

      } else {
        // REGISTER
        await provider.register(identity, pass, name);
        // FIX: Show verification message and Navigate
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text("Account created! Verification email sent."),
               backgroundColor: Colors.green,
               duration: Duration(seconds: 3),
             )
           );
           Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _showError("Invalid account details.");
      } else if (e.code == 'wrong-password') {
        _showError("Incorrect password.");
      } else if (e.code == 'email-already-in-use') {
        _showError("Account already exists. Please log in.");
      } else {
        _showError(e.message ?? "Auth Failed");
      }
    } catch (e) {
      _showError("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI CONSTRUCTION ---
  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const Color orange = Color(0xFFFE7F2D);
    final Color darkBlue = Colors.blue.shade900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. ANIMATED HEADER
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkBlue, Colors.blue.shade800, orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: AnimatedBuilder(
                animation: _bgAnimController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      _buildFloatingIcon(Icons.shopping_bag_outlined, 40, 40, 0),
                      _buildFloatingIcon(Icons.local_shipping_outlined, 100, 280, 1),
                      _buildFloatingIcon(Icons.card_giftcard, 220, 30, 2),
                      _buildFloatingIcon(Icons.stars_rounded, 180, 250, 3),
                      _buildFloatingIcon(Icons.shopping_cart, 60, 160, 4),
                      
                      // Skip Button
                      Positioned(
                        top: 50, right: 20,
                        child: TextButton(
                          onPressed: _skipAsGuest,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white24,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                          ),
                          child: const Row(
                            children: [
                              Text("Skip login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              SizedBox(width: 5),
                              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12)
                            ],
                          ),
                        ),
                      ),

                      // Content
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Hero(
                                tag: 'logo',
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)),
                                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 36),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "08Express",
                                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                              Text(
                                _authMode == AuthMode.login ? "Welcome Back!" : "Join Us Today",
                                style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. WHITE BOTTOM SHEET
          Positioned(
            top: size.height * 0.4, bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      _buildAuthTabs(orange),
                      const SizedBox(height: 25),
                      _buildMainForm(orange),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFloatingIcon(IconData icon, double baseX, double baseY, int index) {
    double offset = math.sin(_bgAnimController.value * 2 * math.pi + index) * 15;
    return Positioned(
      top: baseX + offset,
      right: baseY + (index % 2 == 0 ? offset : -offset),
      child: Icon(icon, color: Colors.white.withOpacity(0.1), size: 50.0 + (index * 8)),
    );
  }

  Widget _buildAuthTabs(Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _buildTabItem("Log In", AuthMode.login, color),
          _buildTabItem("Sign Up", AuthMode.register, color),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, AuthMode mode, Color color) {
    bool isActive = _authMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
           setState(() {
             _authMode = mode;
             _errorMessage = null;
           });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? color : Colors.grey[500],
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainForm(Color orange) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          if (_authMode == AuthMode.register) ...[
            _buildTextField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 20),
          ],

          _buildTextField(
            controller: _identityController,
            label: "Email or Phone Number",
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 20),

          _buildTextField(
            controller: _passwordController,
            label: "Password",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          
          if (_authMode == AuthMode.register) ...[
            const SizedBox(height: 20),
            _buildTextField(
              controller: _confirmPasswordController,
              label: "Confirm Password",
              icon: Icons.lock_reset_rounded,
              isPassword: true,
              validator: (val) {
                if (val != _passwordController.text) return "Passwords do not match";
                return null;
              },
            ),
          ],

          if (_authMode == AuthMode.login)
             Align(
               alignment: Alignment.centerRight,
               child: TextButton(
                 onPressed: _showForgotPasswordDialog,
                 child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
               ),
             ),

          const SizedBox(height: 20),

          // ERROR MESSAGE
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),

          // --- UPDATED BUTTON WITH CUSTOM LOADER ---
          _isLoading
              ? const Center(child: CustomLoader(size: 60)) // Replaced CircularProgressIndicator
              : ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: orange.withOpacity(0.5),
                  ),
                  child: Text(
                    _authMode == AuthMode.register ? "SIGN UP" : "LOG IN",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator ?? (val) => val!.isEmpty ? "Required" : null,
      ),
    );
  }
}