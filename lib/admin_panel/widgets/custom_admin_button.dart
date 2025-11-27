// eight_express/lib/admin_panel/widgets/custom_admin_button.dart

import 'package:flutter/material.dart';

class CustomAdminButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const CustomAdminButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).primaryColor,
        foregroundColor: textColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 2,
      ),
      child: icon == null
          ? Text(text)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(text),
              ],
            ),
    );
  }
}