import 'package:axilon_mini_m/pages/resume_scenario_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:math' as math;
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import 'create_scenario_page.dart';
import 'edit_scenario_page.dart';


// Bridging shapes
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final halfWidth = size.width / 2;
    path.moveTo(halfWidth, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => false;
}

class _BigTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final halfHeight = size.height / 2;
    final halfWidth  = size.width / 2;

    final bottomVertex = Offset(halfWidth, halfHeight + 68);
    final leftVertex   = Offset(halfWidth - 50, halfHeight + 19);
    final rightVertex  = Offset(halfWidth + 50, halfHeight + 19);

    final fillPaint = Paint()
      ..color = const Color(0xFFF9FBFE)
      ..style = PaintingStyle.fill;

    final fillPath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy)
      ..lineTo(rightVertex.dx, rightVertex.dy)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    // left stroke
    final leftSidePath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy);
    final leftSidePaint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leftSidePath, leftSidePaint);

    // right stroke
    final rightSidePath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(rightVertex.dx, rightVertex.dy);
    final rightSidePaint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(rightSidePath, rightSidePaint);
  }

  @override
  bool shouldRepaint(_BigTrianglePainter oldDelegate) => false;
}


class ScenariosPage extends StatefulWidget {
  const ScenariosPage({Key? key}) : super(key: key);

  @override
  _ScenariosPageState createState() => _ScenariosPageState();
}

class _ScenariosPageState extends State<ScenariosPage> {
  bool _isLoading = true;
  List<dynamic> _scenarios = [];
  int _selectedIndex = 2; // for bottom nav

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }  // Bottom nav
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/main');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/logs');
        break;
      case 2:
        break; // already here
      case 3:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }


  Future<void> _fetchScenarios() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?['user_id'];
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final resp = await http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/getAll/$userId'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (resp.statusCode == 200) {
      setState(() {
        _scenarios = jsonDecode(resp.body);
      });
    }
    setState(() => _isLoading = false);
  }
  String _cleanAndTitle(String raw) {
    String extracted;
    try {
      final obj = jsonDecode(raw);
      extracted = obj['message'] ?? raw;
    } catch (_) {
      extracted = raw;
    }
    // Title-case:
    return extracted
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context);
    final bottomBarHeight = 60.0; // same as your BottomAppBar height
    final extraPadding = 16.0;    // gap between FAB and bottom bar
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('My Scenarios')),
        backgroundColor: const Color(0xFFE8EDFF),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _isLoading
            ? Stack(children: [const Center(child: CircularProgressIndicator())])
            : _scenarios.isEmpty
            ? Stack(children: [Center(child: Text(t.t('No scenarios found.'))),])
            : Stack(children:[
              ListView.builder(
          itemCount: _scenarios.length,
          itemBuilder: (_, i) {
            final scn = _scenarios[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(_cleanAndTitle(scn['scenario_name']) ?? '—'),
                subtitle: Text(scn['summary'] ?? '—'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final auth     = Provider.of<AuthProvider>(context, listen: false);
                  final token    = auth.token!;
                  final userId   = auth.user!['user_id'];
                  // Always ask BE to create (or fetch) a scenario‐chat for this scenario:
                  final resp = await http.post(
                    Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/create'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type':  'application/json',
                    },
                    body: jsonEncode({
                      'user_id':    userId,
                      'scenario_id': scn['id'],      // ← pass scenarioId so BE can reuse/create
                    }),
                  );
                  if (resp.statusCode == 200) {
                    final data   = jsonDecode(resp.body);
                    final chatId = data['chat']['chat_id'].toString();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResumeScenarioPage(
                          scenarioId: scn['id'],
                          chatId:      chatId,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load scenario chat.')),
                    );
                  }
                },
              ),
            );
          },
        ),
          ])
      ),
      // 1) Tell Scaffold to float at its end.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // 2) Wrap in Padding to push it up above your manual bottom menu.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: bottomBarHeight + extraPadding + MediaQuery.of(context).padding.bottom,
          right: 16.0, // keep your usual side inset
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.indigo,
          child: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateScenarioPage()),
            );
            _fetchScenarios();
          },
        ),
      ),bottomNavigationBar: BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedIndex,
      onTap: (idx) {
        setState(() => _selectedIndex = idx);
        switch (idx) {
          case 0: Navigator.pushReplacementNamed(context, '/main');  break;
          case 1: Navigator.pushReplacementNamed(context, '/logs'); break;
          case 2: break;
          case 3: Navigator.pushReplacementNamed(context, '/settings'); break;
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: t.t("Home"),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.call_outlined),
          label: t.t("Calls"),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fact_check_outlined),
          label: t.t("Scenarios"),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: t.t("Settings"),
        ),
      ],
    ),
    );
  }
}
