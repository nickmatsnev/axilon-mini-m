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
  String? reaction;
  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.time,
    this.reaction,
  });
}

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _chatId = "";
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSending = false;
  Map<String, String> _contactsMap = {};
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _timeLeft = 0;
  late String _userId;
  String? _assistantName;
  String? _assistantImage;
  late AnimationController _typingIndicatorController;
  late Animation<double> dot1Scale;
  late Animation<double> dot2Scale;
  late Animation<double> dot3Scale;
  bool _hasFetchedLanguage = false;
  bool _hasFetchedCalls = false;
  List<String> _suggestions = [];


  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userId = authProvider.user?['user_id'] ?? "anonymous";
    _initializeAgent();
    _initializeChat();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final translationProvider = Provider.of<TranslationProvider>(context, listen: false);
      final token = authProvider.token ?? "";
      final user = authProvider.user;
      if (!_hasFetchedLanguage && token.isNotEmpty && user != null) {
        _hasFetchedLanguage = true;
        translationProvider.fetchUserLanguage(token, user['user_id']).catchError((_) {});
      }
      if (!_hasFetchedCalls) {
        _hasFetchedCalls = true;
      }
      await _loadContacts();
    });
    _typingIndicatorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    dot1Scale = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _typingIndicatorController, curve: const Interval(0.0, 0.3, curve: Curves.easeInOut)));
    dot2Scale = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _typingIndicatorController, curve: const Interval(0.3, 0.6, curve: Curves.easeInOut)));
    dot3Scale = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _typingIndicatorController, curve: const Interval(0.6, 0.9, curve: Curves.easeInOut)));
    _speech = stt.SpeechToText();
    _initSpeech();
    _inputController.addListener(() { setState(() {}); });
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final agentResponse = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/agents/my-agent'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': _userId}),
      );
      final fullName = jsonDecode(agentResponse.body)?['agent_name'] ?? "eva-agent";
      final agentType = fullName.split('-')[0].toLowerCase();
      _assistantName = agentType[0].toUpperCase() + agentType.substring(1);
      if (agentType == 'max') {
        _assistantImage = 'assets/max.jpg';
      } else if (agentType == 'butler') {
        _assistantImage = 'assets/butler.jpg';
      } else if (agentType == 'genie') {
        _assistantImage = 'assets/genie.jpg';
      } else {
        _assistantImage = 'assets/eva.png';
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats/create');
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({'user_id': _userId}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        setState(() {
          _chatId = data['chat']['chat_id'].toString();
          _messages.clear();
          final msgs = data['messages'] as List;
          for (var msg in msgs.reversed) {
            _messages.add(ChatMessage(
              id: msg['msg_id'].toString(),
              isUser: msg['sender_type'] == 'user',
              text: msg['content'] ?? "",
              time: DateTime.parse(msg['sent_datetime']),
              reaction: msg['reaction'],
            ));
          }
          _isLoading = false;
        });
        final readUrl = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/users/$_userId/setRead');
        await http.get(readUrl, headers: {'Authorization': 'Bearer ${authProvider.token}'});
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChat() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.get(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/users/$_userId/delete-chat'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (resp.statusCode == 200) {
        setState(() { _messages.clear(); _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat cleared!")));
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete chat.")));
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isSending = true;
      _suggestions.clear();
    });
    final userMsg = ChatMessage(id: UniqueKey().toString(), isUser: true, text: text.trim(), time: DateTime.now());
    setState(() { _messages.insert(0, userMsg); _inputController.clear(); });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chat-messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({'chat_id': _chatId, 'sender_type': 'user', 'content': text.trim()}),
      );
    } catch (_) {}
    String messageType = 'chit-chat';
    try {
      final defResp = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats/defineMessage'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({'user_id': _userId, 'message_text': text}),
      );
      if (defResp.statusCode == 200) {
        final defineData = jsonDecode(defResp.body);
        var m = defineData["message"];
        if (m is String) {
          messageType = m;
        } else if (m is Map) {
          var nested = m["message"];
          if (nested is String) messageType = nested;
        }
      }
    } catch (_) {}
    await _handleMessageType(messageType, text);
    setState(() => _isSending = false);
  }

  Future<void> _handleMessageType(String type, String text) async {
    switch (type) {
      case "chat_settings":
        await _handleChatCase(text);
        break;
      case "voicemail_settings":
        await _handlePhoneCase(text);
        break;
      case "voicemail_recordings":
        await _handlePhoneCallsCase(text);
        break;
      default:
        await _handleUsualCase(text);
    }
  }

  Future<void> _loadContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final Map<String, String> mapping = {};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          final normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          mapping[normalized] = contact.displayName;
        }
      }
      setState(() => _contactsMap = mapping);
    }
  }

  Future<void> _handleChatCase(String text) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats/updateChat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message_text': text,
          'current_time': DateTime.now().toIso8601String(),
          'contacts': _contactsMap.toString()
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await _addAssistantReply(data['message'] ?? "Chat prompt has been updated!");
        setState(() {
          _suggestions = List<String>.from(data['suggestions'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _handlePhoneCase(String text) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats/updateAssistant'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message_text': text,
          'current_time': DateTime.now().toIso8601String(),
          'contacts': _contactsMap.toString()
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await _addAssistantReply(data['message'] ?? "Assistant updated (phone route)!");
        setState(() {
          _suggestions = List<String>.from(data['suggestions'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _handlePhoneCallsCase(String text) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats/phoneLogsChat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message_text': text,
          'current_time': DateTime.now().toIso8601String(),
          'contacts': _contactsMap.toString()
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await _addAssistantReply(data['message'] ?? "Assistant updated (phone logs)!");
      }
    } catch (_) {}
  }

  Future<void> _handleUsualCase(String text) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chats/chitChat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'user_id': _userId,
          'message_text': text,
          'current_time': DateTime.now().toIso8601String(),
          'contacts': _contactsMap.toString()
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await _addAssistantReply(data['message'] ?? "We chatted about it!");
        setState(() {
          _suggestions = List<String>.from(data['suggestions'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _addAssistantReply(String content) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final resp = await http.post(
        Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chat-messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({'chat_id': _chatId, 'sender_type': 'agent', 'content': content.trim()}),
      );
      if (resp.statusCode == 200) {
        final saved = jsonDecode(resp.body);
        final msg = ChatMessage(
          id: saved['msg_id'].toString(),
          isUser: false,
          text: saved['content'] ?? "",
          time: DateTime.parse(saved['sent_datetime']),
          reaction: saved['reaction'],
        );
        setState(() => _messages.insert(0, msg));
      }
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) {},
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() => _isRecording = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _speechEnabled = available);
    } catch (_) {
      setState(() => _speechEnabled = false);
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) return;
    }
    if (!_isRecording) {
      setState(() { _isRecording = true; _timeLeft = 30; });
      _startTimer();
      await _speech.listen(
        onResult: (result) {
          setState(() => _inputController.text = result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
      );
    } else {
      await _stopListening();
    }
  }

  Future<void> _stopListening() async {
    _recordingTimer?.cancel();
    await _speech.stop();
    setState(() => _isRecording = false);
  }

  void _startTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 1) {
        timer.cancel();
        _stopListening();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  Future<void> _reactToMessage(String id, String reaction) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/chat-messages/$id/${reaction == 'like' ? 'like' : 'dislike'}');
    try {
      final resp = await http.put(url, headers: {
        'Authorization': 'Bearer ${authProvider.token}',
        'Content-Type': 'application/json',
      });
      if (resp.statusCode == 200) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == id);
          if (index != -1) _messages[index].reaction = reaction;
        });
      }
    } catch (_) {}
  }

  Widget _buildTypingIndicatorBubble() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFD8E1FF), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(scale: dot1Scale, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle))),
        const SizedBox(width: 5),
        ScaleTransition(scale: dot2Scale, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle))),
        const SizedBox(width: 5),
        ScaleTransition(scale: dot3Scale, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle))),
      ]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser ? Colors.white : const Color(0xFFD8E1FF);
    final textColor = isUser ? Colors.black87 : Colors.black;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(0),
      bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(12),
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: alignment,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message copied!")));
              },
              child: msg.isUser
              // User messages remain unchanged, with time visible
                  ? Container(
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: borderRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(msg.text, style: TextStyle(fontSize: 15, color: textColor)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(msg.time),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              )
              // Agent messages get the “two-tab” footer
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Top part: text + time, without bottom padding
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: borderRadius.topLeft,
                        topRight: borderRadius.topRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(msg.text, style: TextStyle(fontSize: 15, color: textColor)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('HH:mm').format(msg.time),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Bottom tabs: dislike on left, like on right
                  Container(
                    height: 28,
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFE8EDFF),
                      borderRadius: BorderRadius.only(
                        bottomLeft: borderRadius.bottomLeft,
                        bottomRight: borderRadius.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Dislike tab
                        Expanded(
                          child: InkWell(
                            onTap: msg.reaction == 'dislike'
                                ? null
                                : () => _reactToMessage(msg.id, 'dislike'),
                            child: Container(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.thumb_down,
                                size: 16,
                                color: msg.reaction == 'dislike' ? Colors.red : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // Like tab
                        Expanded(
                          child: InkWell(
                            onTap: msg.reaction == 'like'
                                ? null
                                : () => _reactToMessage(msg.id, 'like'),
                            child: Container(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.thumb_up,
                                size: 16,
                                color: msg.reaction == 'like' ? Colors.green : Colors.grey,
                              ),
                            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context, listen: true);
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE8EDFF), Color(0xFFF9FBFE)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 2,
          backgroundColor: const Color(0xFFE8EDFF),
          foregroundColor: Colors.black,
          title: Row(
            children: [
              if (_assistantImage != null) ...[
                CircleAvatar(backgroundImage: AssetImage(_assistantImage!), radius: 18),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t("AI Assistant"), style: const TextStyle(fontFamily: 'DrukTextWideLCG', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(_assistantName ?? t.t("Assistant"), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteChat, tooltip: "Clear Chat"),
          ],
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pushReplacementNamed(context, '/main')),
          centerTitle: false,
        ),
        drawer: buildDrawer(context),
        body: Stack(
          children: [
            if (_isLoading)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 5, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF373BF9)))),
                      const SizedBox(height: 20),
                      const Text("Loading Chat...", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else
              Positioned.fill(
                bottom: _suggestions.isNotEmpty ? 140 : 80,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(reverse: true, itemCount: _messages.length, itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i])),
                ),
              ),
            if (_suggestions.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => OutlinedButton(
                      onPressed: () => _sendTextMessage(_suggestions[i]),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.indigo.shade300),
                        shape: const StadiumBorder(),
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(_suggestions[i], style: const TextStyle(color: Colors.black87)),
                    ),
                  ),
                ),
              ),
            if (_isSending) Positioned(left: 16, bottom: 70, child: _buildTypingIndicatorBubble()),
            if (_isRecording)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.redAccent.withOpacity(0.2),
                    child: Text("Recording... $_timeLeft s left", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Container(
                color: const Color(0xFFF9FBFE),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12), hintText: t.t("Message"), border: InputBorder.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _isSending
                          ? null
                          : () {
                        if (_isRecording) {
                          _toggleVoiceRecording();
                        } else {
                          if (_inputController.text.trim().isNotEmpty) {
                            _sendTextMessage(_inputController.text);
                          } else {
                            _toggleVoiceRecording();
                          }
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: _isSending ? Colors.grey : Colors.white, borderRadius: BorderRadius.circular(21)),
                        child: Icon(_isRecording ? Icons.stop : (_inputController.text.trim().isNotEmpty ? Icons.send : Icons.mic), color: const Color.fromRGBO(55, 59, 249, 1), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
