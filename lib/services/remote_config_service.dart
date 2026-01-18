import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

class RemoteConfigService {
  static final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  /// Helper to safely parse JSON strings with a fallback default value
  static Map<String, dynamic> _getSafeJson(String key, Map<String, dynamic> defaultValue) {
    try {
      String raw = _rc.getString(key);
      if (raw.isEmpty) return defaultValue;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("RemoteConfig Error for key '$key': $e");
      return defaultValue;
    }
  }

  /// 1. Maintenance Mode
  static bool get isMaintenance => _rc.getBool('is_under_maintenance');

  /// 2. UI Branding (Colors, Banners)
  static Map<String, dynamic> get ui => _getSafeJson('ui_branding', {
    "primary_color": "#FE7F2D",
    "home_banner_url": "",
    "show_seasonal_banner": false,
  });

  /// 3. Promotions (Popups, Discount Badges)
  static Map<String, dynamic> get promo => _getSafeJson('promotions', {
    "show_popup": false,
    "popup_image": "",
    "popup_title": "",
    "popup_body": "",
    "show_discount_badges": false, 
    "discount_percentage": 0
  });

  /// 4. Delivery Logic
  static Map<String, dynamic> get delivery => _getSafeJson('delivery_config', {
    "standard_fee": 3000,
    "large_fee": 5000,
    "threshold_items": 50,
    "free_delivery_above": 50000
  });

  /// 5. Bank Account Details
  static Map<String, dynamic> get bank => _getSafeJson('bank_details', {
    "bank_name": "Moniepoint",
    "account_number": "5449707683",
    "account_name": "#08Vic Enterprise"
  });

  /// 6. Support Info
  static Map<String, dynamic> get support => _getSafeJson('support_contact', {
    "email": "admin@08vicenterprises.com",
    "phone": "+2348100172239",
    "whatsapp": "+2348100172239"
  });

  /// 7. App Version Control
  static Map<String, dynamic> get forceUpdate => _getSafeJson('force_update_config', {
    "min_version": "1.0.0",
    "store_url": "",
    "force_title": "Update Required",
    "force_message": "Please update to continue."
  });

  /// 8. Search Hints (Robust Parsing for String or JSON types)
  static List<String> get searchHints {
    try {
      String raw = _rc.getString('search_hints');
      
      // If Firebase returns nothing, use hardcoded defaults
      if (raw.isEmpty || raw == "[]") {
        return ["Search 'Indomie'", "Search 'Milk'", "Search 'Diapers'", "Search 'Baby Food'"];
      }

      // Try to decode the string into a list
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((item) => item.toString()).toList();
    } catch (e) {
      debugPrint("RemoteConfig searchHints parsing error: $e");
      // Fallback if the JSON is malformed
      return ["Search 'Indomie'", "Search 'Milk'", "Search 'Diapers'"];
    }
  }

  /// Helper to convert Hex String from Firebase to Flutter Color
  static Color getPrimaryColor() {
    try {
      final configUi = ui;
      String hexString = configUi['primary_color'].replaceAll('#', '');
      if (hexString.length == 6) hexString = 'FF$hexString';
      return Color(int.parse(hexString, radix: 16));
    } catch (e) {
      return const Color(0xFFFE7F2D); // Your signature orange fallback
    }
  }
}