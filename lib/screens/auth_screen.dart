import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/constants/legal_texts.dart';
import 'package:eight_express/widgets/custom_loader.dart';
import 'package:eight_express/screens/home_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _bgAnimController;
  
  // Flag to prevent event conflict between UserCreated and SignedIn
  bool _justRegistered = false; 

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    super.dispose();
  }

  // --- GUEST ENTRY LOGIC ---
  Future<void> _handleGuestEntry() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    
    // 1. Start transition overlay
    userProv.startLoginTransition();
    
    // 2. Set provider to Guest Mode
    userProv.enterGuestMode();

    // 3. Small delay for smooth visual transition
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const HomeScreen(isNewUser: false)),
      );
    }
  }

  // --- TRANSITION LOGIC (FOR LOGIN/REGISTER) ---
  Future<void> _triggerTransition(bool isNew) async {
    if (!mounted) return;
    
    final userProv = Provider.of<UserProvider>(context, listen: false);
    
    // 1. Start the blurred loading overlay
    userProv.startLoginTransition();

    // 2. WAIT for Profile to actually load from Firestore
    int retries = 0;
    while (!userProv.isProfileLoaded && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }

    // 3. Navigate only after data is ready
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (_) => HomeScreen(isNewUser: isNew),
        ),
      );
    }
  }

  // --- LEGAL MODAL HELPER ---
  void _showLegalModal(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            width: 40, 
            height: 5, 
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(height: 1.6, color: Colors.black87)))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            child: const Text("Close"),
          )
        ]),
      ),
    );
  }

  // --- FLOATING ICON HELPER ---
  Widget _buildFloatingIcon(IconData icon, double top, double left, double speed) {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (ctx, child) {
        double angle = _bgAnimController.value * 2 * math.pi;
        return Positioned(
          top: top + (math.sin(angle * speed) * 15),
          left: left + (math.cos(angle * speed) * 15),
          child: Icon(icon, color: Colors.white.withOpacity(0.15), size: 40),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFE7F2D);
    const Color darkBlue = Color(0xFF0D47A1);
    const Color midBlue = Color(0xFF1976D2);
    const Color lightBlue = Color(0xFF42A5F5);

    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardPadding > 0;
    final userProv = Provider.of<UserProvider>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. MAIN FIREBASE AUTH UI
          Theme(
            data: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: orange, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
            child: SignInScreen(
              providers: [
                EmailAuthProvider(), 
                PhoneAuthProvider(),
              ],
              headerMaxExtent: isKeyboardOpen ? 120 : 230,
              headerBuilder: (context, constraints, shrinkOffset) {
                return Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [darkBlue, midBlue, lightBlue],
                      stops: [0.1, 0.6, 1.0],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isKeyboardOpen) ...[
                        _buildFloatingIcon(Icons.local_shipping_outlined, 30, 40, 1.0),
                        _buildFloatingIcon(Icons.shopping_bag_outlined, 100, 280, 0.7),
                      ],
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_rounded, size: isKeyboardOpen ? 40 : 55, color: Colors.white),
                          if (!isKeyboardOpen) ...[
                            const SizedBox(height: 10),
                            const Text(
                              "08Express", 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 36, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
              footerBuilder: (context, action) {
                return Padding(
                  padding: const EdgeInsets.only(top: 25, bottom: 10),
                  child: Column(
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black45, fontSize: 11.5, height: 1.5),
                          children: [
                            const TextSpan(text: "By continuing, you agree to our "),
                            _linkSpan("Terms", () => _showLegalModal("Terms & Conditions", LegalTexts.termsAndConditions)),
                            const TextSpan(text: ", "),
                            _linkSpan("Privacy", () => _showLegalModal("Privacy Policy", LegalTexts.privacyPolicy)),
                            const TextSpan(text: " and "),
                            _linkSpan("Refund Policy", () => _showLegalModal("Refund Policy", LegalTexts.refundPolicy)),
                          ],
                        ),
                      ),
                      // --- GUEST BUTTON FIXED HERE ---
                      if (!isKeyboardOpen && action == AuthAction.signIn) ...[
                        const SizedBox(height: 15),
                        TextButton(
                          onPressed: _handleGuestEntry, // Calls the navigation logic
                          child: const Text(
                            "Continue as Guest", 
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              actions: [
                // 1. New User Registration
                AuthStateChangeAction<UserCreated>((context, state) async {
                  _justRegistered = true; 
                  final user = state.credential.user;
                  if (user != null) {
                    await userProv.createInitialUserDocument(user);
                    if (mounted) await _triggerTransition(true); 
                  }
                }),

                // 2. Existing User Sign In
                AuthStateChangeAction<SignedIn>((context, state) async {
                  if (_justRegistered) return;
                  if (mounted) await _triggerTransition(false);
                }),

                // 3. Forgot Password Navigation
                ForgotPasswordAction((context, email) {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => ForgotPasswordScreen(
                        email: email,
                        headerMaxExtent: 200,
                        headerBuilder: (context, constraints, shrinkOffset) {
                          return Container(
                            color: darkBlue,
                            child: const Center(
                              child: Icon(Icons.lock_reset, size: 80, color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),

                // 4. Phone Auth: Handle SMS Sent
                AuthStateChangeAction((context, state) {
                  if (state is SMSCodeSent) {
                    final dynamic dynamicState = state;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SMSCodeInputScreen(
                          flowKey: dynamicState.flowKey, 
                          actions: [
                            AuthStateChangeAction<SignedIn>((context, state) {
                              _triggerTransition(false);
                            }),
                          ],
                        ),
                      ),
                    );
                  }
                }),
              ],
            ),
          ),

          // 2. PREMIUM TRANSITION OVERLAY
          if (userProv.isTransitioning)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.white.withOpacity(0.85),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CustomLoader(size: 90),
                      const SizedBox(height: 25),
                      Text(
                        "Securing your shopping session...", 
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: darkBlue.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 8),
                      const Text("Preparing your 08Express experience", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TextSpan _linkSpan(String text, VoidCallback onTap) {
    return TextSpan(
      text: text,
      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }
}