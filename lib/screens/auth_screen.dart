import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
// --- FIX: Hide conflicting names from core firebase_auth ---
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/constants/legal_texts.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _bgAnimController;
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE7F2D), 
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)
            ),
            child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final userProv = Provider.of<UserProvider>(context);
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. STANDARD FIREBASE UI COMPONENT
          Theme(
            data: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), 
                  borderSide: BorderSide(color: Colors.grey.shade300)
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), 
                  borderSide: const BorderSide(color: orange, width: 2)
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            child: SignInScreen(
              providers: [EmailAuthProvider()],
              headerMaxExtent: isKeyboardOpen ? 120 : 250,
              headerBuilder: (context, constraints, shrinkOffset) {
                return Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [darkBlue, Color(0xFF42A5F5)]),
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
                          const Icon(Icons.local_shipping_rounded, size: 55, color: Colors.white),
                          if (!isKeyboardOpen) 
                            const Text(
                              "08Express", 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 36, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 2
                              )
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              footerBuilder: (context, action) {
                return Padding(
                  padding: const EdgeInsets.only(top: 25, bottom: 10),
                  child: Column(children: [
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
                    if (!isKeyboardOpen && action == AuthAction.signIn) ...[
                      const SizedBox(height: 25),
                      // --- GUEST BUTTON ---
                      TextButton(
                        onPressed: () => userProv.enterGuestMode(),
                        child: const Text(
                          "CONTINUE AS GUEST", 
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 13)
                        ),
                      ),
                    ],
                  ]),
                );
              },
              actions: [
                // SIGN IN ACTION
                AuthStateChangeAction<SignedIn>((context, state) {
                  // We notify the provider to show the transition loader
                  userProv.startLoginTransition();
                  // The RootGatekeeper in main.dart watches authStateChanges()
                  // and will move to HomeScreen automatically.
                }),

                // REGISTRATION ACTION
                AuthStateChangeAction<UserCreated>((context, state) async {
                  _justRegistered = true; 
                  final user = state.credential.user;
                  if (user != null) {
                    userProv.startLoginTransition();
                    await user.sendEmailVerification();
                    await userProv.createInitialUserDocument(user);
                  }
                }),

                // FORGOT PASSWORD
                ForgotPasswordAction((context, email) {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => ForgotPasswordScreen(email: email))
                  );
                }),
              ],
            ),
          ),

          // 2. PREMIUM BLUR OVERLAY (Visible during transition)
          if (userProv.isTransitioning)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.white.withOpacity(0.8),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomLoader(size: 90),
                      SizedBox(height: 25),
                      Text(
                        "Securing your session...", 
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Preparing your 08Express experience", 
                        style: TextStyle(color: Colors.grey)
                      ),
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
      style: const TextStyle(
        color: Colors.blue, 
        fontWeight: FontWeight.bold, 
        decoration: TextDecoration.underline
      ),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }
}