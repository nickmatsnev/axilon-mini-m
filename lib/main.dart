// lib/main.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/permissions_service.dart';
import 'providers/auth_provider.dart';
import 'providers/call_logging_provider.dart';
import 'providers/translation_provider.dart';
import 'utils/call_listener.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/ussd_setup_page.dart';
import 'pages/main_page.dart';
import 'pages/profile_page.dart';
import 'pages/select_assistant_page.dart';
import 'pages/calls_logs_page.dart';
import 'pages/chat_page.dart';
import 'pages/admin_page.dart';
import 'pages/create_scenario_page.dart';
import 'pages/scenario_chat_page.dart';
import 'pages/scenarios_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'pages/tasks_page.dart';

import 'services/notification_service.dart';

import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

// Этот метод будет вызван при получении FCM-сообщения, когда приложение в фоне или закрыто
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Убедимся, что Firebase инициализирован
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('🔔 Handling background message: ${message.messageId}');
}

Future<void> initFCM(BuildContext context) async {
  // 1) Запросим у пользователя права (iOS > 13, Android 13+)
  NotificationSettings settings =
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  debugPrint('User granted permission: ${settings.authorizationStatus}');

  // 2) Явно дождёмся APNs токена (только для iOS)
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    debugPrint('APNs token (iOS): $apnsToken');
    // Если apnsToken == null, возможно, iOS ещё не зарегистрировался → можно повторить попытку или сообщить пользователю.
  }

  // 3) Получим FCM токен
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM token: $fcmToken');

  if (fcmToken != null) {
    // 4) Отправим FCM token на ваш бэкенд
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final bearerToken = authProvider.token;
        final response = await http.post(
          Uri.parse(
              'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/set-fcm-token'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'fcm_token': fcmToken,
            'userId': authProvider.user?['user_id'],
          }),
        );
        if (authProvider.user?['user_id'] != null) {
          NotificationService().initialize(authProvider.user!['user_id']);
        }
        if (response.statusCode == 200) {
          debugPrint('✅ FCM token сохранён на сервере');
        } else {
          debugPrint(
              '❌ Ошибка сохранения FCM token: ${response.statusCode} → ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ Исключение при сохранении FCM token: $e');
      }
    }
  }

  // 5) Слушаем обновление токена (например, когда пользователь переустановил приложение или сбросил уведомления)
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint('🔄 FCM token refreshed: $newToken');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final bearerToken = authProvider.token;
        await http.post(
          Uri.parse(
              'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/set-fcm-token'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'fcm_token': newToken,
            'userId': authProvider.user?['user_id'],
          }),
        );
      } catch (e) {
        debugPrint('Ошибка обновления FCM token: $e');
      }
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Инициализируем Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) Устанавливаем Background-handler (приложение закрыто или в фоне)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3) Сразу попросим все нужные права (запросы в Android и iOS)
  await PermissionsService().requestAllPermissions();

  // 4) Загружаем существующую сессию (если был сохранён токен)
  final authProvider = AuthProvider();
  await authProvider.loadSession();

  // 5) Загружаем язык и т.д.
  final translationProvider = TranslationProvider();
  final userLang = authProvider.user?['lang'] as String? ?? 'ru';
  await translationProvider.loadLanguage(userLang);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TranslationProvider>.value(
            value: translationProvider),
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
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Ждём, пока дерево виджетов построено, потом инициализируем FCM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initFCM(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Запускаем слушатель звонков (см. ваш CallListener)
    CallListener.startListening(context);

    // Обработчик, если приложение было открыто кликом по пушу
    void handleMessage(RemoteMessage message) {
      debugPrint('OnMessageOpenedApp: ${message.data}');

      if (message.data['type'] == 'task') {
        Navigator.pushNamed(context, '/scenarios');
      } else if (message.data['type'] == 'call') {
        Navigator.pushNamed(context, '/logs');
      }
    }

    Future<void> setupInteractedMessage() async {
      RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        handleMessage(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    }

    // Обработка «app opened from terminated state by push»
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
              return const MainPage();
            }
          },
        ),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/choice': (context) => const SelectAssistantPage(),
        '/logs': (context) => const CallsLogsPage(),
        '/chat': (context) => const ChatPage(),
        '/ussd': (context) => const UssdSetupPage(),
        '/admin-prompts': (context) => const AdminPanelPage(),
        '/stats': (context) => const StatsPage(),
        '/main': (context) => const MainPage(),
        '/settings': (context) => const SettingsPage(),
        '/create-scenario': (context) => const CreateScenarioPage(),
        '/create-scenario-chat': (context) => const ScenarioChatPage(),
        '/scenarios': (context) => const ScenariosPage(),
      },
    );
  }
}
