import 'package:flutter/material.dart';

class AnimatedBorderContainer extends StatelessWidget {
  final Widget child;
  final List<Color> colorGradient;
  final Animation<Alignment> animation;
  final double borderWidth;
  final BorderRadiusGeometry borderRadius;

  const AnimatedBorderContainer({
    super.key,
    required this.child,
    required this.colorGradient,
    required this.animation,
    this.borderWidth = 3.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(15.0)),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, childWidget) {
        final Alignment beginAlignment = animation.value;
        final Alignment endAlignment = Alignment(
          -animation.value.x,
          -animation.value.y,
        );

        return Stack(
          children: [
            // This is the animated gradient border
            Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
              ),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: colorGradient,
                    begin: beginAlignment,
                    end: endAlignment,
                    tileMode: TileMode.mirror,
                  ).createShader(bounds);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // The color that gets masked by the gradient
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: Colors.white, // This color is overwritten by ShaderMask
                      width: borderWidth,
                    ),
                  ),
                ),
              ),
            ),
            // This is the actual content placed inside the border
            Padding(
              padding: EdgeInsets.all(borderWidth), // Adjust content to be inside the border
              child: child,
            ),
          ],
        );
      },
      child: child, // Pass child to AnimatedBuilder to avoid rebuilding it unnecessarily
    );
  }
}