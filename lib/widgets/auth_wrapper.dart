import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProv = Provider.of<UserProvider>(context);

    // 1. Show Splash while checking Firebase status
    if (userProv.isLoading) {
      return const SplashScreen();
    }

    // 2. If logged in OR in Guest Mode, show Home
    if (userProv.isAuthenticated || userProv.isGuest) {
      return const HomeScreen();
    }

    // 3. Otherwise, show Auth
    return const AuthScreen();
  }
}