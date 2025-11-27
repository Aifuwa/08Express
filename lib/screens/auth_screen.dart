import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Make sure to create these dummy providers if you don't have them yet
// For example:
// class UserProvider with ChangeNotifier {
//   Future<User?> signInWithEmail(String email, String password) async {
//     await Future.delayed(Duration(seconds: 1)); // Simulate network call
//     if (email == 'test@example.com' && password == 'password') {
//       return FirebaseAuth.instance.currentUser ?? User(uid: '123', email: email, displayName: 'Test User'); // Dummy user
//     }
//     throw FirebaseAuthException(code: 'wrong-password', message: 'Invalid credentials');
//   }
//   Future<User?> registerWithEmail(String email, String password) async {
//     await Future.delayed(Duration(seconds: 1)); // Simulate network call
//     // Simulate registration success
//     return FirebaseAuth.instance.currentUser ?? User(uid: '124', email: email, displayName: 'New User');
//   }
//   Future<void> verifyPhoneNumber({
//     required String phoneNumber,
//     required Function(String, int?) smsCodeSentCallback,
//     required Function(FirebaseAuthException) verificationFailed,
//     required Function(PhoneAuthCredential) codeAutoVerified,
//     required Function(String) codeAutoRetrievalTimeout,
//   }) async {
//     await Future.delayed(Duration(seconds: 2));
//     // Simulate SMS code sent
//     smsCodeSentCallback('dummy_verification_id', null);
//   }
//   Future<User?> signInWithSmsCode(String smsCode) async {
//     await Future.delayed(Duration(seconds: 1));
//     if (smsCode == '123456') { // Dummy code
//       return FirebaseAuth.instance.currentUser ?? User(uid: '125', email: 'phone_user@example.com', displayName: 'Phone User');
//     }
//     throw FirebaseAuthException(code: 'invalid-verification-code', message: 'Invalid SMS code');
//   }
// }
//
// class User { // Dummy User class for testing purposes
//   final String uid;
//   final String? email;
//   final String? displayName;
//   User({required this.uid, this.email, this.displayName});
// }
//
// And then in main.dart:
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   // If using Firebase, uncomment these:
//   // await Firebase.initializeApp();
//   runApp(
//     ChangeNotifierProvider(
//       create: (context) => UserProvider(),
//       child: MyApp(),
//     ),
//   );
// }
import 'package:eight_express/providers/user_provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
// If you added font_awesome_flutter:
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome

enum AuthMode { login, register, phoneVerification }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

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
    _emailPhoneController.dispose();
    _passwordController.dispose();
    _smsCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _isEmail(String input) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(input);
  }

  bool _isPhoneNumber(String input) {
    // Basic phone number regex, adapt as needed for specific country codes/formats
    return RegExp(r"^\+\d{10,15}$").hasMatch(input.replaceAll(' ', ''));
  }

  Future<void> _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String input = _emailPhoneController.text.trim();

    if (_isEmail(input)) {
      await _submitEmailAuth(input);
    } else if (_isPhoneNumber(input)) {
      await _verifyPhoneNumber(input);
    } else {
      _showErrorSnackBar('Please enter a valid email address or phone number (e.g., +1XXXXXXXXXX).');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitEmailAuth(String email) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      User? user;
      if (_authMode == AuthMode.login) {
        user = await userProvider.signInWithEmail(email, _passwordController.text.trim());
      } else {
        user = await userProvider.registerWithEmail(email, _passwordController.text.trim());
      }

      if (user == null) {
        _showErrorSnackBar('Authentication failed. Please check your credentials.');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid credentials. Please try again.';
      } else if (e.code == 'email-already-in-use') {
        message = 'This email address is already in use.';
      } else if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else {
        message = e.message ?? 'An authentication error occurred.';
      }
      _showErrorSnackBar(message);
      setState(() => _errorMessage = message);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred: $e');
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      await userProvider.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        smsCodeSentCallback: (smsCodeSentId, resendToken) {
          setState(() {
            _verificationId = smsCodeSentId;
            _resendToken = resendToken;
            _authMode = AuthMode.phoneVerification;
            _isLoading = false;
            _smsCodeController.clear();
            _showErrorSnackBar('SMS code sent to $phoneNumber');
          });
        },
        verificationFailed: (e) {
          String message;
          if (e.code == 'invalid-phone-number') {
            message = 'The provided phone number is not valid.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many phone number verification attempts. Try again later.';
          } else {
            message = e.message ?? 'Phone verification failed.';
          }
          _showErrorSnackBar(message);
          setState(() {
            _errorMessage = message;
            _isLoading = false;
          });
        },
        codeAutoVerified: (credential) async {
          debugPrint("Phone number auto-verified and signed in.");
          _showErrorSnackBar('Phone number automatically verified!');
          // You might want to sign in the user here using the credential
          // final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
            _showErrorSnackBar('SMS auto-retrieval timed out. Please enter code manually.');
          });
        },
      );
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred during phone verification: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitSmsCode() async {
    if (_smsCodeController.text.isEmpty || _smsCodeController.text.length < 6) {
      _showErrorSnackBar('Please enter the 6-digit SMS code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      User? user = await userProvider.signInWithSmsCode(_smsCodeController.text.trim());
      if (user == null) {
        _showErrorSnackBar('SMS code verification failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'invalid-verification-code') {
        message = 'Invalid SMS code. Please check and try again.';
      } else {
        message = e.message ?? 'An SMS verification error occurred.';
      }
      _showErrorSnackBar(message);
      setState(() => _errorMessage = message);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred during SMS login: $e');
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    // Assuming you have a secondary color defined in your theme
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: _authMode == AuthMode.phoneVerification
          ? AppBar(
              title: const Text('Verify Phone Number'),
              backgroundColor: primaryColor,
            )
          : null,
      body: Stack( // Use Stack for background elements
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.8), primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // E-commerce Icons as Watermark
          ..._buildEcommerceWatermarkIcons(primaryColor), // Spread the list of positioned icons

          // Main content, centered and scrollable
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Your logo - make sure 'assets/logo.png' exists
                  Image.asset(
                    'assets/logo.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _authMode == AuthMode.phoneVerification
                        ? 'Verify Your Phone'
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
                          padding: const EdgeInsets.all(28.0),
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

  // --- Helper to build watermark icons ---
  // --- Helper to build watermark icons ---
// --- Helper to build watermark icons ---
  List<Widget> _buildEcommerceWatermarkIcons(Color color) {
    return [
      Positioned(
        top: 50,
        left: -30,
        child: Transform.rotate(
          angle: -0.2,
          child: Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.white.withOpacity(0.2)), // Increased opacity
        ),
      ),
      Positioned(
        bottom: 80,
        right: -40,
        child: Transform.rotate(
          angle: 0.3,
          child: Icon(Icons.local_shipping_outlined, size: 120, color: Colors.white.withOpacity(0.25)), // Increased opacity
        ),
      ),
      Positioned(
        top: 200,
        right: 10,
        child: Transform.rotate(
          angle: 0.1,
          child: Icon(Icons.credit_card, size: 80, color: Colors.white.withOpacity(0.2)), // Increased opacity
        ),
      ),
      Positioned(
        bottom: 20,
        left: 20,
        child: Transform.rotate(
          angle: -0.15,
          child: Icon(Icons.shopping_bag_outlined, size: 90, color: Colors.white.withOpacity(0.22)), // Increased opacity
        ),
      ),
       Positioned(
        top: 350,
        left: -20,
        child: Transform.rotate(
          angle: 0.4,
          child: Icon(Icons.storefront_outlined, size: 110, color: Colors.white.withOpacity(0.28)), // Increased opacity
        ),
      ),
       Positioned(
        top: 100,
        right: -20,
        child: Transform.rotate(
          angle: 0.25,
          child: Icon(Icons.redeem_outlined, size: 70, color: Colors.white.withOpacity(0.2)), // Increased opacity
        ),
      ),
      Positioned(
        bottom: 250,
        left: 50,
        child: Transform.rotate(
          angle: 0.18,
          child: Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white.withOpacity(0.18)), // Increased opacity
        ),
      ),
    ];
  }


  // --- Widget for Combined Email/Phone Input (Login/Register) ---
  Widget _buildAuthForm(BuildContext context, Color primaryColor, Color accentColor) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign In / Sign Up', // Corrected text here
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailPhoneController,
            keyboardType: _isEmail(_emailPhoneController.text.trim())
                ? TextInputType.emailAddress
                : (_isPhoneNumber(_emailPhoneController.text.trim())
                    ? TextInputType.phone
                    : TextInputType.text),
            decoration: _inputDecoration('Email / Phone Number (+CountryCode)', Icons.person),
            onChanged: (value) {
              setState(() {}); // Rebuild to update keyboard type if needed
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address or phone number.';
              }
              final input = value.trim();
              if (!_isEmail(input) && !_isPhoneNumber(input)) {
                return 'Please enter a valid email or phone number.';
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
                return 'Password must be at least 6 characters long.';
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

  // --- Widget for Phone SMS Code Verification ---
  Widget _buildPhoneVerificationForm(BuildContext context, Color primaryColor, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the 6-digit code sent to ${_emailPhoneController.text.trim()}',
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
            borderRadius: BorderRadius.circular(10),
            fieldHeight: 50,
            fieldWidth: 45,
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
          onChanged: (value) {
            // Can add real-time validation here
          },
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Please enter the full 6-digit code.';
            }
            return null;
          },
          onCompleted: (value) {
            _submitSmsCode();
          },
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
            child: const Text('VERIFY & LOGIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () {
            setState(() {
              _authMode = AuthMode.login;
              _smsCodeController.clear();
              _verificationId = null;
              _errorMessage = null;
            });
          },
          child: Text('Edit Phone Number', style: TextStyle(fontSize: 16, color: primaryColor)),
        ),
        TextButton(
          onPressed: _isLoading || _verificationId == null
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  // You might need to re-call _verifyPhoneNumber with a new forceResendingToken: _resendToken
                  // if your Firebase setup requires it for explicit resend.
                  await _verifyPhoneNumber(_emailPhoneController.text.trim());
                  setState(() => _isLoading = false);
                },
          child: Text('Resend Code', style: TextStyle(fontSize: 16, color: primaryColor)),
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