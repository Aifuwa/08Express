// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW: For fetching Product data

import 'package:eight_express/firebase_options.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/providers/cart_provider.dart';
import 'package:eight_express/providers/category_provider.dart';
import 'package:eight_express/providers/product_provider.dart';
import 'package:eight_express/services/order_service.dart';

import 'package:eight_express/screens/auth_screen.dart';
import 'package:eight_express/screens/home_screen.dart';
import 'package:eight_express/screens/splash_screen.dart';
import 'package:eight_express/screens/categories_screen.dart';
// YOUR ACTUAL SCREEN IMPORTS:
import 'package:eight_express/screens/my_orders_screen.dart'; // Corrected path and class name
import 'package:eight_express/screens/product_detail_screen.dart'; // Corrected path
import 'package:eight_express/models/product.dart'; // Needed to pass to ProductDetailScreen


// --- GLOBAL NAVIGATION KEY ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// -----------------------------

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// This handler runs when the app is in the background or terminated
@pragma('vm:entry-point') // Required for background message handler in Flutter 3.0+
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");

  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- LOCAL NOTIFICATION INITIALIZATION ---
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Your app icon
  
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
      print('Notification tapped! Payload: ${response.payload}');
      if (response.payload != null && navigatorKey.currentState != null) {
        // Parse the payload. Assume it's a JSON string or a simple screen name.
        // For product_detail, we expect "product_detail/<productId>"
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
  // ----------------------------------------

  // --- FIREBASE MESSAGING SETUP ---
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  String? token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token");

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
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
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // Ensure 'screen' and 'productId' (if applicable) are in message.data from FCM
        payload: message.data['screen'] ?? 'default_payload', 
      );
    }
  });

  // Handle interaction when the app is in the background or terminated (opened by tapping a notification)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
    if (navigatorKey.currentState != null) {
      await _handleNotificationNavigation(message.data['screen'], message.data);
    }
  });

  // Handle initial message (when the app is opened from a terminated state by tapping a notification)
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('App opened from terminated state by notification!');
    print('Initial Message data: ${initialMessage.data}');
    if (navigatorKey.currentState != null) {
      await _handleNotificationNavigation(initialMessage.data['screen'], initialMessage.data);
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

// --- NAVIGATION HANDLER FUNCTION ---
// Now an async function because we might need to fetch data from Firestore
Future<void> _handleNotificationNavigation(String? screen, [Map<String, dynamic>? data]) async {
  if (screen == null || navigatorKey.currentState == null) {
    print('Navigation screen is null or navigatorKey not available.');
    return;
  }

  print('Attempting to navigate to screen: $screen with data: $data');

  // Important: Use pushNamedAndRemoveUntil for deep links to clear the stack
  // and ensure a clean navigation flow from a notification.

  // Special handling for ProductDetailScreen because it requires a Product object
  if (screen == 'product_detail' && data != null && data['productId'] != null) {
    final String productId = data['productId'];
    try {
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (productDoc.exists) {
        final product = Product.fromFirestore(productDoc);
        // Push ProductDetailScreen directly using MaterialPageRoute as it needs a Product object
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
          (Route<dynamic> route) => false, // Clear all previous routes
        );
      } else {
        print('Product with ID $productId not found.');
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      print('Error fetching product for notification: $e');
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
    }
  } else {
    // For other screens that don't need special object fetching,
    // we can use named routes directly.
    String routeName;
    switch (screen) {
      case 'home':
        routeName = '/home';
        break;
      case 'my_orders': // Matches your MyOrdersScreen path
        routeName = '/my_orders';
        break;
      case 'categories':
        routeName = '/categories';
        break;
      // Add more cases for other screens as needed
      default:
        print('Unknown screen for navigation: $screen. Defaulting to home.');
        routeName = '/home';
        break;
    }
    
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false, // Clears all previous routes
    );
  }
}
// -----------------------------------


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
        navigatorKey: navigatorKey, // CRUCIAL
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.deepOrange,
          ).copyWith(
            secondary: Colors.amber,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromRGBO(57, 64, 83, 1),
            foregroundColor: Colors.white,
          ),
        ),
        // Define your named routes here
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/home': (context) => const HomeScreen(),
          '/splash': (context) => const SplashScreen(),
          '/categories': (context) => const CategoriesScreen(),
          
          // Your actual screens:
          // MyOrdersScreen does not take constructor arguments
          '/my_orders': (context) => const MyOrdersScreen(), 
          
          // ProductDetailScreen needs a 'Product' object,
          // so it cannot be directly instantiated via a named route this way.
          // We handle its navigation in _handleNotificationNavigation with MaterialPageRoute.
          // If you ever want to navigate to ProductDetailScreen via named route *from within the app*,
          // you'd need to pass the Product object using `arguments` and retrieve it there,
          // or modify ProductDetailScreen to fetch the product by ID.
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, userSnapshot) {
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