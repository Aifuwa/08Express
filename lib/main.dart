import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as auth_ui;
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

import 'package:eight_express/firebase_options.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/providers/product_provider.dart';
import 'package:eight_express/services/order_service.dart';

import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/splash_screen.dart'; 
import 'package:eight_express/widgets/auth_wrapper.dart';
import 'package:eight_express/services/remote_config_service.dart';
import 'package:eight_express/screens/maintenance_screen.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:eight_express/services/notification_service.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: const Duration(seconds: 0),
  ));

  try {
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    debugPrint("Remote Config Fetch Failed: $e");
  }

  if (remoteConfig.getBool('is_under_maintenance')) {
    runApp(const MaterialApp(home: MaintenanceScreen(), debugShowCheckedModeBanner: false));
    return;
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  auth_ui.FirebaseUIAuth.configureProviders([
    auth_ui.EmailAuthProvider(),
    auth_ui.PhoneAuthProvider(),
  ]);
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
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
      if (user != null) {
        _saveDeviceToken();
      }
    });

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (res) {
        if (res.payload != null) _handleNav(res.payload);
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async{
      RemoteNotification? notification = message.notification;
      if (notification != null) {


         // --- ADD THIS LINE TO SAVE TO FIRESTORE ---
        await NotificationService().saveNotification(
          title: notification.title ?? "New Notification",
          body: notification.body ?? "",
          type: message.data['type'] ?? 'system',
        );



        flutterLocalNotificationsPlugin.show(
          notification.hashCode, notification.title, notification.body,
          NotificationDetails(android: AndroidNotificationDetails(channel.id, channel.name, priority: Priority.high, importance: Importance.max, icon: '@mipmap/launcher_icon')),
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
    Future.delayed(Duration.zero, () {
      String route = '/home';
      if (screen == 'my_orders') route = '/my_orders';
      if (screen == 'categories') route = '/categories';
      navigatorKey.currentState?.pushNamed(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFE7F2D);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider2<UserProvider, CartProvider, OrderService>(
          create: (context) => OrderService(Provider.of<UserProvider>(context, listen: false), Provider.of<CartProvider>(context, listen: false)),
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
            filled: true, fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: orange, width: 2)),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}