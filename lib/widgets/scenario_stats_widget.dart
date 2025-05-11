import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';

class ScenarioStatsWidget extends StatefulWidget {
  const ScenarioStatsWidget({Key? key}) : super(key: key);

  @override
  _ScenarioStatsWidgetState createState() => _ScenarioStatsWidgetState();
}

class _ScenarioStatsWidgetState extends State<ScenarioStatsWidget> {
  String _range = 'day';
  bool _loading = true;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    final uri = Uri.parse(
        'https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/stats/scenarios?range=$_range'
    );
    final resp = await http.get(uri, headers: { 'Authorization': 'Bearer $token' });
    if (resp.statusCode == 200) {
      final List<dynamic> raw = jsonDecode(resp.body);
      setState(() {
        _data = raw.map((e) => {
          'label': e['label'],
          'count': e['count'],
        }).toList();
      });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Scenarios",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _range,
                items: const [
                  DropdownMenuItem(value: 'day', child: Text("Day")),
                  DropdownMenuItem(value: 'week', child: Text("Week")),
                  DropdownMenuItem(value: 'month', child: Text("Month")),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _range = v);
                    _fetch();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _data.isEmpty
              ? const Center(child: Text("No data available."))
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _data.length) return const SizedBox();
                        return Text(_data[i]['label'], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(_data.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (_data[i]['count'] as num).toDouble(),
                        width: 12,
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
