import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum AuthMode { login, register, phoneVerification }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers (Nullable to allow safe disposal)
  TextEditingController? _emailPhoneController;
  TextEditingController? _passwordController;
  TextEditingController? _smsCodeController;

  AuthMode _authMode = AuthMode.login;
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;
  int? _resendToken;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _emailPhoneController = TextEditingController();
    _passwordController = TextEditingController();
    _smsCodeController = TextEditingController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailPhoneController?.dispose();
    _emailPhoneController = null;
    _passwordController?.dispose();
    _passwordController = null;
    _smsCodeController?.dispose();
    _smsCodeController = null;
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isEmail(String input) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(input);
  }

  bool _isPhoneNumber(String input) {
    return RegExp(r"^\+\d{10,15}$").hasMatch(input.replaceAll(' ', ''));
  }

  Future<void> _submitAuthForm() async {
    if (_emailPhoneController == null) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String input = _emailPhoneController!.text.trim();

    if (_isEmail(input)) {
      await _submitEmailAuth(input);
    } else if (_isPhoneNumber(input)) {
      await _verifyPhoneNumber(input);
    } else {
      _showErrorSnackBar('Please enter a valid email or phone number (e.g., +234...)');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmailAuth(String email) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (_passwordController == null) return;

    try {
      User? user;
      if (_authMode == AuthMode.login) {
        user = await userProvider.signInWithEmail(email, _passwordController!.text.trim());
      } else {
        user = await userProvider.registerWithEmail(email, _passwordController!.text.trim());
      }

      if (!mounted) return;

      if (user == null) {
        _showErrorSnackBar('Authentication failed. Check credentials.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = e.message ?? 'Authentication error.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid email or password.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already registered.';
      }
      _showErrorSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      await userProvider.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        smsCodeSentCallback: (smsCodeSentId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = smsCodeSentId;
            _resendToken = resendToken;
            _authMode = AuthMode.phoneVerification;
            _isLoading = false;
            _smsCodeController?.clear();
          });
          _showErrorSnackBar('SMS code sent to $phoneNumber');
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          String message = e.message ?? 'Verification failed';
          if (e.code == 'invalid-phone-number') {
            message = 'Invalid phone format.';
          }
          _showErrorSnackBar(message);
        },
        codeAutoVerified: (credential) {
          if (!mounted) return;
          _showErrorSnackBar('Verified automatically!');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _submitSmsCode() async {
    if (_smsCodeController == null) return;
    if (_smsCodeController!.text.isEmpty || _smsCodeController!.text.length < 6) {
      _showErrorSnackBar('Enter the 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      User? user = await userProvider.signInWithSmsCode(_smsCodeController!.text.trim());
      
      if (!mounted) return;

      if (user == null) {
        _showErrorSnackBar('Verification failed. Try again.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = e.message ?? 'Error';
      if (e.code == 'invalid-verification-code') {
        message = 'Invalid SMS code.';
      } 
      _showErrorSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    // Loading State Check
    if (_emailPhoneController == null || _passwordController == null || _smsCodeController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: _authMode == AuthMode.phoneVerification
          ? AppBar(
              title: const Text('Verify Phone'),
              backgroundColor: primaryColor,
            )
          : null,
      body: Stack(
        clipBehavior: Clip.hardEdge, // Prevents watermark overflow
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.8), primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ..._buildEcommerceWatermarkIcons(primaryColor),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _authMode == AuthMode.phoneVerification
                        ? 'Verify Phone'
                        : (_authMode == AuthMode.login ? 'Welcome Back!' : 'Create Account'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          // REDUCED PADDING TO PREVENT OVERFLOW
                          padding: const EdgeInsets.all(24.0), 
                          child: _authMode == AuthMode.phoneVerification
                              ? _buildPhoneVerificationForm(context, primaryColor, accentColor)
                              : _buildAuthForm(context, primaryColor, accentColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEcommerceWatermarkIcons(Color color) {
    return [
      Positioned(
        top: 50,
        left: -30,
        child: Transform.rotate(
          angle: -0.2,
          child: Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.white.withOpacity(0.2)),
        ),
      ),
      Positioned(
        bottom: 80,
        right: -40,
        child: Transform.rotate(
          angle: 0.3,
          child: Icon(Icons.local_shipping_outlined, size: 120, color: Colors.white.withOpacity(0.25)),
        ),
      ),
      Positioned(
        top: 200,
        right: 10,
        child: Transform.rotate(
          angle: 0.1,
          child: Icon(Icons.credit_card, size: 80, color: Colors.white.withOpacity(0.2)),
        ),
      ),
      Positioned(
        bottom: 20,
        left: 20,
        child: Transform.rotate(
          angle: -0.15,
          child: Icon(Icons.shopping_bag_outlined, size: 90, color: Colors.white.withOpacity(0.22)),
        ),
      ),
    ];
  }

  Widget _buildAuthForm(BuildContext context, Color primaryColor, Color accentColor) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign In / Sign Up',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailPhoneController,
            keyboardType: TextInputType.emailAddress,
            // Changed validation logic to simple text to allow auto-detection in logic
            decoration: _inputDecoration('Email or Phone (+Code)', Icons.person),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: _inputDecoration('Password', Icons.lock),
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) {
                return 'Min 6 chars.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            CircularProgressIndicator(color: primaryColor)
          else
            Column(
              children: [
                ElevatedButton(
                  onPressed: _submitAuthForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _authMode == AuthMode.login ? 'LOGIN' : 'REGISTER',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _authMode = _authMode == AuthMode.login ? AuthMode.register : AuthMode.login;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _authMode == AuthMode.login
                        ? 'Create new account'
                        : 'I already have an account',
                    style: TextStyle(fontSize: 16, color: primaryColor),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneVerificationForm(BuildContext context, Color primaryColor, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter 6-digit code sent to ${_emailPhoneController?.text.trim() ?? "phone"}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 24),
        PinCodeTextField(
          appContext: context,
          controller: _smsCodeController,
          length: 6,
          keyboardType: TextInputType.number,
          obscureText: false,
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(8),
            fieldHeight: 45, // REDUCED HEIGHT
            fieldWidth: 35,  // REDUCED WIDTH TO PREVENT OVERFLOW
            activeFillColor: primaryColor.withOpacity(0.1),
            inactiveFillColor: Colors.grey.shade100,
            selectedFillColor: Colors.white,
            activeColor: primaryColor,
            inactiveColor: Colors.grey,
            selectedColor: accentColor,
          ),
          animationDuration: const Duration(milliseconds: 300),
          backgroundColor: Colors.transparent,
          enableActiveFill: true,
          onCompleted: (value) {
            _submitSmsCode();
          },
          onChanged: (value) {},
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          CircularProgressIndicator(color: primaryColor)
        else
          ElevatedButton(
            onPressed: _submitSmsCode,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('VERIFY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () {
            setState(() {
              _authMode = AuthMode.login;
              _smsCodeController?.clear();
              _verificationId = null;
              _errorMessage = null;
            });
          },
          child: Text('Change Number', style: TextStyle(fontSize: 16, color: primaryColor)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
    );
  }
}