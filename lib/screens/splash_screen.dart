import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Controllers for different layers of animation to ensure smooth orchestration
  late AnimationController _mainController;     // Handles logo and footer entry
  late AnimationController _rotationController; // Handles continuous orbit rotation
  late AnimationController _pulseController;    // Handles the breathing background glow
  
  // Specific animation definitions
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowScale;
  late Animation<double> _footerOpacity;
  late Animation<double> _loadingWidth;

  @override
  void initState() {
    super.initState();

    // 1. Setup the Main Entry Controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 2. Setup the Continuous Rotation Controller (Orbits)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 3. Setup the Pulse Controller (Background breathing effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // --- DEFINE TWEENS ---

    // Logo pops in with an elastic effect
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController, 
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    // Logo fades in early
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController, 
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Background glow pulses between sizes
    _glowScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _pulseController, 
        curve: Curves.easeInOut,
      ),
    );

    // Footer text appears towards the end of the splash
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController, 
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Visual progress bar that fills up smoothly
    _loadingWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController, 
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOut),
      ),
    );

    // Trigger the entry animations
    _mainController.forward();
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _mainController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryOrange = Color(0xFFFE7F2D);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // LAYER 1: Glassmorphic Background Pulsing Glow
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _glowScale.value,
                  child: Container(
                    width: 280, height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryOrange.withOpacity(0.15), 
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // LAYER 2: Outer Orbit (Clockwise Rotation)
          Center(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(260, 260),
                    painter: _SplashOrbitPainter(
                      color: primaryOrange.withOpacity(0.1),
                      strokeWidth: 1.5,
                    ),
                  ),
                );
              },
            ),
          ),

          // LAYER 3: Inner Orbit (Counter-Clockwise Rotation)
          Center(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_rotationController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(200, 200),
                    painter: _SplashOrbitPainter(
                      color: primaryOrange.withOpacity(0.35),
                      strokeWidth: 3.5,
                    ),
                  ),
                );
              },
            ),
          ),

          // LAYER 4: The Main App Logo
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1), 
                            blurRadius: 40, 
                            offset: const Offset(0, 15),
                          )
                        ],
                      ),
                      child: Hero(
                        tag: 'appLogo', // Used for smooth transitions to Home
                        child: Image.asset(
                          'assets/logo.png', 
                          width: 115, height: 115,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // LAYER 5: Visual Loading Bar and Footer Branding
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _footerOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Smooth animated loading indicator
                  Container(
                    width: 180,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _loadingWidth,
                          builder: (context, child) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _loadingWidth.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primaryOrange.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryOrange.withOpacity(0.3),
                                    blurRadius: 5,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    "08Express", 
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.black87, 
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "by 08Vic Enterprises © 2026", 
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey.shade400, 
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
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
}

// ==========================================
// CUSTOM PAINTER FOR ORBITAL ARCS
// ==========================================
class _SplashOrbitPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SplashOrbitPainter({
    required this.color, 
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Drawing three distinct artistic segments for the orbits
    // Segment 1
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height), 
      0, 
      math.pi / 1.5, 
      false, 
      paint,
    );

    // Segment 2
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height), 
      math.pi, 
      math.pi / 4, 
      false, 
      paint,
    );

    // Segment 3
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height), 
      math.pi * 1.5, 
      math.pi / 8, 
      false, 
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}