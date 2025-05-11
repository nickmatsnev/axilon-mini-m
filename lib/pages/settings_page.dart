import 'dart:async';
import 'dart:convert';
import 'dart:io';          // for File reading (recorded file)
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:axilon_m/pages/ussd_setup_page.dart';
import 'package:axilon_m/widgets/scenario_admin_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Audio-related
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';

// Providers
import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

// For other audio
import 'package:audioplayers/audioplayers.dart';

import '../widgets/scenario_stats_widget.dart';

/// A single page that combines:
///  - Profile settings (including "Reject All Calls")
///  - Voice Cloning (record or pick an audio file, then clone)
///  - Choose Assistant
///  - Admin Panel (+ Stats) if isAdmin == true
///  - Logout button
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------
  //  VOICE CLONE FIELDS
  // ---------------------------------------------------------
  PlatformFile? _selectedFile; // from file picker
  String? _recordedFilePath;   // from recording
  bool _isCloningVoiceFile = false;

  final TextEditingController _voiceNameController = TextEditingController();
  final TextEditingController _voiceDescriptionController = TextEditingController();

  // For recording
  bool _isRecording = false;
  FlutterSoundRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    _initRecorder();  // <--- setup for audio recording

    _adminTabController = TabController(length: 9, vsync: this);

    // Profile: load "reject_all"
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null && user['reject_all'] != null) {
      _isRejectAll = user['reject_all'] == true;
    }

    // Assistants: fetch chosen agent
    _fetchUserAgents();

    // If admin => load admin data
    if (_isUserAdmin(user)) {
      _fetchPrompts();
      _fetchUsers();
      _fetchAllCalls();
      _fetchAllChats();
      _fetchAllTasks();
      _fetchAllAgents();
      _fetchAllStats();
    }
  }

  // ---------------------------------------------------------
  //  RECORDING SETUP
  // ---------------------------------------------------------
  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();

    // request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission denied")),
      );
      return;
    }

    await _recorder!.openRecorder();
  }

  Future<void> _startRecording() async {
    if (_recorder == null) return;
    try {
      final tempDir = Directory.systemTemp;
      final path = '${tempDir.path}/my_recorded_voice.aac';

      await _recorder!.startRecorder(toFile: path);
      setState(() {
        _isRecording = true;
        _recordedFilePath = null; // reset the previously recorded path
      });
    } catch (e) {
      debugPrint("startRecording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (_recorder == null) return;
    try {
      final resultPath = await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
        _recordedFilePath = resultPath; // path to the recorded file
      });
    } catch (e) {
      debugPrint("stopRecording error: $e");
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    super.dispose();
  }

  // Let user pick an existing audio file
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _recordedFilePath = null; // if user picks a file, ignore the recorded path
      });
    }
  }

  // Actually do the POST to your Node server
  Future<void> _cloneVoiceFile() async {
    final name = _voiceNameController.text.trim();
    final desc = _voiceDescriptionController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a voice name.")),
      );
      return;
    }

    // we need either a picked file or a recorded path
    if (_selectedFile == null && _recordedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No audio selected or recorded.")),
      );
      return;
    }

    setState(() => _isCloningVoiceFile = true);

    try {
      // get userId
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['user_id'];
      if (userId == null) {
        throw "No userId found; are you logged in?";
      }

      // Node server route
      final uri = Uri.parse("https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/voice-cloning/clone-voice");
      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId.toString();
      request.fields['voiceName'] = name;
      request.fields['voiceDescription'] = desc;

      // if user recorded audio
      if (_recordedFilePath != null) {
        final file = File(_recordedFilePath!);
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            bytes,
            filename: 'recorded.aac',
            contentType: MediaType('audio', 'aac'),
          ),
        );
      }
      // else user picked a file
      else if (_selectedFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            _selectedFile!.bytes!,
            filename: _selectedFile!.name,
            contentType: MediaType('audio', 'mpeg'), // or 'audio/wav' etc.
          ),
        );
      }

      // If your server requires auth:
      // request.headers['Authorization'] = "Bearer ${authProvider.token}";

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final respJson = jsonDecode(respStr);

        // If server returns updated user
        final updatedUser = respJson['user'];
        if (updatedUser != null) {
          authProvider.setUser(updatedUser);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voice cloned successfully!")),
        );
      } else {
        final respStr = await response.stream.bytesToString();
        debugPrint("Error from server: $respStr");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode} => $respStr")),
        );
      }
    } catch (e) {
      debugPrint("cloneVoiceFile error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exception: $e")),
      );
    } finally {
      setState(() => _isCloningVoiceFile = false);
    }
  }

  // Build the entire Voice Cloning section (record OR pick)
  Widget _buildVoiceCloningSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(105, 125, 255, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.record_voice_over, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Voice Cloning",
                  style: const TextStyle(
                    fontFamily: 'DrukTextWideLCG',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // name
          TextField(
            controller: _voiceNameController,
            decoration: const InputDecoration(
              labelText: "Voice Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // description
          TextField(
            controller: _voiceDescriptionController,
            decoration: const InputDecoration(
              labelText: "Voice Description",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // row of two buttons: Record or Pick
          Row(
            children: [
              // record
              ElevatedButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? "Stop Recording" : "Record Audio"),
              ),
              const SizedBox(width: 16),
              // pick
              ElevatedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.audiotrack),
                label: const Text("Pick File"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // status text re: selected/recorded
          Text(
            _isRecording
                ? "Recording in progress..."
                : _recordedFilePath != null
                ? "Recorded file: $_recordedFilePath"
                : _selectedFile != null
                ? "Selected file: ${_selectedFile!.name}"
                : "No audio selected/recorded",
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),

          // Submit button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isCloningVoiceFile ? null : _cloneVoiceFile,
            child: _isCloningVoiceFile
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
              "Clone My Voice",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'DrukTextWideLCG',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  //  PROFILE FIELDS
  // ---------------------------------------------------------
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final TextEditingController agentPromptController = TextEditingController();
  final TextEditingController agentPhonePromptController = TextEditingController();
  bool _isRejectAll = false;

  // ---------------------------------------------------------
  //  ASSISTANTS
  // ---------------------------------------------------------
  final List<Map<String, String>> assistants = [
    // ... same as your code ...
    {
      'name': 'Eva',
      'description': 'Warm and caring. Will help in any situation.',
      'prompt': '...',
      'type': 'Eva',
      'image': 'assets/eva.png',
      'audio': 'eva.wav',
      'voice': 'geZBdP2vohuTWBjFpLuJ',
    },
    {
      'name': 'Max',
      'description': 'Energetic and charismatic. Your best helper.',
      'prompt': '...',
      'type': 'Max',
      'image': 'assets/max.jpg',
      'audio': 'max.wav',
      'voice': 'UABvEBz6Pj3TqF2WweSe',
    },
    {
      'name': 'Butler',
      'description': 'Eloquent and professional. Always cool.',
      'prompt': '...',
      'type': 'Butler',
      'image': 'assets/butler.jpg',
      'audio': 'butler.wav',
      'voice': 'XbemdYthPhEKqbItloSV',
    },
    {
      'name': 'Genie',
      'description': 'Hilarious and creative. Will make your wish come true!',
      'prompt': '...',
      'type': 'Genie',
      'image': 'assets/genie.jpg',
      'audio': 'genie.wav',
      'voice': 'FfVjc9uLZIJReA7J4CY3',
    },
  ];
  String? chosenAgent;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ---------------------------------------------------------
  //  ADMIN PANEL
  // ---------------------------------------------------------
  late TabController _adminTabController;
  bool _adminPanelExpanded = false;

  bool _isLoadingPrompts = false;
  List<dynamic> _prompts = [];

  bool _isLoadingUsers = false;
  List<dynamic> _users = [];
  String _userSearch = "";

  bool _isLoadingCalls = false;
  List<dynamic> _calls = [];
  String _callSearch = "";

  bool _isLoadingChats = false;
  List<dynamic> _chats = [];
  String _chatSearch = "";

  bool _isLoadingTasks = false;
  List<dynamic> _tasks = [];
  String _taskSearch = "";

  bool _isLoadingAgents = false;
  List<dynamic> _agents = [];
  String _agentsSearch = "";

  bool _isLoadingStats = true;
  Map<String, dynamic> _globalStats = {};
  String _callsRange = 'day';
  List<Map<String, dynamic>> _callsData = [];
  String _messagesRange = 'day';
  List<Map<String, dynamic>> _messagesData = [];
  String _tasksRange = 'day';
  String _scenariosRange = 'day';
  List<Map<String, dynamic>> _tasksData = [];
  List<Map<String, dynamic>> _scenariosData = [];
  Map<String, dynamic> _countryDist = {};

  // bottom nav
  int _selectedIndex = 4; // "settings"

  // check admin
  bool _isUserAdmin(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    if (userData['is_admin'] == true || userData['is_admin'] == 1) return true;
    return false;
  }

  // ---------------------------------------------------------
  //  PROFILE LOGIC
  // ---------------------------------------------------------
  Future<void> _toggleRejectAll(bool val) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    final user = authProvider.user;
    if (token == null || user == null) return;
    final userId = user['user_id'];
    if (userId == null) return;

    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/reject-all');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({"reject_all": val}),
      );

      if (response.statusCode == 200) {
        final respData = jsonDecode(response.body);
        final updatedUser = respData['user'];
        authProvider.setUser(updatedUser);
        setState(() {
          _isRejectAll = val;
        });
      } else {
        print("Error updating reject_all: ${response.body}");
      }
    } catch (e) {
      print("Exception updating reject_all: $e");
    }
  }

  void _changePhone() {
    // you'd do your phone update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr("PHONE_UPDATED_SUCCESS"))),
    );
  }

  void _changePassword() {
    // you'd do your password update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr("PASSWORD_UPDATED_SUCCESS"))),
    );
  }

  Future<void> _deleteAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final userId = user['user_id'];
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(_tr("DELETE_ACCOUNT")),
        content: Text(_tr("DELETE_ACCOUNT_CONFIRM")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(_tr("CANCEL")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(_tr("DELETE"), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = authProvider.token;
      if (token == null) return;
      await authProvider.deleteUser(userId, token);

      authProvider.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $error")),
      );
    }
  }

  // ---------------------------------------------------------
  //  SELECT ASSISTANT LOGIC
  // ---------------------------------------------------------
  Future<void> _fetchUserAgents() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents/by-client/${authProvider.user?['user_id']}'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );

      if (response.statusCode == 200) {
        final agents = jsonDecode(response.body);
        final chosen = agents.firstWhere(
              (agent) => agent['chosen'] == true,
          orElse: () => null,
        );
        setState(() {
          chosenAgent = chosen?['agent_name'];
          agentPromptController.text = chosen?['chat_prompt'] ?? "";
          agentPhonePromptController.text = chosen?['prompt'] ?? "";
        });
      } else {
        print('Error fetching agents: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _selectAgent(
      String agentType, String prompt, String audioPath, String voice) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'clientId': authProvider.user?['user_id'],
          'agentType': agentType,
          'prompt': prompt,
          'voice': voice,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final agent = jsonDecode(response.body);

        setState(() {
          chosenAgent = agent['agent_name'];
        });
        final translationProvider =
        Provider.of<TranslationProvider>(context, listen: false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${agentType.toUpperCase()} ${translationProvider.t("selected successfully!")}'),
          ),
        );

        // optionally play a short audio
        await _audioPlayer.play(AssetSource(audioPath));
      } else {
        print('Error selecting agent: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // ---------------------------------------------------------
  //  ADMIN PANEL LOGIC
  // ---------------------------------------------------------
  Future<void> _fetchPrompts() async {
    setState(() => _isLoadingPrompts = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/prompts'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _prompts = data;
          _isLoadingPrompts = false;
        });
      } else {
        setState(() => _isLoadingPrompts = false);
        print("Failed to fetch prompts: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingPrompts = false);
      print("Error fetching prompts: $err");
    }
  }

  Future<void> _updatePrompt(String promptId, String newVal, String newDescr) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.put(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/prompts/$promptId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "prompt_val": newVal,
          "prompt_descr": newDescr,
        }),
      );
      if (response.statusCode == 200) {
        print("Prompt updated successfully");
        _fetchPrompts();
      } else {
        print("Error updating prompt: ${response.body}");
      }
    } catch (err) {
      print("Exception updating prompt: $err");
    }
  }

  Widget _buildPromptsTab() {
    if (_isLoadingPrompts) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _prompts.length,
      itemBuilder: (context, index) {
        final item = _prompts[index];
        final promptId = item['prompt_id'];
        final valController = TextEditingController(text: item['prompt_val']);
        final descrController =
        TextEditingController(text: item['prompt_descr'] ?? "");

        return Card(
          margin: const EdgeInsets.all(12.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ID: $promptId",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: descrController,
                  decoration:
                  const InputDecoration(labelText: "Description"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valController,
                  maxLines: 5,
                  decoration:
                  const InputDecoration(labelText: "Prompt Value"),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _updatePrompt(
                            promptId, valController.text, descrController.text);
                      },
                      child: const Text("Save"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = data;
          _isLoadingUsers = false;
        });
      } else {
        setState(() => _isLoadingUsers = false);
        print("Error fetching users: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingUsers = false);
      print("Exception fetching users: $err");
    }
  }

  Future<void> _deleteUser(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final resp = await http.delete(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (resp.statusCode == 200) {
        setState(() {
          _users.removeWhere((u) => u['user_id'] == userId);
        });
      } else {
        print("Failed to delete user: ${resp.body}");
      }
    } catch (err) {
      print("Error deleting user: $err");
    }
  }

  Future<void> _toggleAdmin(String userId, bool isAdmin) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final endpoint = isAdmin ? 'unsetAdmin' : 'setAdmin';
    final url =
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/$endpoint';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmin
                ? 'User demoted from admin successfully.'
                : 'User promoted to admin successfully.'),
          ),
        );
        await _fetchUsers();
      } else {
        print("Failed to toggle admin: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to toggle admin status.')),
        );
      }
    } catch (err) {
      print("Error toggling admin: $err");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling admin status: $err')),
      );
    }
  }

  String _getUserDisplayName(String userId) {
    final user = _users.firstWhere(
          (u) => u['user_id'] == userId,
      orElse: () => null,
    );
    if (user == null) return userId;
    final fname = user['first_name'] ?? '';
    final lname = user['last_name'] ?? '';
    return (fname + ' ' + lname).trim();
  }

  Widget _buildUsersTab() {
    final searchLower = _userSearch.toLowerCase();
    final filtered = _users.where((u) {
      final fName = (u['first_name'] ?? '').toString().toLowerCase();
      final lName = (u['last_name'] ?? '').toString().toLowerCase();
      final phone = (u['phone_number'] ?? '').toString().toLowerCase();
      final id = (u['user_id'] ?? '').toString().toLowerCase();
      return fName.contains(searchLower) ||
          lName.contains(searchLower) ||
          phone.contains(searchLower) ||
          id.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _userSearch = val),
            decoration: const InputDecoration(
              labelText: "Search users",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final user = filtered[index];
              final userId = user['user_id'];
              final name =
              "${user['first_name']} ${user['last_name']}".trim();
              final phone = user['phone_number'] ?? '';
              final isAdmin =
                  user['is_admin'] == true || user['is_admin'] == 1;

              return ListTile(
                title: Text(name),
                subtitle: Text("Phone: $phone\nID: $userId"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.admin_panel_settings_outlined,
                        color: isAdmin ? Colors.green : Colors.grey,
                      ),
                      tooltip:
                      isAdmin ? 'Demote to User' : 'Promote to Admin',
                      onPressed: () => _toggleAdmin(userId, isAdmin),
                    ),
                    IconButton(
                      icon:
                      const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete User',
                      onPressed: () => _deleteUser(userId),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsPage(userData: user),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _fetchAllCalls() async {
    setState(() => _isLoadingCalls = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/phone-calls'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _calls = data;
          _isLoadingCalls = false;
        });
      } else {
        setState(() => _isLoadingCalls = false);
        print("Error fetching calls: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingCalls = false);
      print("Exception phone calls: $err");
    }
  }

  Future<void> _deleteCall(String callId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final resp = await http.delete(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/phone-calls/$callId'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (resp.statusCode == 200) {
        setState(() {
          _calls.removeWhere((c) => c['call_id'] == callId);
        });
      } else {
        print("Failed to delete call: ${resp.body}");
      }
    } catch (err) {
      print("Error deleting call: $err");
    }
  }

  Widget _buildPhoneCallsTab() {
    final searchLower = _callSearch.toLowerCase();
    final filtered = _calls.where((c) {
      final from = (c['caller_phone'] ?? '').toString().toLowerCase();
      final to = (c['recipient_phone'] ?? '').toString().toLowerCase();
      final summary = (c['summary'] ?? '').toString().toLowerCase();
      return from.contains(searchLower) ||
          to.contains(searchLower) ||
          summary.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _callSearch = val),
            decoration: const InputDecoration(
              labelText: "Search calls",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingCalls
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final call = filtered[index];
              final callId = call['call_id'];
              final summary = call['summary'] ?? '';
              final from = call['caller_phone'] ?? '';
              final to = call['recipient_phone'] ?? '';
              return ListTile(
                title: Text("Call #$callId - $summary"),
                subtitle: Text("From: $from / To: $to"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCall(callId),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PhoneCallDetailsPage(callData: call),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _fetchAllChats() async {
    setState(() => _isLoadingChats = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/chats'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chats = data;
          _isLoadingChats = false;
        });
      } else {
        setState(() => _isLoadingChats = false);
        print("Error fetching chats: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingChats = false);
      print("Error chats: $err");
    }
  }

  Widget _buildChatsTab() {
    final sLower = _chatSearch.toLowerCase();
    final filtered = _chats.where((chat) {
      final cId = (chat['chat_id'] ?? '').toString().toLowerCase();
      final uId = (chat['user_id'] ?? '').toString().toLowerCase();
      final agentId = (chat['agent_id'] ?? '').toString().toLowerCase();
      return cId.contains(sLower) ||
          uId.contains(sLower) ||
          agentId.contains(sLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _chatSearch = val),
            decoration: const InputDecoration(
              labelText: "Search chats",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingChats
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final chat = filtered[index];
              final chatId = chat['chat_id'];
              final userId = chat['user_id'] ?? '';
              final agId = chat['agent_id'] ?? '';
              final userName = _getUserDisplayName(userId);

              return ListTile(
                title: Text("Chat #$chatId"),
                subtitle: Text("User: $userName | Agent: $agId"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailsPage(chatData: chat),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(
                          userData: {'user_id': userId},
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _fetchAllTasks() async {
    setState(() => _isLoadingTasks = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/tasks'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tasks = data;
          _isLoadingTasks = false;
        });
      } else {
        setState(() => _isLoadingTasks = false);
        print("Error fetching tasks: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingTasks = false);
      print("Error tasks: $err");
    }
  }

  Widget _buildTasksTab() {
    if (_isLoadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }

    final searchLower = _taskSearch.toLowerCase();
    final filtered = _tasks.where((t) {
      final txt = (t['task_text'] ?? '').toString().toLowerCase();
      final st = (t['task_status'] ?? '').toString().toLowerCase();
      final cid = (t['client_id'] ?? '').toString().toLowerCase();
      return txt.contains(searchLower) ||
          st.contains(searchLower) ||
          cid.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _taskSearch = val),
            decoration: const InputDecoration(
              labelText: "Search tasks",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final task = filtered[index];
              final tId = task['task_id'];
              final tStatus = task['task_status'];
              final tText = task['task_text'] ?? "";
              final clientId = task['client_id'] ?? "unknown";
              final userName = _getUserDisplayName(clientId);

              return ListTile(
                title: Text("Task #$tId - $tStatus"),
                subtitle: Text("User: $userName\n$tText"),
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserDetailsPage(userData: {'user_id': clientId}),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskDetailsPage(taskData: task),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _fetchAllAgents() async {
    setState(() => _isLoadingAgents = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _agents = data;
          _isLoadingAgents = false;
        });
      } else {
        setState(() => _isLoadingAgents = false);
        print("Error fetching agents: ${response.body}");
      }
    } catch (err) {
      setState(() => _isLoadingAgents = false);
      print("Exception fetching agents: $err");
    }
  }
  Future<void> _updatePhoneAgentPrompt() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final userId = user['user_id'];
    final newPrompt = agentPhonePromptController.text.trim();
    if (newPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("phone Prompt cannot be empty")),
      );
      return;
    }
    final token = authProvider.token;
    if (token == null) return;
    try {
      final response = await http.put(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents/my-agent/phone-prompt'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'userId': userId,
          'prompt': newPrompt,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Agent phone prompt updated successfully")),
        );
      } else {
        print("Error updating agent phone prompt: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update agent phone prompt")),
        );
      }
    } catch (e) {
      print("Exception updating agent phone prompt: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exception: $e")),
      );
    }
  }
  Future<void> _updateAgentPrompt() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;
    final userId = user['user_id'];
    final newPrompt = agentPromptController.text.trim();
    if (newPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prompt cannot be empty")),
      );
      return;
    }
    final token = authProvider.token;
    if (token == null) return;
    try {
      final response = await http.put(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents/my-agent/prompt'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'userId': userId,
          'chat_prompt': newPrompt,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Agent prompt updated successfully")),
        );
      } else {
        print("Error updating agent prompt: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update agent prompt")),
        );
      }
    } catch (e) {
      print("Exception updating agent prompt: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exception: $e")),
      );
    }
  }
  Widget _buildAgentsTab() {
    final searchLower = _agentsSearch.toLowerCase();
    final filtered = _agents.where((agent) {
      final agId = (agent['agent_id'] ?? '').toString().toLowerCase();
      final clientId = (agent['client_id'] ?? '').toString().toLowerCase();
      final agName = (agent['agent_name'] ?? '').toString().toLowerCase();
      return agId.contains(searchLower) ||
          clientId.contains(searchLower) ||
          agName.contains(searchLower);
    }).toList();

    return Column(
      children: [
        // search
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (val) => setState(() => _agentsSearch = val),
            decoration: const InputDecoration(
              labelText: "Search agents",
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingAgents
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final agent = filtered[index];
              final agentId = agent['agent_id'];
              final clientId = agent['client_id'];
              final name = agent['agent_name'] ?? '';
              final chosen = agent['chosen'] == true;
              final userName = _getUserDisplayName(clientId);

              return ListTile(
                title: Text("Agent #$agentId | Name: $name"),
                subtitle: Text("User: $userName\nchosen: $chosen"),
                onTap: () {
                  // Could open Agent details
                },
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsPage(userData: {'user_id': clientId}),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // STATS
  Future<void> _fetchAllStats() async {
    setState(() => _isLoadingStats = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) {
      setState(() => _isLoadingStats = false);
      return;
    }

    try {
      await Future.wait([
        _fetchGlobalStats(token),
        _fetchCallsStats(token, _callsRange),
        _fetchMessagesStats(token, _messagesRange),
        _fetchTasksStats(token, _tasksRange),
        _fetchUsersCountry(token),
        _fetchScenariosStats(token, _scenariosRange)
      ]);
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    setState(() => _isLoadingStats = false);
  }

  Future<void> _fetchGlobalStats(String token) async {
    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/stats/global');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      setState(() {
        _globalStats = jsonDecode(resp.body);
      });
    } else {
      debugPrint("Global stats error: ${resp.body}");
    }
  }

  Future<void> _fetchCallsStats(String token, String range) async {
    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/stats/calls?range=$range');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _callsData = data
            .map<Map<String, dynamic>>((e) => {
          'label': e['label'],
          'count': e['count'],
        })
            .toList();
      });
    } else {
      debugPrint("Calls data error: ${resp.body}");
    }
  }

  Future<void> _fetchMessagesStats(String token, String range) async {
    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/stats/messages?range=$range');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _messagesData = data
            .map<Map<String, dynamic>>((e) => {
          'label': e['label'],
          'count': e['count'],
        })
            .toList();
      });
    } else {
      debugPrint("Messages data error: ${resp.body}");
    }
  }

  Future<void> _fetchTasksStats(String token, String range) async {
    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/stats/tasks?range=$range');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _tasksData = data
            .map<Map<String, dynamic>>((e) => {
          'label': e['label'],
          'count': e['count'],
        })
            .toList();
      });
    } else {
      debugPrint("Tasks data error: ${resp.body}");
    }
  }
  Future<void> _fetchScenariosStats(String token, String range) async {
    final url = Uri.parse('https://…/api/stats/scenarios?range=$range');
    final resp = await http.get(url, headers: {'Authorization':'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _scenariosData = data.map((e) => {
          'label': e['label'],
          'count': e['count']
        }).toList();
      });
    }
  }
  Future<void> _fetchUsersCountry(String token) async {
    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/stats/users-country');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      setState(() {
        _countryDist = jsonDecode(resp.body);
      });
    } else {
      debugPrint("Users-country error: ${resp.body}");
    }
  }

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlobalStatsHeader(),
          const SizedBox(height: 20),
          _buildHeadingRow(
            title: "Calls Chart",
            currentRange: _callsRange,
            onRangeChanged: (val) async {
              setState(() => _callsRange = val);
              final token =
              Provider.of<AuthProvider>(context, listen: false).token!;
              await _fetchCallsStats(token, _callsRange);
            },
          ),
          const SizedBox(height: 16),
          _buildBarChart(_callsData, Colors.blue),
          const SizedBox(height: 40),

          _buildHeadingRow(
            title: "Messages Chart",
            currentRange: _messagesRange,
            onRangeChanged: (val) async {
              setState(() => _messagesRange = val);
              final token =
              Provider.of<AuthProvider>(context, listen: false).token!;
              await _fetchMessagesStats(token, _messagesRange);
            },
          ),
          const SizedBox(height: 16),
          _buildBarChart(_messagesData, Colors.green),
          const SizedBox(height: 40),

          _buildHeadingRow(
            title: "Tasks Chart",
            currentRange: _tasksRange,
            onRangeChanged: (val) async {
              setState(() => _tasksRange = val);
              final token =
              Provider.of<AuthProvider>(context, listen: false).token!;
              await _fetchTasksStats(token, _tasksRange);
            },
          ),
          const SizedBox(height: 16),
          _buildBarChart(_tasksData, Colors.teal),
          const SizedBox(height: 40),

          _buildCountryDistribution(),
          const SizedBox(height: 30),
          _buildCountryMap(),
        ],
      ),
    );
  }

  Widget _buildGlobalStatsHeader() {
    final totalUsers = _globalStats['total_users'] ?? 0;
    final totalCalls = _globalStats['total_calls'] ?? 0;
    final totalTasks = _globalStats['total_tasks'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildGlobalItem("Users", totalUsers),
            _buildGlobalItem("Calls", totalCalls),
            _buildGlobalItem("Tasks", totalTasks),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalItem(String label, dynamic val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("$val", style: const TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildHeadingRow({
    required String title,
    required String currentRange,
    required ValueChanged<String> onRangeChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: currentRange,
          items: const [
            DropdownMenuItem(value: 'day', child: Text("Day")),
            DropdownMenuItem(value: 'week', child: Text("Week")),
            DropdownMenuItem(value: 'month', child: Text("Month")),
          ],
          onChanged: (val) {
            if (val != null) onRangeChanged(val);
          },
        ),
      ],
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data, Color color) {
    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(child: Text("No data available.")),
      );
    }

    final rodData = <BarChartRodData>[];
    final xLabels = <String>[];

    for (int i = 0; i < data.length; i++) {
      final label = data[i]['label'] ?? '';
      final count = (data[i]['count'] ?? 0).toDouble();
      xLabels.add(label);
      rodData.add(
        BarChartRodData(
          toY: count,
          width: 12,
          color: color,
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: _computeMaxY(rodData),
          barGroups: List.generate(rodData.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [rodData[index]],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final i = val.toInt();
                  if (i < 0 || i >= xLabels.length) return Container();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(xLabels[i], style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _computeMaxY(List<BarChartRodData> rods) {
    double maxY = 0;
    for (final r in rods) {
      if (r.toY > maxY) maxY = r.toY;
    }
    return maxY * 1.2;
  }

  Widget _buildCountryDistribution() {
    if (_countryDist.isEmpty) {
      return Card(
        elevation: 2,
        child: SizedBox(
          height: 200,
          child: Center(child: Text("No country distribution available.")),
        ),
      );
    }

    final List<Widget> items = [];
    _countryDist.forEach((countryCode, count) {
      items.add(
        ListTile(
          leading: const Icon(Icons.location_on),
          title: Text("Country: $countryCode, Users: $count"),
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Geographical Distribution",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildCountryMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Map (OpenStreetMap)",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(50, 15),
              initialZoom: 3.5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final Map<String, LatLng> countryCoords = {
      'CZ': LatLng(49.8175, 15.4730),
      'US': LatLng(39.8283, -98.5795),
      'FR': LatLng(46.2276, 2.2137),
      'ES': LatLng(40.4637, -3.7492),
      'RU': LatLng(61.5240, 105.3188),
      'CY': LatLng(35.1264, 33.4299),
    };

    final markers = <Marker>[];
    _countryDist.forEach((countryCode, count) {
      if (!countryCoords.containsKey(countryCode)) return;
      final latLon = countryCoords[countryCode]!;
      markers.add(
        Marker(
          point: latLon,
          width: 80,
          height: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 30),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    });
    return markers;
  }

  // If your server directly updates user voice
  Future<void> _updateUserVoiceId(String newVoiceId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?['user_id'];
    if (userId == null) return;
    final token = authProvider.token;
    final url = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/voice/$userId');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"voice_id": newVoiceId}),
      );
      if (response.statusCode == 200) {
        final updatedUser = jsonDecode(response.body);
        authProvider.setUser(updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User voice updated successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update user voice")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating voice: $e")),
      );
    }
  }

  // ---------------------------------------------------------
  //  BOTTOM NAV
  // ---------------------------------------------------------
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
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/scenarios');
        break;
      case 4:
      // Already here
        break;
    }
  }

  // ---------------------------------------------------------
  //  BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final translationProvider = Provider.of<TranslationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userId = user?['user_id'];

    final firstName = user?['first_name'] ?? '';
    final lastName = user?['last_name'] ?? '';
    final phoneNumber = user?['phone_number'] ?? '';
    final isAdmin = _isUserAdmin(user);

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
              // MAIN SCROLL
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    children: [
                      // Top user info with language selector
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9FBFE),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                    const Color.fromRGBO(105, 125, 255, 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child:
                                  const Icon(Icons.settings, color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$firstName $lastName",
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      phoneNumber.isNotEmpty
                                          ? '+$phoneNumber'
                                          : '---',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Language selector
                            DropdownButton<String>(
                              value: translationProvider.currentLang,
                              underline: const SizedBox(),
                              icon:
                              const Icon(Icons.language, color: Colors.indigo),
                              dropdownColor: Colors.white,
                              items: const [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text('English',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'es',
                                  child: Text('Español',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'fr',
                                  child: Text('Français',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'cs',
                                  child: Text('Čeština',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'de',
                                  child: Text('Deutsch',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'ru',
                                  child: Text('Русский',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'fa',
                                  child: Text('فارسی',
                                      style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'el',
                                  child: Text('Ελληνικά',
                                      style: TextStyle(color: Colors.black)),
                                ),
                              ],
                              onChanged: (String? newLang) async {
                                if (newLang != null) {
                                  final token = authProvider.token;
                                  await translationProvider.setLanguage(
                                      newLang, token!, user?['user_id']);
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // ASSISTANT SECTION
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildAssistantSection(),
                      ),

                      // USSD Info
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child:
                        UssdInfoWidget(phoneNumber: user?['phone_number']),
                      ),


                      // AGENT PROMPT
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildAgentPromptSection(),
                      ),

                      // AGENT PHONE PROMPT
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildAgentPhonePromptSection(),
                      ),

                      // VOICE CLONING
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildVoiceCloningSection(),
                      ),
                      // PROFILE SECTION
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildProfileSection(),
                      ),

                      // ADMIN
                      if (isAdmin)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildAdminPanelSection(),
                        ),

                      // LOGOUT
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        child: _buildLogoutButton(),
                      ),
                    ],
                  ),
                ),
              ),

              // BOTTOM NAV
              Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.indigo.shade300, width: 1),
                        ),
                      ),
                      child: BottomAppBar(
                        shape: const CircularNotchedRectangle(),
                        notchMargin: 8.0,
                        color: Colors.white,
                        elevation: 8.0,
                        child: SizedBox(
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.home_outlined),
                                color:
                                _selectedIndex == 0 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(0),
                              ),
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.call_outlined),
                                color:
                                _selectedIndex == 1 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(1),
                              ),
                              const SizedBox(width: 48),
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.fact_check_outlined),
                                color:
                                _selectedIndex == 3 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(3),
                              ),
                              IconButton(
                                iconSize: 30.0,
                                icon: const Icon(Icons.settings_outlined),
                                color:
                                _selectedIndex == 4 ? Colors.indigo : Colors.grey,
                                onPressed: () => _onItemTapped(4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // White bridging shape behind diamond
                    Positioned(
                      bottom: 48,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        child: Center(
                          child: CustomPaint(
                            painter: _TrianglePainter(),
                            child: const SizedBox(width: 90, height: 70),
                          ),
                        ),
                      ),
                    ),

                    // Big extra triangle
                    Positioned(
                      bottom: 60,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        child: Center(
                          child: CustomPaint(
                            painter: _BigTrianglePainter(),
                            child: const SizedBox(width: 110, height: 80),
                          ),
                        ),
                      ),
                    ),

                    // Diamond button w/ Chat Icon
                    Positioned(
                      bottom: 56,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: InkWell(
                            onTap: () => _onItemTapped(2),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.indigo.shade300,
                                  width: 1.0,
                                ),
                              ),
                              child: Transform.rotate(
                                angle: -math.pi / 4,
                                child: SvgPicture.asset(
                                  'assets/ChatIcon.svg',
                                  semanticsLabel: 'Chat Icon',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // AI-Chat label
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        child: Center(
                          child: Text(
                            translationProvider.t("AI-Chat"),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
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
      ),
    );
  }

  // ---------------------------------------------------------
  //  WIDGETS
  // ---------------------------------------------------------
  Widget _buildProfileSection() {
    final translationProvider = Provider.of<TranslationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null) return const SizedBox();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(105, 125, 255, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Text(
                translationProvider.t("YOUR_PROFILE"),
                style: const TextStyle(
                  fontFamily: 'DrukTextWideLCG',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle reject all calls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Reject All Calls"),
              Switch(
                value: _isRejectAll,
                onChanged: (val) {
                  setState(() {
                    _isRejectAll = val;
                  });
                  _toggleRejectAll(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Change Phone
          TextField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: translationProvider.t("NEW_PHONE_NUMBER"),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _changePhone,
            child: Text(
              translationProvider.t("CHANGE_PHONE"),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'DrukTextWideLCG',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Change Password
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: translationProvider.t("CHANGE_PASSWORD"),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _changePassword,
            child: Text(
              translationProvider.t("CHANGE_PASSWORD"),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'DrukTextWideLCG',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Delete Account
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade200,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _deleteAccount,
            child: Text(
              translationProvider.t("DELETE_ACCOUNT"),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'DrukTextWideLCG',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantSection() {
    final translationProvider = Provider.of<TranslationProvider>(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(105, 125, 255, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.support_agent, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Text(
                translationProvider.t("Choose your assistant"),
                style: const TextStyle(
                  fontFamily: 'DrukTextWideLCG',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grid of assistants
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: assistants.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemBuilder: (ctx, index) {
              final assistant = assistants[index];
              final isSelected =
                  chosenAgent?.startsWith(assistant['type']!) ?? false;

              return GestureDetector(
                onTap: () => _selectAgent(
                  assistant['type']!,
                  assistant['prompt']!,
                  assistant['audio']!,
                  assistant['voice']!,
                ),
                child: Card(
                  color: isSelected ? Colors.indigo.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: isSelected ? 4 : 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Assistant image
                        SizedBox(
                          height: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              assistant['image']!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          translationProvider.t(assistant['name']!),
                          style: TextStyle(
                            fontFamily: 'DrukTextWideLCG',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.indigo : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.indigo : Colors.grey,
                            size: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPhonePromptSection() {
    final translationProvider = Provider.of<TranslationProvider>(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(105, 125, 255, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with edit icon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phonelink_ring_outlined, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  translationProvider.t("Edit Agent Phone Prompt"),
                  style: const TextStyle(
                    fontFamily: 'DrukTextWideLCG',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: agentPhonePromptController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: translationProvider.t("Agent Phone Prompt"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _updatePhoneAgentPrompt,
            child: Text(
              translationProvider.t("Save Agent Phone Prompt"),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'DrukTextWideLCG',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAgentPromptSection() {
    final translationProvider = Provider.of<TranslationProvider>(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(105, 125, 255, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with edit icon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  translationProvider.t("Edit Agent Prompt"),
                  style: const TextStyle(
                    fontFamily: 'DrukTextWideLCG',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: agentPromptController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: translationProvider.t("Agent Prompt"),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _updateAgentPrompt,
            child: Text(
              translationProvider.t("Save Agent Prompt"),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'DrukTextWideLCG',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPanelSection() {
    final translationProvider = Provider.of<TranslationProvider>(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(105, 125, 255, 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                const Icon(Icons.admin_panel_settings, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  translationProvider.t("Admin Panel"),
                  style: const TextStyle(
                    fontFamily: 'DrukTextWideLCG',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DefaultTabController(
            length: 7,
            child: Column(
              children: [
                TabBar(
                  controller: _adminTabController,
                  isScrollable: true,
                  labelColor: Colors.indigo,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: translationProvider.t("Prompts")),
                    Tab(text: translationProvider.t("Users")),
                    Tab(text: translationProvider.t("Calls")),
                    Tab(text: translationProvider.t("Chats")),
                    Tab(text: translationProvider.t("Tasks")),
                    Tab(text: translationProvider.t("Agents")),
                    Tab(text: translationProvider.t("Stats")),
                    Tab(text: translationProvider.t("Scenario Admin")),
                    Tab(text: translationProvider.t("Scenarios Stats")),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _adminTabController,
                    children: [
                      _buildPromptsTab(),
                      _buildUsersTab(),
                      _buildPhoneCallsTab(),
                      _buildChatsTab(),
                      _buildTasksTab(),
                      _buildAgentsTab(),
                      _buildStatsTab(),
                      const ScenarioAdminWidget(),
                      const ScenarioStatsWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLogoutButton() {
    final translationProvider = Provider.of<TranslationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () {
        authProvider.logout();
        Navigator.pushReplacementNamed(context, '/');
      },
      icon: const Icon(Icons.logout, color: Colors.white, size: 24),
      label: Text(
        translationProvider.t("LOG OUT"),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontFamily: 'DrukTextWideLCG',
        ),
      ),
    );
  }

  // helper
  String _tr(String key) {
    final provider = Provider.of<TranslationProvider>(context, listen: false);
    return provider.t(key);
  }
}

// -----------------------------
//  SUB-PAGES for details
// -----------------------------

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const UserDetailsPage({Key? key, required this.userData}) : super(key: key);

  @override
  _UserDetailsPageState createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  bool _loading = true;

  List<dynamic> _userCalls = [];
  List<dynamic> _userTasks = [];
  List<dynamic> _userChats = [];
  Map<String, List<dynamic>> _chatMessages = {};
  List<dynamic> _userScenarios = [];
  List<dynamic> _userAgents = [];

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final userId = widget.userData['user_id'].toString();
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // 1) Fetch calls, tasks, chats, scenarios, agents
    final callsFut = http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/calls'),
      headers: headers,
    );
    final tasksFut = http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/tasks'),
      headers: headers,
    );
    final chatsFut = http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/chats'),
      headers: headers,
    );
    final scenFut = http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/$userId/scenarios'),
      headers: headers,
    );
    final agentsFut = http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/agents'),
      headers: headers,
    );

    final responses = await Future.wait([
      callsFut, tasksFut, chatsFut, scenFut, agentsFut
    ]);

    // 2) Decode
    if (responses[0].statusCode == 200) _userCalls = jsonDecode(responses[0].body);
    if (responses[1].statusCode == 200) _userTasks = jsonDecode(responses[1].body);
    if (responses[2].statusCode == 200) _userChats = jsonDecode(responses[2].body);
    if (responses[3].statusCode == 200) _userScenarios = jsonDecode(responses[3].body);
    if (responses[4].statusCode == 200) {
      final allAgents = jsonDecode(responses[4].body) as List;
      _userAgents = allAgents
          .where((a) => a['client_id'].toString() == userId)
          .toList();
    }

    // 3) For each chat, fetch its messages
    final messageFutures = _userChats.map((chat) {
      final chatId = chat['chat_id'].toString();
      return http.get(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/chat-messages/chat/$chatId'),
        headers: headers,
      );
    }).toList();

    final messageResponses = await Future.wait(messageFutures);
    final messagesMap = <String, List<dynamic>>{};
    for (int i = 0; i < messageResponses.length; i++) {
      final chatId = _userChats[i]['chat_id'].toString();
      if (messageResponses[i].statusCode == 200) {
        messagesMap[chatId] = jsonDecode(messageResponses[i].body);
      } else {
        messagesMap[chatId] = [];
      }
    }

    setState(() {
      _chatMessages = messagesMap;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final u = widget.userData;

    return Scaffold(
      appBar: AppBar(title: Text("${u['first_name']} ${u['last_name']}")),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          // --- User Info ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: u.entries
                    .where((e) => e.key != 'password')
                    .map((e) => Text("${e.key}: ${e.value}"))
                    .toList(),
              ),
            ),
          ),

          // --- Calls ---
          ExpansionTile(
            title: Text("Calls (${_userCalls.length})"),
            children: _userCalls.map((c) {
              return ListTile(
                title: Text("Call #${c['call_id']}"),
                subtitle: Text(c['summary'] ?? ''),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhoneCallDetailsPage(callData: c),
                  ),
                ),
              );
            }).toList(),
          ),

          // --- Tasks ---
          ExpansionTile(
            title: Text("Tasks (${_userTasks.length})"),
            children: _userTasks.map((t) {
              return ListTile(
                title: Text("Task #${t['task_id']}"),
                subtitle: Text(t['task_status'] ?? ''),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskDetailsPage(taskData: t),
                  ),
                ),
              );
            }).toList(),
          ),

          // --- Chats with Messages ---
          ExpansionTile(
            title: Text("Chats (${_userChats.length})"),
            children: _userChats.map((ch) {
              final chatId = ch['chat_id'].toString();
              final messages = _chatMessages[chatId] ?? [];

              return ExpansionTile(
                title: Text("Chat #$chatId"),
                children: messages.isEmpty
                    ? [const ListTile(title: Text("No messages."))]
                    : messages.map((m) {
                  final sender = m['sender_type'] ?? 'unknown';
                  final content = m['content'] ?? '';
                  return ListTile(
                    title: Text("$sender"),
                    subtitle: Text(content),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailsPage(chatData: ch),
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),

          // --- Scenarios ---
          ExpansionTile(
            title: Text("Scenarios (${_userScenarios.length})"),
            children: _userScenarios.map((s) {
              return ListTile(
                title: Text(s['name'] ?? 'Unnamed'),
                subtitle: Text("ID: ${s['scenario_id']}"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScenarioChatDetailsPage(scenario: s),
                  ),
                ),
              );
            }).toList(),
          ),

          // --- Agents ---
          ExpansionTile(
            title: Text("Agents (${_userAgents.length})"),
            children: _userAgents.map((a) {
              return ListTile(
                title: Text(a['agent_name'] ?? 'Agent ${a['agent_id']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ID: ${a['agent_id']}"),
                    Text("Prompt: ${a['prompt']}"),
                    Text("Chat Prompt: ${a['chat_prompt']}"),
                    Text("Voice ID: ${a['voice']}"),
                    Text("ElevenLabs ID: ${a['elevenlabs_id']}"),
                    Text("Chosen: ${a['chosen']}"),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
/// Shows the chat log for a specific scenario
class ScenarioChatDetailsPage extends StatefulWidget {
  final Map<String, dynamic> scenario;
  const ScenarioChatDetailsPage({Key? key, required this.scenario})
      : super(key: key);
  @override
  _ScenarioChatDetailsPageState createState() =>
      _ScenarioChatDetailsPageState();
}

class _ScenarioChatDetailsPageState extends State<ScenarioChatDetailsPage> {
  bool _loading = true;
  List _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final sid = widget.scenario['scenario_id'];
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final resp = await http.get(
      Uri.parse(
          'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/$sid/chats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      _messages = jsonDecode(resp.body);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: Text('Scenario: ${widget.scenario['name']}')),
      body: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final m = _messages[i];
          return ListTile(
            title: Text(m['sender'] ?? 'Unknown'),
            subtitle: Text(m['content'] ?? ''),
          );
        },
      ),
    );
  }
}
class PhoneCallDetailsPage extends StatefulWidget {
  final Map<String, dynamic> callData;
  const PhoneCallDetailsPage({Key? key, required this.callData})
      : super(key: key);

  @override
  State<PhoneCallDetailsPage> createState() => _PhoneCallDetailsPageState();
}

class _PhoneCallDetailsPageState extends State<PhoneCallDetailsPage> {
  Map<String, dynamic>? _maybeUserRecipient;
  Map<String, dynamic>? _maybeUserCaller;

  @override
  void initState() {
    super.initState();
    _lookupUserByPhone(widget.callData['recipient_phone'] ?? '')
        .then((u) => setState(() => _maybeUserRecipient = u));
    _lookupUserByPhone(widget.callData['caller_phone'] ?? '')
        .then((u) => setState(() => _maybeUserCaller = u));
  }

  Future<Map<String, dynamic>?> _lookupUserByPhone(String phone) async {
    if (phone.isEmpty) return null;
    try {
      final resp = await http.get(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/by-phone/$phone'),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (err) {
      print("Error looking up user by phone: $err");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.callData;
    final callId = call['call_id'];
    final summary = call['summary'] ?? '';
    final from = call['caller_phone'] ?? '';
    final to = call['recipient_phone'] ?? '';
    final transcript = call['transcript'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Call #$callId")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text("Call #$callId",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Summary: $summary", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text("From: $from"),
          if (_maybeUserCaller != null)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          UserDetailsPage(userData: _maybeUserCaller!)),
                );
              },
              child: Text("View user with phone $from"),
            ),
          Text("To: $to"),
          if (_maybeUserRecipient != null)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          UserDetailsPage(userData: _maybeUserRecipient!)),
                );
              },
              child: Text("View user with phone $to"),
            ),
          const Divider(),
          Text("Transcript:",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(transcript.isNotEmpty ? transcript : "No transcript"),
        ],
      ),
    );
  }
}

class ChatDetailsPage extends StatefulWidget {
  final Map<String, dynamic> chatData;
  const ChatDetailsPage({Key? key, required this.chatData}) : super(key: key);

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _isLoading = false;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    final cId = widget.chatData['chat_id'];
    try {
      final resp = await http.get(
        Uri.parse(
            'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/chat-messages/chat/$cId'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _messages = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        print("Error fetching chat messages: ${resp.body}");
      }
    } catch (err) {
      setState(() => _isLoading = false);
      print("Error: $err");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cId = widget.chatData['chat_id'];

    return Scaffold(
      appBar: AppBar(title: Text("Chat #$cId")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? const Center(child: Text("No messages in this chat."))
          : ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (ctx, i) {
          final msg = _messages[i];
          final sender = msg['sender_type'] ?? 'unknown';
          final content = msg['content'] ?? '';
          return ListTile(
            title: Text("$sender: $content"),
          );
        },
      ),
    );
  }
}

class TaskDetailsPage extends StatelessWidget {
  final Map<String, dynamic> taskData;
  const TaskDetailsPage({Key? key, required this.taskData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tId = taskData['task_id'];
    final tStatus = taskData['task_status'];
    final tText = taskData['task_text'] ?? '';
    final tPrompt = taskData['task_prompt'] ?? '';
    final summary = taskData['summary'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Task #$tId")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text("Task #$tId",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Status: $tStatus"),
          const Divider(),
          const Text("Task Text:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(tText.isNotEmpty ? tText : "No content"),
          const Divider(),
          const Text("Task Prompt:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(tPrompt.isNotEmpty ? tPrompt : "No prompt"),
          const Divider(),
          const Text("Summary:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(summary.isNotEmpty ? summary : "No summary"),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
//  The bridging shapes behind the bottom diamond button
// ----------------------------------------------------------------
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = ui.Path();
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
    final halfWidth = size.width / 2;
    final bottomVertex = Offset(halfWidth, halfHeight + 68);
    final leftVertex = Offset(halfWidth - 50, halfHeight + 19);
    final rightVertex = Offset(halfWidth + 50, halfHeight + 19);

    final fillPaint = Paint()
      ..color = const Color(0xFFF9FBFE)
      ..style = PaintingStyle.fill;
    final fillPath = ui.Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy)
      ..lineTo(rightVertex.dx, rightVertex.dy)
      ..close();

    canvas.drawPath(fillPath, fillPaint);

    final sidePaint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final leftSidePath = ui.Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(leftVertex.dx, leftVertex.dy);
    canvas.drawPath(leftSidePath, sidePaint);
    final rightSidePath = ui.Path()
      ..moveTo(bottomVertex.dx, bottomVertex.dy)
      ..lineTo(rightVertex.dx, rightVertex.dy);
    canvas.drawPath(rightSidePath, sidePaint);
  }

  @override
  bool shouldRepaint(_BigTrianglePainter oldDelegate) => false;
}
