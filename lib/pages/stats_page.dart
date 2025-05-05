import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// For the OSM-based map
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';
import '../widgets/drawer_widget.dart';

/// Hard-coded example for countries -> user count -> map
/// Uses flutter_map (OpenStreetMap) with no API key needed.
class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _isLoading = true;

  // -- Global Stats --
  Map<String, dynamic> _globalStats = {}; // { total_users, total_calls, total_tasks }

  // -- Calls Data --
  String _callsRange = 'day';
  List<Map<String, dynamic>> _callsData = [];

  // -- Messages Data --
  String _messagesRange = 'day';
  List<Map<String, dynamic>> _messagesData = [];

  // -- Tasks Data --
  String _tasksRange = 'day';
  List<Map<String, dynamic>> _tasksData = [];

  // -- Users Country Distribution --
  /// Example: { "CZ": 5, "US": 10, "FR": 2, "ES": 3, "RU": 1, "CY": 0 }
  Map<String, dynamic> _countryDist = {};

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  Future<void> _fetchAllStats() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await Future.wait([
        _fetchGlobalStats(token),
        _fetchCallsData(token, _callsRange),
        _fetchMessagesData(token, _messagesRange),
        _fetchTasksData(token, _tasksRange),
        _fetchUsersCountry(token),
      ]);
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    setState(() => _isLoading = false);
  }

  // 1) Global stats
  Future<void> _fetchGlobalStats(String token) async {
    final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/stats/global');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      setState(() {
        _globalStats = jsonDecode(resp.body);
      });
    } else {
      debugPrint("Global stats error: ${resp.body}");
    }
  }

  // 2) Calls
  Future<void> _fetchCallsData(String token, String range) async {
    final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/stats/calls?range=$range');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _callsData = data.map<Map<String, dynamic>>((e) => {
          'label': e['label'],
          'count': e['count'],
        }).toList();
      });
    } else {
      debugPrint("Calls data error: ${resp.body}");
    }
  }

  // 3) Messages
  Future<void> _fetchMessagesData(String token, String range) async {
    final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/stats/messages?range=$range');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _messagesData = data.map<Map<String, dynamic>>((e) => {
          'label': e['label'],
          'count': e['count'],
        }).toList();
      });
    } else {
      debugPrint("Messages data error: ${resp.body}");
    }
  }

  // 4) Tasks
  Future<void> _fetchTasksData(String token, String range) async {
    final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/stats/tasks?range=$range');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        _tasksData = data.map<Map<String, dynamic>>((e) => {
          'label': e['label'],
          'count': e['count'],
        }).toList();
      });
    } else {
      debugPrint("Tasks data error: ${resp.body}");
    }
  }

  // 5) Users Country Distribution
  Future<void> _fetchUsersCountry(String token) async {
    final url = Uri.parse('https://axilon-be-dd0f4db1f2c9.herokuapp.com/api/stats/users-country');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      setState(() {
        _countryDist = jsonDecode(resp.body); // e.g. { "CZ": 5, "US": 10 }
      });
    } else {
      debugPrint("Users-country error: ${resp.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationProvider = Provider.of<TranslationProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;
    final bool isAdmin = (user?['is_admin'] == true || user?['is_admin'] == 1);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(translationProvider.t("Statistics"))),
        body: const Center(child: Text("You are not admin. No stats for you.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(translationProvider.t("Statistics")),
      ),
      drawer: buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildGlobalStatsHeader(),
            const SizedBox(height: 20),

            // Calls chart
            _buildHeadingRow(
              title: "Calls Chart",
              currentRange: _callsRange,
              onRangeChanged: (val) async {
                setState(() => _callsRange = val);
                final token = Provider.of<AuthProvider>(context, listen: false).token!;
                await _fetchCallsData(token, _callsRange);
              },
            ),
            const SizedBox(height: 16),
            _buildBarChart(_callsData, Colors.blue),
            const SizedBox(height: 40),

            // Messages chart
            _buildHeadingRow(
              title: "Messages Chart",
              currentRange: _messagesRange,
              onRangeChanged: (val) async {
                setState(() => _messagesRange = val);
                final token = Provider.of<AuthProvider>(context, listen: false).token!;
                await _fetchMessagesData(token, _messagesRange);
              },
            ),
            const SizedBox(height: 16),
            _buildBarChart(_messagesData, Colors.green),
            const SizedBox(height: 40),

            // Tasks chart
            _buildHeadingRow(
              title: "Tasks Chart",
              currentRange: _tasksRange,
              onRangeChanged: (val) async {
                setState(() => _tasksRange = val);
                final token = Provider.of<AuthProvider>(context, listen: false).token!;
                await _fetchTasksData(token, _tasksRange);
              },
            ),
            const SizedBox(height: 16),
            _buildBarChart(_tasksData, Colors.teal),
            const SizedBox(height: 40),

            // Geographic distribution => show list + map
            _buildCountryDistribution(),
            const SizedBox(height: 30),
            _buildCountryMap(),
          ],
        ),
      ),
    );
  }

  /// A row for heading + dropdown
  Widget _buildHeadingRow({
    required String title,
    required String currentRange,
    required ValueChanged<String> onRangeChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  /// Global stats row
  Widget _buildGlobalStatsHeader() {
    final totalUsers = _globalStats['total_users'] ?? 0;
    final totalCalls = _globalStats['total_calls'] ?? 0;
    final totalTasks = _globalStats['total_tasks'] ?? 0;

    // Display them in a simple row or card
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
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("$val", style: const TextStyle(fontSize: 18)),
      ],
    );
  }

  /// Simple bar chart for calls/messages/tasks
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
                    child: Text(
                      xLabels[i],
                      style: const TextStyle(fontSize: 10),
                    ),
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

  /// Simple country distribution listing
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

  /// The FlutterMap portion, no API key required, uses openstreetmap.org tiles
  Widget _buildCountryMap() {
    // Optionally, compute markers from _countryDist
    // For demonstration, let's just center on Europe
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
              initialCenter: LatLng(50, 15), // roughly central Europe
              initialZoom: 3.5,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
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

  /// Build a list of markers from `_countryDist`.
  /// For real usage, you'd store lat/long for each country.
  List<Marker> _buildMarkers() {
    // Quick country -> lat/lon map (center of country)
    final Map<String, LatLng> countryCoords = {
      'CZ': LatLng(49.8175, 15.4730),
      'US': LatLng(39.8283, -98.5795),
      'FR': LatLng(46.2276, 2.2137),
      'ES': LatLng(40.4637, -3.7492),
      'RU': LatLng(61.5240, 105.3188),
      'CY': LatLng(35.1264, 33.4299),
      // Add more as needed...
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
}
