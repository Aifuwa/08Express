import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/splash_screen.dart';
import 'package:eight_express/screens/onboarding_screen.dart';
import 'package:eight_express/widgets/custom_loader.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProv = Provider.of<UserProvider>(context);

    // 1. CRITICAL LOADING STATE
    // We show the Splash Screen if:
    // A. We haven't finished reading SharedPreferences yet (!isIntroCheckDone)
    // B. Firebase is still establishing the initial connection (isLoading)
    if (!userProv.isIntroCheckDone || userProv.isLoading) {
      return const SplashScreen(key: ValueKey('splash'));
    }

    // 2. DETERMINE THE MAIN CONTENT
    Widget currentScreen;
    
    if (userProv.isFirstTime) {
      // Priority 1: User has never clicked "Get Started"
      currentScreen = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (userProv.isAuthenticated || userProv.isGuest) {
      // Priority 2: User is logged in OR is browsing as Guest
      currentScreen = const HomeScreen(key: ValueKey('home'));
    } else {
      // Priority 3: Default state (Login Screen)
      currentScreen = const AuthScreen(key: ValueKey('auth'));
    }

    // 3. BUILD UI WITH TRANSITIONS & OVERLAYS
    return Scaffold(
      body: Stack(
        children: [
          // A. The Main Screen (Switches smoothly)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: currentScreen,
          ),

          // B. SECURING SESSION OVERLAY 
          // Shows when logging in manually OR when auto-login is working but Profile data isn't ready yet.
          // This prevents the Home Screen from showing "Guest" for a split second before the name loads.
          if (userProv.isTransitioning || (userProv.isAuthenticated && !userProv.isProfileLoaded))
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withOpacity(0.85),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomLoader(size: 80),
                      SizedBox(height: 25),
                      Text(
                        "Securing your session...",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF0D47A1)
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Preparing your 08Express experience",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
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
}