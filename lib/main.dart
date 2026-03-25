import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as auth_ui;
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Firebase Config
import 'package:eight_express/firebase_options.dart';

// Providers
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/providers/product_provider.dart';

// Services
import 'package:eight_express/services/order_service.dart';
import 'package:eight_express/services/notification_service.dart';

// Screens
import 'package:eight_express/screens/splash_screen.dart';
import 'package:eight_express/screens/onboarding_screen.dart';
import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/maintenance_screen.dart';

// Global navigation key for notification handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'eight_express_high_importance_channel',
  'Eight Express Notifications',
  description: 'Channel for delivery alerts.',
  importance: Importance.max,
  playSound: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.notification != null) {
    await NotificationService().saveNotification(
      title: message.notification!.title ?? "New Notification",
      body: message.notification!.body ?? "",
      type: message.data['type'] ?? 'system',
    );
  }
}

// ==========================================
// MAIN ENTRY POINT
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. BOOTSTRAP: Load SharedPreferences BEFORE the app runs
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

  // 3. Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // 4. Remote Config with TIMEOUT
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(hours: 1),
  ));

  try {
    await remoteConfig.fetchAndActivate().timeout(const Duration(seconds: 12));
  } catch (e) {
    debugPrint("Remote Config initialization timed out: $e");
  }

  // 5. Maintenance Mode Check
  if (remoteConfig.getBool('is_under_maintenance')) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MaintenanceScreen(),
    ));
    return;
  }

  // 6. Messaging & Notifications
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  // 7. Auth UI Config
  auth_ui.FirebaseUIAuth.configureProviders([
    auth_ui.EmailAuthProvider(),
    auth_ui.PhoneAuthProvider(),
  ]);

  runApp(MyApp(isFirstTime: isFirstTime));
}

class MyApp extends StatefulWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () => _initFCM());
  }

  Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic('all_users');

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) _saveDeviceToken();
    });

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (res) {
        if (res.payload != null) _handleNav(res.payload);
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        await NotificationService().saveNotification(
          title: notification.title ?? "New Notification",
          body: notification.body ?? "",
          type: message.data['type'] ?? 'system',
        );

        flutterLocalNotificationsPlugin.show(
          notification.hashCode, 
          notification.title, 
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(channel.id, channel.name, icon: '@mipmap/launcher_icon')
          ),
          payload: message.data['screen'],
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleNav(msg.data['screen']));
  }

  Future<void> _saveDeviceToken() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'fcmToken': token,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  void _handleNav(String? screen) {
    if (screen == null || navigatorKey.currentState == null) return;
    if (screen == 'my_orders') navigatorKey.currentState?.pushNamed('/my_orders');
    if (screen == 'categories') navigatorKey.currentState?.pushNamed('/categories');
  }

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFE7F2D);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProxyProvider<UserProvider, CartProvider>(
          create: (_) => CartProvider(),
          update: (_, userProv, cartProv) => cartProv!..setUserId(userProv.appUser?.uid),
        ),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider2<UserProvider, CartProvider, OrderService>(
          create: (context) => OrderService(
            Provider.of<UserProvider>(context, listen: false), 
            Provider.of<CartProvider>(context, listen: false),
          ),
          update: (context, user, cart, prev) => OrderService(user, cart),
        ),
      ],
      child: MaterialApp(
        title: 'Eight Express',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, 
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15), 
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15), 
              borderSide: const BorderSide(color: orange, width: 2),
            ),
          ),
        ),
        home: RootGatekeeper(isFirstTime: widget.isFirstTime),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/auth': (context) => const AuthScreen(),
        },
      ),
    );
  }
}

// ==========================================
// PROFESSIONAL GATEKEEPER (REACTIVE GUEST FIX)
// ==========================================
class RootGatekeeper extends StatefulWidget {
  final bool isFirstTime;
  const RootGatekeeper({super.key, required this.isFirstTime});

  @override
  State<RootGatekeeper> createState() => _RootGatekeeperState();
}

class _RootGatekeeperState extends State<RootGatekeeper> {
  bool _isSplashFinished = false;

  @override
  void initState() {
    super.initState();
    // Splash duration
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _isSplashFinished = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show Splash Screen first
    if (!_isSplashFinished) return const SplashScreen();

    return Consumer<UserProvider>(
      builder: (context, userProv, _) {
        // 2. If it is a new user and hasn't clicked 'Explore'
        if (widget.isFirstTime && !userProv.isIntroCompleted) {
          return const OnboardingScreen();
        }

        // 3. CRITICAL GUEST CHECK: If user clicked 'Continue as Guest', go to Home
        if (userProv.isGuest) {
          return const HomeScreen();
        }

        // 4. Otherwise, check Firebase Auth Status
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            // Keep splash visual during connection logic
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            // User is logged in to Firebase
            if (authSnapshot.hasData) return const HomeScreen();

            // Default fallback: Go to Login/Auth Screen
            return const AuthScreen();
          },
        );
      },
    );
  }
}