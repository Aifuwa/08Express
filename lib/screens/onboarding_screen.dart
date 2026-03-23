import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eight_express/providers/user_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool isLastPage = false;

  final List<Color> bgColors = [
    const Color(0xFFFFF9F5), 
    const Color(0xFFF7FAFF), 
    const Color(0xFFF6FFF8), 
  ];

  final List<Color> accentColors = [
    const Color(0xFFFE7F2D), 
    const Color(0xFF2D8EFF), 
    const Color(0xFF00C853), 
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- THE MASTER FINISH LOGIC ---
  // This ensures the screen is killed forever and navigation happens instantly
  Future<void> _handleFinishOnboarding() async {
    // 1. Save to local disk so it never shows again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    
    if (mounted) {
      // 2. Update Provider. This triggers notifyListeners() which
      // the RootGatekeeper in main.dart is watching.
      await Provider.of<UserProvider>(context, listen: false).completeIntro();
      
      // Navigation is now handled automatically by RootGatekeeper!
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: bgColors[_currentPage],
        child: Stack(
          children: [
            // 1. BACKGROUND BLOBS (Artistic Layer)
            _buildBackgroundBlobs(),

            // 2. MAIN PAGE CONTENT (Logic Layer)
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                  isLastPage = index == 2;
                });
              },
              children: [
                _buildPage(
                  lottiePath: 'lib/lottie/1.json',
                  title: "Premium\nShopping",
                  subtitle: "Experience the luxury of high-quality groceries selected specifically for your home.",
                  accentColor: accentColors[0],
                ),
                _buildPage(
                  lottiePath: 'lib/lottie/2.json',
                  title: "Lightning\nExpress",
                  subtitle: "Our express delivery system ensures your items arrives in good condition.",
                  accentColor: accentColors[1],
                ),
                _buildPage(
                  lottiePath: 'lib/lottie/3.json',
                  title: "Secure\nCheckout",
                  subtitle: "Transparent bank transfers with instant receipt verification for your peace of mind.",
                  accentColor: accentColors[2],
                ),
              ],
            ),

            // 3. BOTTOM INDICATORS & ACTION BUTTONS
            Positioned(
              bottom: 50,
              left: 30,
              right: 30,
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: ExpandingDotsEffect(
                      activeDotColor: accentColors[_currentPage],
                      dotColor: accentColors[_currentPage].withOpacity(0.15),
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                      spacing: 8,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isLastPage
                        ? _buildGetStartedButton(accentColors[2])
                        : _buildNextButton(accentColors[_currentPage]),
                  ),
                ],
              ),
            ),

            // 4. SKIP BUTTON (Always on top, always clickable)
            if (!isLastPage)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: TextButton(
                      onPressed: _handleFinishOnboarding,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        "SKIP",
                        style: TextStyle(
                          color: accentColors[_currentPage],
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBlobs() {
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 800),
          top: _currentPage == 0 ? -50 : -100,
          left: _currentPage == 1 ? -20 : -80,
          child: _Blob(color: accentColors[_currentPage].withOpacity(0.05), size: 300),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 800),
          bottom: _currentPage == 2 ? 100 : -50,
          right: _currentPage == 0 ? -50 : -100,
          child: _Blob(color: accentColors[_currentPage].withOpacity(0.08), size: 250),
        ),
      ],
    );
  }

  Widget _buildNextButton(Color color) {
    return GestureDetector(
      key: const ValueKey('nextBtn'),
      onTap: () {
        _controller.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      },
      child: Container(
        height: 70, width: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2), 
              blurRadius: 20, 
              offset: const Offset(0, 10)
            )
          ],
        ),
        child: Center(child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 28)),
      ),
    );
  }

  Widget _buildGetStartedButton(Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('getStartedBtn'),
        onTap: _handleFinishOnboarding,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 65, width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3), 
                blurRadius: 25, 
                offset: const Offset(0, 12)
              )
            ],
          ),
          child: const Center(
            child: Text(
              "EXPLORE 08EXPRESS",
              style: TextStyle(
                color: Colors.white, 
                fontSize: 16, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 1.5
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage({required String lottiePath, required String title, required String subtitle, required Color accentColor}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(lottiePath, height: 350, fit: BoxFit.contain),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              Text(
                title, 
                textAlign: TextAlign.center, 
                style: const TextStyle(
                  fontSize: 42, 
                  fontWeight: FontWeight.w900, 
                  color: Color(0xFF1A1A1A), 
                  height: 1.0, 
                  letterSpacing: -2
                )
              ),
              const SizedBox(height: 20),
              Text(
                subtitle, 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.grey.shade600, 
                  height: 1.6, 
                  fontWeight: FontWeight.w500
                )
              ),
            ],
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, 
    height: size, 
    decoration: BoxDecoration(color: color, shape: BoxShape.circle)
  );
}