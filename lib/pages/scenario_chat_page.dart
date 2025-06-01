import 'package:axilon_mini_m/pages/resume_scenario_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import '../widgets/drawer_widget.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime time;
  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.time,
  });
}

class ScenarioChatPage extends StatefulWidget {
  const ScenarioChatPage({super.key});

  @override
  State<ScenarioChatPage> createState() => _ScenarioChatPageState();
}

class _ScenarioChatPageState extends State<ScenarioChatPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _chatId = "";
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSending = false;

  /// your hard-coded default suggestions
  List<String> _initialSuggestions = [
    "Если я не ответил - пишите...",
    "Если звонит курьер...",
    "С 23:00 до 9:00 не беспокоить, перезвоню",
    "В отпуске с ..."
  ];

  late stt.SpeechToText _speech;
  final bool _isRecording = false;
  Timer? _recordingTimer;

  late String _userId;
  String? _assistantName, _assistantImage;

  late AnimationController _typingIndicatorController;
  late Animation<double> dot1Scale, dot2Scale, dot3Scale;

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();
    _typingIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    dot1Scale = Tween(begin: .4, end: 1.0).animate(
      CurvedAnimation(parent: _typingIndicatorController, curve: const Interval(0, .3, curve: Curves.easeInOut)),
    );
    dot2Scale = Tween(begin: .4, end: 1.0).animate(
      CurvedAnimation(parent: _typingIndicatorController, curve: const Interval(.3, .6, curve: Curves.easeInOut)),
    );
    dot3Scale = Tween(begin: .4, end: 1.0).animate(
      CurvedAnimation(parent: _typingIndicatorController, curve: const Interval(.6, .9, curve: Curves.easeInOut)),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _userId = auth.user?['user_id'] ?? 'anonymous';

      await _initializeAgent();
      await _initializeChat();
      await _loadContacts();
    });

    _inputController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typingIndicatorController.dispose();
    _inputController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Вы уверены?'),
        content: const Text('Если вы не создали сценарий, то прогресс будет утерян!'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Остаться')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Уйти')),
        ],
      ),
    );
    if (leave == true) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Future<void> _initializeAgent() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents/my-agent'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': _userId}),
      );
      final fullName = jsonDecode(resp.body)['agent_name'] ?? 'eva-agent';
      final t = fullName.split('-')[0].toLowerCase();
      _assistantName = t[0].toUpperCase() + t.substring(1);
      _assistantImage = {
        'max': 'assets/max.jpg',
        'butler': 'assets/butler.jpg',
        'genie': 'assets/genie.jpg'
      }[t] ?? 'assets/eva.png';
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/create'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': _userId}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _chatId = data['chat']['chat_id'].toString();
        _messages.clear();

        // seed with any server-provided intro if needed
        final rawMessages = data['messages'] as List;
        for (var m in rawMessages.reversed) {
          _messages.add(ChatMessage(
            id: UniqueKey().toString(),
            isUser: m['sender_type'] == 'user',
            text: m['content'] ?? '',
            time: DateTime.parse(m['sent_datetime']),
          ));
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadContacts() async {
    if (!await FlutterContacts.requestPermission()) return;
    final list = await FlutterContacts.getContacts(withProperties: true);
    final map = <String, String>{};
    for (var c in list) {
      for (var p in c.phones) {
        final num = p.number.replaceAll(RegExp(r'\D'), '');
        map[num] = c.displayName;
      }
    }
  }

  void _onSuggestionTap(String s) {
    _inputController.text = s;
    setState(() => _initialSuggestions = []);
  }

  Future<void> _sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isSending = true;
      _initialSuggestions = [];
    });

    // 1) show user bubble
    _messages.insert(0, ChatMessage(
      id: UniqueKey().toString(),
      isUser: true,
      text: text.trim(),
      time: DateTime.now(),
    ));
    _inputController.clear();
    // 2) call your BE
    final auth = Provider.of<AuthProvider>(context, listen: false);
    print("Auth:");
    print(auth.user!['user_id']);
    final resp = await http.post(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/message'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'chat_id': _chatId, 'content': text.trim(), 'user_id': auth.user!['user_id']}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      //
      // 👇 read `message`, not `reply`
      //
      final assistantText = data['message'] as String;
      final insertBody   = data['insert_body'] != null
          ? Map<String, dynamic>.from(data['insert_body'])
          : null;

      // 3) show assistant bubble
      _messages.insert(0, ChatMessage(
        id: UniqueKey().toString(),
        isUser: false,
        text: assistantText,
        time: DateTime.now(),
      ));

      if (insertBody != null) {
          Navigator.pushReplacementNamed(context, '/main');
        } else {
        Navigator.pushReplacementNamed(context, '/main');
        }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${resp.statusCode} sending message')),
      );
    }

    setState(() => _isSending = false);
  }


  Widget _buildTypingIndicator() {
    Widget dot = Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle));
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFD8E1FF), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(scale: dot1Scale, child: dot),
        const SizedBox(width: 5),
        ScaleTransition(scale: dot2Scale, child: dot),
        const SizedBox(width: 5),
        ScaleTransition(scale: dot3Scale, child: dot),
      ]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser ? Colors.white : const Color(0xFFD8E1FF);
    final txtColor = isUser ? Colors.black87 : Colors.black;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
      bottomRight: isUser ? Radius.zero : const Radius.circular(12),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: align,
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: msg.text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(color: bg, borderRadius: radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(msg.text, style: TextStyle(fontSize: 15, color: txtColor)),
                const SizedBox(height: 4),
                Text(DateFormat('HH:mm').format(msg.time), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8EDFF),
        foregroundColor: Colors.black,
        elevation: 2,
        title: Row(children: [
          if (_assistantImage != null) ...[
            CircleAvatar(backgroundImage: AssetImage(_assistantImage!), radius: 18),
            const SizedBox(width: 8),
          ],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              t.t("Сценарий"),
              style: const TextStyle(fontFamily: 'DrukTextWideLCG', fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(_assistantName ?? t.t("Assistant"),
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _confirmLeave,
        ),
      ),
      drawer: buildDrawer(context),
      body: Stack(children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Positioned.fill(
            bottom: 140,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
              ),
            ),
          ),

        // initial suggestions strip
        if (_initialSuggestions.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 88,
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _initialSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => OutlinedButton(
                  onPressed: () => _onSuggestionTap(_initialSuggestions[i]),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.indigo.shade300),
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(_initialSuggestions[i], style: const TextStyle(color: Colors.black87)),
                ),

              ),
            ),
          ),

        if (_isSending) Positioned(left: 16, bottom: 70, child: _buildTypingIndicator()),

        // input bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Container(
            color: const Color(0xFFF9FBFE),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: t.t("Your answer..."),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _isSending
                    ? null
                    : () {
                  if (_isRecording) {
                    _speech.stop();
                  } else if (_inputController.text.trim().isNotEmpty) {
                    _sendTextMessage(_inputController.text);
                  } else {
                    _speech.listen();
                  }
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey : Colors.white,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.send,
                    color: const Color.fromRGBO(55, 59, 249, 1),
                    size: 20,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
