import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _mainController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));

    _mainController.forward();

    // Fast but smooth transition (2.5 seconds total)
    Timer(const Duration(milliseconds: 2500), () => _navigate());
  }

  void _navigate() {
    if (!mounted) return;
    User? user = FirebaseAuth.instance.currentUser;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => user != null ? const HomeScreen() : const AuthScreen()),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Orbit Center
          Center(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) => Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(200, 200), 
                  painter: _OrbitPainter(color: const Color(0xFFFE7F2D).withOpacity(0.3)),
                ),
              ),
            ),
          ),
          // 2. Logo Center
          Center(
            child: ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                  child: Image.asset('assets/logo.png', width: 100, height: 100),
                ),
              ),
            ),
          ),
          // 3. Footer
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Column(
              children: [
                const Text("08Express", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text("by 08Vic Enterprises © 2025", style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final Color color;
  _OrbitPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), 0, math.pi, false, p);
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), math.pi, math.pi/4, false, p);
  }
  @override
  bool shouldRepaint(CustomPainter old) => false;
}