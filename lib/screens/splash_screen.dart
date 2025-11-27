import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _orangeBloomScaleAnimation; // For the orange bloom effect
  late Animation<double> _orangeBloomFadeAnimation; // For the orange bloom fade

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2, milliseconds: 500), // Total animation duration (2.5 seconds)
      vsync: this,
    );

    // Logo appears and slightly scales up
    _logoScaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic), // Logo scales up during first half
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn), // Logo fades in quickly
      ),
    );

    // Orange bloom effect
    _orangeBloomScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate( // Scales from 0 to slightly larger than container
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut), // Bloom starts after logo appears, peaks, then recedes
      ),
    );

    _orangeBloomFadeAnimation = Tween<double>(begin: 0.0, end: 0.7).animate( // Fades in and out
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeInOut), // Bloom fades in, then fades out
      ),
    );

    // Start the animation
    _controller.forward(); // We no longer add .then((_) {...}) here
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryOrange = Color(0xFFF97125); // Your brand orange
    const Color backgroundColor = Colors.white; // Option 1: Pure white

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // The orange bloom effect
                Opacity(
                  opacity: _orangeBloomFadeAnimation.value,
                  child: Transform.scale(
                    scale: _orangeBloomScaleAnimation.value,
                    child: Container(
                      width: 250, // Max size for the bloom effect
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryOrange.withOpacity(0.4), // Softer orange glow
                            blurRadius: 50.0,
                            spreadRadius: 20.0,
                          ),
                          BoxShadow(
                            color: primaryOrange.withOpacity(0.2), // Even softer outer glow
                            blurRadius: 80.0,
                            spreadRadius: 40.0,
                          ),
                        ],
                        color: primaryOrange.withOpacity(0.0), // Invisible core, just relies on shadows
                      ),
                    ),
                  ),
                ),
                // Your logo
                Opacity(
                  opacity: _logoFadeAnimation.value,
                  child: Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Image.asset(
                      'assets/logo.png', // Your specified logo path (relative to project root)
                      width: 150, // Adjust size as needed
                      height: 150, // Adjust size as needed
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}