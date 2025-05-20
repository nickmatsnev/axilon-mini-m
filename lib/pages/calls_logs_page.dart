import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

// Providers
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

// Pages
import 'call_details_page.dart';

/// Triangles for bottom nav
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
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

    final leftSidePath = Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy);
    final leftSidePaint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leftSidePath, leftSidePaint);

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

class CallLogsPage extends StatefulWidget {
  const CallLogsPage({Key? key}) : super(key: key);

  @override
  State<CallLogsPage> createState() => _CallLogsPageState();
}

class _CallLogsPageState extends State<CallLogsPage> {
  List<dynamic> _callLogs = [];
  bool _isLoading = true;
  int _selectedIndex = 1; // "Calls" tab
  Map<String, String> _contactsMap = {};
  late AudioPlayer _audioPlayer;
  Map<String, bool> _playingStatus = {};
  String? _lastPlayedCallId;
  bool _hasFetchedLanguage = false;

  // filter
  String _filterCategory = 'Все';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final translationProvider = Provider.of<TranslationProvider>(context, listen: false);
      final token = authProvider.token ?? "";
      final user = authProvider.user;
      if (!_hasFetchedLanguage && token.isNotEmpty && user != null) {
        translationProvider.fetchUserLanguage(token, user['user_id']).catchError((_) {});
        _hasFetchedLanguage = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.fetchUserAndUpdateLang(context);
      await _fetchCallLogs();
      await _loadContacts();
    });
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (_lastPlayedCallId != null) {
        setState(() {
          _playingStatus[_lastPlayedCallId!] = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final mapping = <String,String>{};
      for (var c in contacts) {
        for (var p in c.phones) {
          final num = p.number.replaceAll(RegExp(r'\D'), '');
          mapping[num] = c.displayName;
        }
      }
      setState(() => _contactsMap = mapping);
    }
  }

  Future<void> _fetchCallLogs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?['user_id'];
    if (userId == null || auth.token == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final url = Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/calls');
      final resp = await http.get(url, headers: {'Authorization':'Bearer ${auth.token}'});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          data.sort((a, b) {
            final aT = DateTime.tryParse(a['start_time'] ?? '');
            final bT = DateTime.tryParse(b['start_time'] ?? '');
            if (aT==null||bT==null) return 0;
            return bT.compareTo(aT);
          });
          setState(() {
            _callLogs = data;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _getContactName(String phone) {
    final norm = phone.replaceAll(RegExp(r'\D'), '');
    return _contactsMap[norm] ?? phone;
  }

  Map<String, List<dynamic>> _groupCallsByTime(List<dynamic> calls) {
    final t = Provider.of<TranslationProvider>(context, listen: true);
    final now = DateTime.now();
    final groups = {
      t.t("Today"): <dynamic>[],
      t.t("Yesterday"): <dynamic>[],
      t.t("Week ago"): <dynamic>[],
      t.t("Month ago"): <dynamic>[],
      t.t("Year ago"): <dynamic>[],
      t.t("Older"): <dynamic>[],
    };
    for (var call in calls) {
      final s = call['start_time'];
      final dt = s != null ? DateTime.tryParse(s) : null;
      if (dt == null) {
        groups[t.t("Older")]!.add(call);
        continue;
      }
      final diff = now.difference(dt).inDays;
      if (diff == 0) groups[t.t("Today")]!.add(call);
      else if (diff == 1) groups[t.t("Yesterday")]!.add(call);
      else if (diff <= 7) groups[t.t("Week ago")]!.add(call);
      else if (diff <= 30) groups[t.t("Month ago")]!.add(call);
      else if (diff <= 365) groups[t.t("Year ago")]!.add(call);
      else groups[t.t("Older")]!.add(call);
    }
    final filtered = <String,List<dynamic>>{};
    groups.forEach((k,v){ if (v.isNotEmpty) filtered[k]=v; });
    return filtered;
  }

  String _formatDuration(dynamic d) {
    final t = Provider.of<TranslationProvider>(context, listen: true);
    if (d==null) return 'N/A';
    final sec = d['seconds'] ?? 0;
    final min = d['minutes'] ?? 0;
    final hr  = d['hours'] ?? 0;
    if (hr>0) return '${hr}${t.t("h")} ${min}${t.t("m")}';
    if (min>0) return '${min}${t.t("m")} ${sec}${t.t("s")}';
    return '${sec}${t.t("s")}';
  }

  Future<void> _handlePlayPause(dynamic call) async {
    final callId = call['call_id']?.toString() ?? call['id']?.toString() ?? '';
    final isPlaying = _playingStatus[callId] ?? false;
    if (isPlaying) {
      await _audioPlayer.pause();
      setState(() => _playingStatus[callId] = false);
      return;
    }
    // stop others
    _playingStatus.keys.forEach((k)=> _playingStatus[k]=false);
    await _audioPlayer.stop();
    final url = call['audio'] ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No audio for this call')));
      return;
    }
    try {
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _playingStatus[callId] = true;
        _lastPlayedCallId = callId;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playback error: $e')));
    }
  }

  Widget _buildCallItem(dynamic call) {
    final callId = call['call_id']?.toString() ?? call['id']?.toString() ?? '';
    final dt = call['start_time']!=null ? DateTime.tryParse(call['start_time']) : null;
    final dateText = dt==null ? '---' : DateFormat('HH:mm').format(dt);
    final durText = _formatDuration(call['duration']);
    final name = _getContactName(call['caller_phone']?.toString() ?? '');
    final summary = call['summary'] ?? '';
    final category = call['category'] ?? '';
    final isPlaying = _playingStatus[callId] ?? false;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // summary + category
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(category, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 2),
              Text('$dateText • $durText', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () => _handlePlayPause(call),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch(index) {
      case 0: Navigator.pushReplacementNamed(context,'/main'); break;
      case 1: break;
      case 2: Navigator.pushReplacementNamed(context,'/scenarios'); break;
      case 3: Navigator.pushReplacementNamed(context,'/settings'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context, listen: true);

    // build category filter list
    final cats = <String>{'Все'};
    for (var c in _callLogs) {
      final cat = (c['category'] as String?)?.trim();
      if (cat != null && cat.isNotEmpty) cats.add(cat);
    }
    final filteredLogs = _filterCategory == 'Все'
        ? _callLogs
        : _callLogs.where((c) => (c['category'] ?? '') == _filterCategory).toList();
    final grouped = _groupCallsByTime(filteredLogs);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE8EDFF), Color(0xFFF9FBFE)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFFE8EDFF),
          foregroundColor: Colors.black,
          elevation: 2,
          title: Text(t.t('CALLS').toUpperCase(), style: const TextStyle(fontFamily: 'DrukTextWideLCG', fontSize: 20, fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterCategory,
                  items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _filterCategory = v!),
                  icon: const Icon(Icons.filter_list, color: Colors.black),
                ),
              ),
            ),
          ],
          centerTitle: false,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 60,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (ctx, i) {
                    final grp = grouped.keys.elementAt(i);
                    final calls = grouped[grp]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(grp.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        ...calls.map((call) {
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CallDetailsPage(call: call)),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: _buildCallItem(call),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ),
              // bottom nav
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
              case 0: Navigator.pushReplacementNamed(context, '/main'); break;
              case 1: break;
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
}
