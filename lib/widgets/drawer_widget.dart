import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

// The Drawer
Widget buildDrawer(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final translationProvider = Provider.of<TranslationProvider>(context, listen: true);

  Future<int> _fetchMessageCount() async {
    final token = authProvider.token;
    final userId = authProvider.user?['user_id'];
    if (userId == null) {
      return 0;
    }
    try {
      final resp = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['unread_count'];
      } else {
        print('Fetching unread message count for user $userId failed: ${resp.body}');
        return 0;
      }
    } catch (err) {
      print('Exception fetching unread message count locally: $err');
      return 0;
    }
  }
  // Helper to fetch all tasks for the current user -> then count statuses
  Future<Map<String, int>> _fetchTaskCountsLocally() async {
    final token = authProvider.token;
    final userId = authProvider.user?['user_id'];
    if (userId == null) {
      return {'pending': 0, 'in_progress': 0, 'completed': 0, 'failed': 0};
    }

    try {
      final resp = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/tasks'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        // data is an array of tasks
        int pending = 0;
        int inProgress = 0;
        int completed = 0;
        int failed = 0;

        for (final task in data) {
          final status = (task['task_status'] ?? '').toLowerCase();
          if (status == 'pending') pending++;
          else if (status == 'in_progress') inProgress++;
          else if (status == 'completed' || status == 'done') completed++;
          else if (status == 'failed') failed++;
        }

        return {
          'pending': pending,
          'in_progress': inProgress,
          'completed': completed,
          'failed': failed,
        };
      } else {
        print('Fetching tasks for user $userId failed: ${resp.body}');
        return {'pending': 0, 'in_progress': 0, 'completed': 0, 'failed': 0};
      }
    } catch (err) {
      print('Exception fetching tasks locally: $err');
      return {'pending': 0, 'in_progress': 0, 'completed': 0, 'failed': 0};
    }
  }

  // Now return the Drawer with everything
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Colors.indigo,
          ),
          child: Text(
            "${translationProvider.t('Hey,')} ${authProvider.user?['first_name']}\n\n${translationProvider.t("Axilon menu")}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(translationProvider.t('Profile')),
          onTap: () {
            Navigator.pushReplacementNamed(context, '/profile');
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(translationProvider.t('Setup Agent')),
          onTap: () {
            Navigator.pushReplacementNamed(context, '/choice');
          },
        ),
        FutureBuilder<int>(
          future: _fetchMessageCount(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                leading: const Icon(Icons.chat),
                title: Text('${translationProvider.t('Chat')} (Loading...)'),
              );
            } else if (snapshot.hasError) {
              return ListTile(
                leading: const Icon(Icons.chat),
                title: Text('${translationProvider.t('Chat')} (Error)'),
              );
            } else {
              final unreadCount = snapshot.data ?? 0;
              final chatTitle = unreadCount > 0
                  ? '${translationProvider.t('Chat')} ($unreadCount)'
                  : translationProvider.t('Chat');

              return ListTile(
                leading: const Icon(Icons.chat),
                title: Text(chatTitle),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/chat');
                },
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.call_made),
          title: Text(translationProvider.t('Calls')),
          onTap: () {
            Navigator.pushReplacementNamed(context, '/logs');
          },
        ),
        ListTile(
          leading: const Icon(Icons.home),
          title: Text(translationProvider.t('Main')),
          onTap: () {
            Navigator.pushReplacementNamed(context, '/main');
          },
        ),
        // Show admin stuff if user is admin
        if (authProvider.user?['is_admin'] == true) ...[
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: Text(translationProvider.t("Admin Panel")),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/admin-prompts');
            },
          ),
          // Also show the Statistics page if admin
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(translationProvider.t("Statistics")),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/stats');
            },
          ),
        ],
        ListTile(
          leading: const Icon(Icons.phonelink_setup_rounded),
          title: Text(translationProvider.t('USSD')),
          onTap: () {
            Navigator.pushReplacementNamed(context, '/ussd');
          },
        ),
        // Now a FutureBuilder that fetches tasks from /api/users/$userId/tasks and counts them
        FutureBuilder<Map<String, int>>(
          future: _fetchTaskCountsLocally(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                leading: const Icon(Icons.task),
                title: Text('${translationProvider.t("Tasks")} (Loading...)'),
              );
            } else if (snapshot.hasError) {
              return ListTile(
                leading: const Icon(Icons.task),
                title: Text('${translationProvider.t("Tasks")} (Error)'),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/scenarios');
                },
              );
            } else {
              final counts = snapshot.data ?? {
                'pending': 0,
                'in_progress': 0,
                'completed': 0,
                'failed': 0,
              };
              return ExpansionTile(
                leading: const Icon(Icons.task),
                title: Text(translationProvider.t('Tasks')),
                children: [
                  ListTile(
                    title: Text('${translationProvider.t('Pending')} (${counts["pending"]})'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                        context,
                        '/scenarios',
                        arguments: {'status': 'pending'},
                      );
                    },
                  ),
                  ListTile(
                    title: Text('${translationProvider.t('In Progress')} (${counts["in_progress"]})'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                        context,
                        '/scenarios',
                        arguments: {'status': 'in progress'},
                      );
                    },
                  ),
                  ListTile(
                    title: Text('${translationProvider.t('Completed')} (${counts["completed"]})'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                        context,
                        '/tasks',
                        arguments: {'status': 'completed'},
                      );
                    },
                  ),
                  ListTile(
                    title: Text('${translationProvider.t('Failed')} (${counts["failed"]})'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                        context,
                        '/tasks',
                        arguments: {'status': 'failed'},
                      );
                    },
                  ),
                ],
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(translationProvider.t('Logout')),
          onTap: () {
            authProvider.logout();
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
      ],
    ),
  );
}
