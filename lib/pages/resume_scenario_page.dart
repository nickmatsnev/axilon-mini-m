import 'dart:async';
import 'dart:convert';

import 'package:axilon_mini_m/pages/edit_scenario_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

class ResumeScenarioPage extends StatefulWidget {
  final String scenarioId;

  const ResumeScenarioPage({
    required this.scenarioId,
    Key? key,
  }) : super(key: key);

  @override
  _ResumeScenarioPageState createState() => _ResumeScenarioPageState();
}

class _ResumeScenarioPageState extends State<ResumeScenarioPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSending = false;
  late String _chatId;
  late String _userId;
  String? _assistantName, _assistantImage;
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  List<String> _initialSuggestions = [];
  Map<String, String> _contactsMap = {};
  late stt.SpeechToText _speech;
  bool _speechEnabled = false, _isRecording = false;
  Timer? _recordingTimer;
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
      CurvedAnimation(
        parent: _typingIndicatorController,
        curve: const Interval(0, .3, curve: Curves.easeInOut),
      ),
    );
    dot2Scale = Tween(begin: .4, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingIndicatorController,
        curve: const Interval(.3, .6, curve: Curves.easeInOut),
      ),
    );
    dot3Scale = Tween(begin: .4, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingIndicatorController,
        curve: const Interval(.6, .9, curve: Curves.easeInOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _userId = auth.user?['user_id'] ?? 'anonymous';

      await _initializeAgent();
      await _loadContacts();
      await _fetchScenarioAndChat();
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

  Future<void> _initializeAgent() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents/my-agent'),
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
      }[t];
    } catch (_) {
      _assistantName = null;
      _assistantImage = null;
    }
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
    setState(() => _contactsMap = map);
  }

  Future<void> _fetchScenarioAndChat() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // 1) load scenario to get chat_id
    final scenResp = await http.get(
      Uri.parse(
          'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/get/${widget.scenarioId}'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
      },
    );
    if (scenResp.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Failed to load scenario (${scenResp.statusCode})')),
      );
      setState(() => _isLoading = false);
      return;
    }
    final scenario = jsonDecode(scenResp.body);
    _chatId = scenario['chat_id'];

    // 2) load chat messages
    final chatResp = await http.get(
      Uri.parse(
          'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/$_chatId/messages'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
      },
    );
    if (chatResp.statusCode == 200) {
      final data = jsonDecode(chatResp.body) as List;
      _messages.clear();
      for (var m in data.reversed) {
        _messages.add(ChatMessage(
          id: UniqueKey().toString(),
          isUser: m['sender_type'] == 'user',
          text: m['content'] ?? '',
          time: DateTime.parse(m['sent_datetime']),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chat (${chatResp.statusCode})')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isSending = true;
    });

    // show user bubble immediately
    _messages.insert(
      0,
      ChatMessage(
        id: UniqueKey().toString(),
        isUser: true,
        text: text.trim(),
        time: DateTime.now(),
      ),
    );
    _inputController.clear();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final resp = await http.post(
      Uri.parse(
          'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/scenario-chat/message'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'chat_id': _chatId,
        'content': text.trim(),
      }),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final assistantText = data['message'] as String;
      _messages.insert(
        0,
        ChatMessage(
          id: UniqueKey().toString(),
          isUser: false,
          text: assistantText,
          time: DateTime.now(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send (${resp.statusCode})')),
      );
    }

    setState(() => _isSending = false);
  }

  Future<void> _deleteScenario() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final resp = await http.delete(
      Uri.parse(
          'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/delete/${widget.scenarioId}'),
      headers: {
        'Authorization': 'Bearer ${auth.token}',
      },
    );
    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Scenario deleted')));
      Navigator.of(context).pop(); // back to list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed (${resp.statusCode})')),
      );
    }
  }

  Widget _buildTypingIndicator() {
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration:
      const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFD8E1FF),
          borderRadius: BorderRadius.circular(12)),
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
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("Copied!")));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(color: bg, borderRadius: radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(msg.text,
                    style: TextStyle(fontSize: 15, color: txtColor)),
                const SizedBox(height: 4),
                Text(DateFormat('HH:mm').format(msg.time),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          if (_assistantImage != null) ...[
            CircleAvatar(
                backgroundImage: AssetImage(_assistantImage!), radius: 18),
            const SizedBox(width: 8),
          ],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              t.t("Build Scenario"),
              style: const TextStyle(
                  fontFamily: 'DrukTextWideLCG',
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              _assistantName ?? t.t("Assistant"),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteScenario,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditScenarioPage(scenarioId: widget.scenarioId),
                ),
              );
            },
          )
        ],
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

        if (_isSending)
          Positioned(left: 16, bottom: 70, child: _buildTypingIndicator()),

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
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: t.t("Your answer..."),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
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
                    size: 20,
                    color: const Color.fromRGBO(55, 59, 249, 1),
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
