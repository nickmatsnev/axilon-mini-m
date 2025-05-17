import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

// Providers
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

// Pages
import '../services/notification_service.dart';
import 'edit_scenario_page.dart';
import 'task_details_page.dart';      // Optional: if you have a scenario details page, replace this import.
import 'call_details_page.dart';
import 'scenario_chat_page.dart';     // The page to create/run a scenario chat

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isLoadingScenarios = true;
  bool _isLoadingCalls = true;
  Map<String, String> _contactsMap = {};
  bool _hasFetchedLanguage = false;

  List<dynamic> _scenarios = [];
  List<dynamic> _calls = [];

  Future<void> _loadContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final Map<String, String> mapping = {};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          mapping[normalized] = contact.displayName;
        }
      }
      setState(() => _contactsMap = mapping);
    }
  }

  String _getContactName(String phone) {
    String normalized = phone.replaceAll(RegExp(r'\D'), '');
    return _contactsMap[normalized] ?? phone;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchScenarios();
      _fetchUnreadCalls();
      _loadContacts();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final translation = Provider.of<TranslationProvider>(context, listen: false);
      final token = auth.token ?? "";
      final user = auth.user;
      if (!_hasFetchedLanguage && token.isNotEmpty && user != null) {
        translation.fetchUserLanguage(token, user['user_id']).catchError((e) => print(e));
        _hasFetchedLanguage = true;
      }
      if (user != null) {
        NotificationService().initialize(user['user_id']);
      }
    });
  }

  Future<void> _fetchScenarios() async {
    setState(() => _isLoadingScenarios = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?['user_id'];
    if (userId == null) {
      setState(() => _isLoadingScenarios = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/getAll/$userId'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _scenarios = data;
          _isLoadingScenarios = false;
        });
      } else {
        setState(() => _isLoadingScenarios = false);
      }
    } catch (_) {
      setState(() => _isLoadingScenarios = false);
    }
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

  Future<void> _fetchUnreadCalls() async {
    setState(() => _isLoadingCalls = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?['user_id'];
    if (userId == null) {
      setState(() => _isLoadingCalls = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/calls'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final unread = data.where((c) {
          final isRead = c['is_read'] == true;
          final hasSummary = c['summary'] != null && c['summary'].toString().trim().isNotEmpty;
          return !isRead && hasSummary;
        }).toList();
        unread.sort((a, b) => (b['start_time'] as String).compareTo(a['start_time'] as String));
        setState(() {
          _calls = unread.take(3).toList();
          _isLoadingCalls = false;
        });
      } else {
        setState(() => _isLoadingCalls = false);
      }
    } catch (_) {
      setState(() => _isLoadingCalls = false);
    }
  }

  String _formatCallTime(dynamic startTime) {
    if (startTime == null) return '---';
    try {
      final dt = DateTime.parse(startTime.toString());
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return '---';
    }
  }

  String _formatDuration(dynamic dur) {
    if (dur == null) return 'N/A';
    final secs = dur['seconds'] ?? 0;
    final mins = dur['minutes'] ?? 0;
    final hrs  = dur['hours'] ?? 0;
    if (hrs > 0) return '${hrs}h ${mins}m ${secs}s';
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
  Future<void> _toggleStatus(int index) async {
    final scn = _scenarios[index];
    final id = scn['id'];
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final resp = await http.put(
      Uri.parse(
          'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/toggle/$id'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      setState(() => _scenarios[index]['status'] = body['status']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Toggle failed (${resp.statusCode})')),
      );
    }
  }

  int _selectedIndex = 0;
  void _onItemTapped(int idx) {
    setState(() => _selectedIndex = idx);
    switch (idx) {
      case 0: break;
      case 1: Navigator.pushReplacementNamed(context, '/logs'); break;
      case 2: Navigator.pushReplacementNamed(context, '/scenarios'); break;
      case 3: Navigator.pushReplacementNamed(context, '/settings'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final firstName = user?['first_name'] ?? '';
    final lastName  = user?['last_name']  ?? '';
    final phone     = user?['phone_number'] ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8EDFF), Color(0xFFF9FBFE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    children: [
                      // User Info
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9FBFE),
                          boxShadow: [ BoxShadow(color: Colors.black12, offset: Offset(0,2), blurRadius:4) ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(105,125,255,0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person, color: Colors.indigo),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$firstName $lastName', style: const TextStyle(fontSize:11, color:Colors.black)),
                                const SizedBox(height:4),
                                Text(phone.isNotEmpty ? '+$phone' : '---',
                                    style: const TextStyle(fontSize:18, fontWeight:FontWeight.bold, color:Colors.black)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Scenarios & Calls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal:16, vertical:16),
                        child: Column(
                          children: [
                            // Calls panel (unchanged)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(105,125,255,0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom:16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      width:48, height:48,
                                      decoration: BoxDecoration(color:Colors.white, borderRadius: BorderRadius.circular(12)),
                                      child: SvgPicture.asset('assets/icons/VoiceMailIcon.svg', height:56, width:56),
                                    ),
                                    const SizedBox(width:16),
                                    Expanded(child: Text(t.t("VOICEMAIL"),
                                      style: const TextStyle(fontFamily:'DrukTextWideLCG', fontSize:14, fontWeight:FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                  ]),
                                  const SizedBox(height:8),
                                  if (_isLoadingCalls)
                                    const Center(child:CircularProgressIndicator())
                                  else if (_calls.isEmpty)
                                    Text(t.t("No new calls"))
                                  else
                                    Column(
                                      children: _calls.map((call) {
                                        final summary = call['summary']?.toString() ?? '---';
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => CallDetailsPage(call: call),
                                            ));
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(vertical:6),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color:Colors.white, borderRadius: BorderRadius.circular(8)),
                                            child: _buildCallTile(call, context),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.pushReplacementNamed(context, '/logs'),
                                      child: Text(t.t("All Calls")),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Scenarios panel
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(105,125,255,0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width:48, height:48,
                                        decoration: BoxDecoration(
                                            color:Colors.white,
                                            borderRadius: BorderRadius.circular(12)
                                        ),
                                        child: SvgPicture.asset(
                                            'assets/icons/TasksIcon.svg',
                                            height:56, width:56
                                        ),
                                      ),
                                      const SizedBox(width:16),
                                      Expanded(
                                        child: Text(
                                          t.t("SCENARIOS"),
                                          style: const TextStyle(
                                              fontFamily:'DrukTextWideLCG',
                                              fontSize:18,
                                              fontWeight:FontWeight.bold
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height:8),
                                  if (_isLoadingScenarios)
                                    const Center(child:CircularProgressIndicator())
                                  else if (_scenarios.isEmpty)
                                    Text(t.t("No scenarios found"))
                                  else
                                    Column(
                                      children: _scenarios
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final idx = entry.key;
                                        final scn = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => EditScenarioPage(
                                                        scenarioId: scn['id'],
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _cleanAndTitle(scn['scenario_name']) ?? '—',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(scn['summary'] ?? '—'),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Switch.adaptive(
                                                value: scn['status'] as bool,
                                                onChanged: (_) => _toggleStatus(idx),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                          .toList(),
                                    ),
                                  const SizedBox(height:8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.pushNamed(context, '/create-scenario-chat'),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: Text(t.t("New Scenario")),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.indigo,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.pushNamed(context, '/scenarios'),
                                          icon: const Icon(Icons.open_in_new, size: 18),
                                          label: Text(t.t("View All")),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.indigo,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom navigation + diamond

            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: (idx) {
            setState(() => _selectedIndex = idx);
            switch (idx) {
              case 0: /* Home stays */ break;
              case 1: Navigator.pushReplacementNamed(context, '/logs'); break;
              case 2: Navigator.pushReplacementNamed(context, '/scenarios'); break;
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
      ),
    );
  }

  Widget _buildCallTile(dynamic call, BuildContext context) {
    final phone = _getContactName('+${call['caller_phone']}');
    final summary  = call['summary'] ?? '---';
    final dateText = _formatCallTime(call['start_time']);
    final durText  = _formatDuration(call['duration']);
    final category = call['category'] ?? '---';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width:6),
              SvgPicture.asset('assets/icons/VoiceMailIcon.svg', height:16, width:16),
            ]),
            const SizedBox(height:4),
            Text("Category: $category", style: const TextStyle(fontSize:12, color:Colors.grey)),
            const SizedBox(height:4),
            Text(summary, style: const TextStyle(color:Colors.black87)),
          ]),
        ),
        const SizedBox(width:8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(dateText, style: const TextStyle(fontSize:12, color:Colors.grey)),
          Text(durText,  style: const TextStyle(fontSize:12, color:Colors.grey)),
        ]),
      ],
    );
  }
}

// Triangle painter
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width/2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_TrianglePainter old) => false;
}

// Big triangle painter
class _BigTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final halfW = size.width/2, halfH = size.height/2;
    final bottom  = Offset(halfW, halfH+68);
    final left    = Offset(halfW-50, halfH+19);
    final right   = Offset(halfW+50, halfH+19);

    final fill = Paint()..color = const Color(0xFFF9FBFE)..style = PaintingStyle.fill;
    final path = Path()..moveTo(bottom.dx,bottom.dy)..lineTo(left.dx,left.dy)..lineTo(right.dx,right.dy)..close();
    canvas.drawPath(path, fill);

    final stroke = Paint()..color = Colors.indigo.shade300..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawLine(bottom, left, stroke);
    canvas.drawLine(bottom, right, stroke);
    // top invisible
    final top = Paint()..color = const Color(0xFFF9FBFE)..style = PaintingStyle.stroke..strokeWidth=1;
    canvas.drawLine(left, right, top);
  }
  @override bool shouldRepaint(_BigTrianglePainter old) => false;
}
