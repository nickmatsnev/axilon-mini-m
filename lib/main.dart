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


// HTTP
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  Widget build(BuildContext context) {
    // Start listening for phone calls
    CallListener.startListening(context);

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
