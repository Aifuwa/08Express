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

    // 1. INITIAL LOADING (Check memory and Firebase)
    if (userProv.isLoading) {
      return const SplashScreen(key: ValueKey('splash'));
    }

    // 2. MAIN APP FLOW
    return Scaffold(
      body: Stack(
        children: [
          // This Switcher handles the "Explore" button transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: userProv.isFirstTime
                ? const OnboardingScreen(key: ValueKey('onboarding'))
                : (userProv.isAuthenticated || userProv.isGuest)
                    ? const HomeScreen(key: ValueKey('home'))
                    : const AuthScreen(key: ValueKey('auth')),
          ),

          // 3. SECURING SESSION OVERLAY (Blur effect during manual login)
          if (userProv.isTransitioning || (userProv.isAuthenticated && !userProv.isProfileLoaded))
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withOpacity(0.8),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomLoader(size: 80),
                      SizedBox(height: 25),
                      Text(
                        "Securing your session...",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                      ),
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