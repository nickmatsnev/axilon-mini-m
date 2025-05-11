import 'dart:convert';
import 'package:axilon_mini_m/pages/admin_page.dart';
import 'package:axilon_mini_m/pages/create_scenario_page.dart';
import 'package:axilon_mini_m/pages/edit_scenario_page.dart';
import 'package:axilon_mini_m/pages/main_page.dart';
import 'package:axilon_mini_m/pages/scenario_chat_page.dart';
import 'package:axilon_mini_m/pages/scenarios_page.dart';
import 'package:axilon_mini_m/pages/settings_page.dart';
import 'package:axilon_mini_m/pages/stats_page.dart';
import 'package:axilon_mini_m/pages/tasks_page.dart';
import 'package:axilon_mini_m/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services/Providers
import 'services/permissions_service.dart';
import 'providers/auth_provider.dart';
import 'providers/call_logging_provider.dart';
import 'providers/translation_provider.dart';

// Pages
import 'pages/chat_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'pages/select_assistant_page.dart';
import 'pages/calls_logs_page.dart';
import 'pages/ussd_setup_page.dart';

// Other Utils
import 'utils/call_listener.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// HTTP
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Handling a background message: ${message.messageId}');
}

Future<void> initFCM(BuildContext context) async {
  // 1) Request permissions (iOS, web, Android 13+)
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // 2) Get the token
  String? token = await FirebaseMessaging.instance.getToken();
  print('FCM token: $token');

  if (token != null) {
    // 3) Send token to your backend
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token != null) {
      try {
        final bearerToken = authProvider.token;
        final response = await http.post(
          Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/set-fcm-token'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'fcm_token': token, 'userId': authProvider.user?['user_id']}),
        );
        if (authProvider.user?['user_id'] != null){
          NotificationService().initialize(authProvider.user?['user_id']);
        }
        if (response.statusCode == 200) {
          print("FCM token stored on server");
        } else {
          print("Error storing FCM token: ${response.statusCode} => ${response.body}");
        }
      } catch (e) {
        print("Exception while storing FCM token: $e");
      }
    }
  }

  // 4) Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('FCM token refreshed: $newToken');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final bearerToken = authProvider.token;
        await http.post(
          Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/set-fcm-token'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'fcm_token': newToken, 'userId': authProvider.user?['user_id']}),
        );
      } catch (e) {
        print("Error refreshing FCM token: $e");
      }
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set the background message handler early
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Example: Listen for messages in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message in foreground: ${message.notification?.title}, ${message.notification?.body}');
  });

  await PermissionsService().requestAllPermissions();

  // Initialize AuthProvider
  final authProvider = AuthProvider();
  await authProvider.loadSession(); // loads session from local storage

  // Initialize translation
  final translationProvider = TranslationProvider();
  print('user = ${authProvider.user}');
  final userLang = authProvider.user?['lang'] as String? ?? 'en';
  await translationProvider.loadLanguage(userLang);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TranslationProvider>.value(value: translationProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ProxyProvider<AuthProvider, CallLoggingProvider>(
          update: (context, auth, previous) {
            return CallLoggingProvider(auth.token ?? '');
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initFCM(context);
    });

  }

  @override
  Widget build(BuildContext context) {
    // Start listening for phone calls
    CallListener.startListening(context);

    void handleMessage(RemoteMessage message) {
      if (message.data['type'] == 'task') {
        Navigator.pushNamed(context, '/scenarios');
      } else if (message.data['type'] == 'call') {
        Navigator.pushNamed(context, '/logs');
      }
    }

    Future<void> setupInteractedMessage() async {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        handleMessage(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    }

    // Optionally, handle any initial interaction message
    setupInteractedMessage();

    return MaterialApp(
      title: 'Axilon',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Nunito',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.token == null) {
              return const LoginPage();
            } else {
              return MainPage();
            }
          },
        ),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => ProfilePage(),
        '/choice': (context) => SelectAssistantPage(),
        '/logs': (context) => const CallLogsPage(),
        '/chat': (context) => const ChatPage(),
        '/ussd': (context) => const UssdSetupPage(),
        '/admin-prompts': (context) => const AdminPanelPage(),
        '/stats': (ctx) => const StatsPage(),
        '/main': (ctx) => const MainPage(),
        '/settings': (ctx) => const SettingsPage(),
        '/create-scenario': (ctx) => const CreateScenarioPage(),
        '/create-scenario-chat': (ctx) => const ScenarioChatPage(),
        '/scenarios': (ctx) => const ScenariosPage(),
      },
    );
  }
}
