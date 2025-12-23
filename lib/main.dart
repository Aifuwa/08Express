// lib/main.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:eight_express/firebase_options.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/providers/product_provider.dart';
import 'package:eight_express/providers/wishlist_provider.dart'; 
import 'package:eight_express/services/order_service.dart';

import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/splash_screen.dart';
import 'package:eight_express/screens/categories_screen.dart';
import 'package:eight_express/screens/my_orders_screen.dart';
import 'package:eight_express/screens/product_detail_screen.dart';
import 'package:eight_express/models/product.dart';

// --- GLOBAL NAVIGATION KEY ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- LOCAL NOTIFICATION INITIALIZATION ---
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null && navigatorKey.currentState != null) {
        final String? payload = response.payload;
        if (payload != null && payload.startsWith('product_detail/')) {
          final productId = payload.split('/').last;
          await _handleNotificationNavigation('product_detail', {'productId': productId});
        } else if (payload != null) {
          await _handleNotificationNavigation(payload);
        }
      }
    },
  );

  // --- FIREBASE MESSAGING SETUP ---
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: false, provisional: false, sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      flutterLocalNotificationsPlugin.show(
        message.notification.hashCode,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'eight_express_channel',
            'Eight Express Notifications',
            channelDescription: 'Notifications for Eight Express App',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['screen'] ?? 'default_payload', 
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    if (navigatorKey.currentState != null) {
      await _handleNotificationNavigation(message.data['screen'], message.data);
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

// --- NAVIGATION HANDLER FUNCTION ---
Future<void> _handleNotificationNavigation(String? screen, [Map<String, dynamic>? data]) async {
  if (screen == null || navigatorKey.currentState == null) return;

  if (screen == 'product_detail' && data != null && data['productId'] != null) {
    final String productId = data['productId'];
    try {
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (productDoc.exists) {
        final product = Product.fromFirestore(productDoc);
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
          (Route<dynamic> route) => false,
        );
      } else {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  } else {
    String routeName = '/home';
    switch (screen) {
      case 'my_orders': routeName = '/my_orders'; break;
      case 'categories': routeName = '/categories'; break;
    }
    navigatorKey.currentState?.pushNamedAndRemoveUntil(routeName, (route) => false);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        
        ChangeNotifierProxyProvider2<UserProvider, CartProvider, OrderService>(
          create: (context) => OrderService(
            Provider.of<UserProvider>(context, listen: false),
            Provider.of<CartProvider>(context, listen: false),
          ),
          update: (context, userProvider, cartProvider, previousOrderService) => OrderService(
            userProvider,
            cartProvider,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Eight Express',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepOrange).copyWith(secondary: Colors.amber),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromRGBO(57, 64, 83, 1),
            foregroundColor: Colors.white,
          ),
        ),
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/home': (context) => const HomeScreen(),
          '/splash': (context) => const SplashScreen(),
          '/categories': (context) => const CategoriesScreen(),
          '/my_orders': (context) => const MyOrdersScreen(), 
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, userSnapshot) {
            // --- CRUCIAL: Pointing to your Custom SplashScreen while waiting ---
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            if (userSnapshot.hasData) {
              return const HomeScreen();
            }
            return const AuthScreen();
          },
        ),
      ),
    );
  }
}