import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/auth_provider.dart';
import '../providers/translation_provider.dart';

class EditScenarioPage extends StatefulWidget {
  final String scenarioId;
  const EditScenarioPage({Key? key, required this.scenarioId}) : super(key: key);

  @override
  _EditScenarioPageState createState() => _EditScenarioPageState();
}

class _EditScenarioPageState extends State<EditScenarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _schedStartCtrl = TextEditingController();
  final _execTimeCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();

  String _type = 'voice';
  String _callMode = 'single';
  String _interval = 'Hourly';
  DateTime? _schedStart, _execTime, _till;
  bool _loading = true, _submitting = false;

  final _types = ['voice'];
  final _modes = ['single','repeating'];
  final _intervals = ['Hourly','Daily','Weekly'];
  final _intervalMap = {'Hourly':'1 hour','Daily':'1 day','Weekly':'1 week'};

  @override
  void initState() {
    super.initState();
    _loadScenario();
  }

  Future<void> _loadScenario() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final resp = await http.get(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/get/${widget.scenarioId}'),
      headers: {'Authorization':'Bearer ${auth.token}'},
    );
    if (resp.statusCode == 200) {
      final s = jsonDecode(resp.body);
      setState(() {
        _nameCtrl.text = s['scenario_name'] ?? '';
        _summaryCtrl.text = s['summary'] ?? '';
        _type = s['scenario_type'] ?? 'voice';
        _promptCtrl.text = s['prompt_value'] ?? '';
        _schedStart = s['scheduled_start']!=null ? DateTime.parse(s['scheduled_start']) : null;
        _schedStartCtrl.text = _schedStart!=null ? DateFormat('yyyy-MM-dd HH:mm').format(_schedStart!) : '';
        _execTime = s['exec_time']!=null ? DateTime.parse(s['exec_time']) : null;
        _execTimeCtrl.text = _execTime!=null ? DateFormat('yyyy-MM-dd HH:mm').format(_execTime!) : '';
        _till = s['till']!=null ? DateTime.parse(s['till']) : null;
        _tillCtrl.text = _till!=null ? DateFormat('yyyy-MM-dd HH:mm').format(_till!) : '';
        final rep = s['repeating'] == true;
        _callMode = rep ? 'repeating' : 'single';
        // find interval key
        _intervalMap.forEach((k,v){
          if(v==s['scheduled_interval']) _interval=k;
        });
      });
    }
    setState(() => _loading = false);
  }

  Future<DateTime?> _pickDateTime() async {
    final d = await showDatePicker(
        context:context, initialDate:DateTime.now(), firstDate:DateTime(2000), lastDate:DateTime(2100));
    if(d==null) return null;
    final t = await showTimePicker(context:context, initialTime:TimeOfDay.now());
    if(t==null) return null;
    return DateTime(d.year,d.month,d.day,t.hour,t.minute);
  }

  Future<void> _submit() async {
    if(!_formKey.currentState!.validate()) return;
    setState(()=>_submitting=true);
    final auth = Provider.of<AuthProvider>(context, listen:false);
    final body = {
      'scenario_name':_nameCtrl.text.trim(),
      'summary':_summaryCtrl.text.trim(),
      'status':true,
      'scenario_type':_type,
      'add_to_voice_prompt': _type=='voice',
      'prompt_value':_promptCtrl.text.trim(),
    };
    final resp = await http.put(
      Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/scenarios/update/${widget.scenarioId}'),
      headers:{'Content-Type':'application/json','Authorization':'Bearer ${auth.token}'},
      body: jsonEncode(body),
    );
    setState(()=>_submitting=false);
    if(resp.statusCode==200){
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Provider.of<TranslationProvider>(context,listen:false).t('Scenario updated'))));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${resp.body}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<TranslationProvider>(context);
    if(_loading) return const Scaffold(body: Center(child:CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('Изменить сценарий')),
        backgroundColor: const Color(0xFFE8EDFF),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key:_formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:[
                // name
                TextFormField(
                    controller:_nameCtrl,
                    decoration: InputDecoration(
                        filled:true, fillColor:Colors.white,
                        hintText:t.t('Name'),
                        border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                    ),
                    validator:(v)=>v==null||v.isEmpty?t.t('Required'):null
                ),
                const SizedBox(height:12),
                // summary
                TextFormField(
                    controller:_summaryCtrl,
                    minLines:3,maxLines:5,
                    decoration: InputDecoration(
                        filled:true, fillColor:Colors.white,
                        hintText:t.t('Summary'),
                        border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                    ),
                    validator:(v)=>v==null||v.isEmpty?t.t('Required'):null
                ),
                const SizedBox(height:12),
                // type dropdown
                DropdownButtonFormField<String>(
                  value:_type,
                  decoration:InputDecoration(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(22),borderSide:BorderSide.none)),
                  items:_types.map((e)=>DropdownMenuItem(value:e,child:Text(t.t(e).toUpperCase()))).toList(),
                  onChanged:(v)=>setState((){
                    _type=v!;
                    _callMode='single';
                    _promptCtrl.clear();
                    _schedStartCtrl.clear();
                    _execTimeCtrl.clear();
                    _tillCtrl.clear();
                  }),
                ),
                const SizedBox(height:12),
                // conditional fields...
                if(_type=='voice')...[
                  TextFormField(
                      controller:_promptCtrl,
                      decoration: InputDecoration(
                          filled:true, fillColor:Colors.white,
                          hintText:t.t('Prompt Value'),
                          border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                      ),
                      validator:(v)=>v==null||v.isEmpty?t.t('Required'):null
                  ),
                  const SizedBox(height:12),
                ] else if(_type=='call')...[
                  DropdownButtonFormField<String>(
                    value:_callMode,
                    decoration:InputDecoration(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(22),borderSide:BorderSide.none)),
                    items:_modes.map((e)=>DropdownMenuItem(value:e,child:Text(t.t(e).toUpperCase()))).toList(),
                    onChanged:(v)=>setState((){
                      _callMode=v!;
                      _promptCtrl.clear();
                      _schedStartCtrl.clear();
                      _execTimeCtrl.clear();
                      _tillCtrl.clear();
                    }),
                  ),
                  const SizedBox(height:12),
                  if(_callMode=='repeating')...[
                    TextFormField(
                        controller:_schedStartCtrl,
                        readOnly:true,
                        decoration: InputDecoration(
                            filled:true, fillColor:Colors.white,
                            hintText:t.t('Scheduled Start'),
                            border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                        ),
                        onTap:()async{
                          final dt=await _pickDateTime();
                          if(dt!=null) setState((){
                            _schedStart=dt;
                            _schedStartCtrl.text=DateFormat('yyyy-MM-dd HH:mm').format(dt);
                          });
                        },
                        validator:(v)=>v==null||v.isEmpty?t.t('Required'):null
                    ),
                    const SizedBox(height:12),
                    DropdownButtonFormField<String>(
                        value:_interval,
                        decoration:InputDecoration(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(22),borderSide:BorderSide.none)),
                        items:_intervals.map((e)=>DropdownMenuItem(value:e,child:Text(t.t(e)))).toList(),
                        onChanged:(v)=>setState(()=>_interval=v!)
                    ),
                    const SizedBox(height:12),
                    TextFormField(
                      controller:_tillCtrl,
                      readOnly:true,
                      decoration: InputDecoration(
                          filled:true, fillColor:Colors.white,
                          hintText:t.t('Till (optional)'),
                          border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                      ),
                      onTap:()async{
                        final dt=await _pickDateTime();
                        if(dt!=null) setState((){
                          _till=dt;
                          _tillCtrl.text=DateFormat('yyyy-MM-dd HH:mm').format(dt);
                        });
                      },
                    ),
                    const SizedBox(height:12),
                  ] else ...[
                    TextFormField(
                        controller:_execTimeCtrl,
                        readOnly:true,
                        decoration: InputDecoration(
                            filled:true, fillColor:Colors.white,
                            hintText:t.t('Execution Time'),
                            border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                        ),
                        onTap:()async{
                          final dt=await _pickDateTime();
                          if(dt!=null) setState((){
                            _execTime=dt;
                            _execTimeCtrl.text=DateFormat('yyyy-MM-dd HH:mm').format(dt);
                          });
                        },
                        validator:(v)=>v==null||v.isEmpty?t.t('Required'):null
                    ),
                    const SizedBox(height:12),
                  ],
                  TextFormField(
                      controller:_promptCtrl,
                      decoration: InputDecoration(
                          filled:true, fillColor:Colors.white,
                          hintText:t.t('Prompt Value'),
                          border:OutlineInputBorder(borderRadius:BorderRadius.circular(22), borderSide:BorderSide.none)
                      ),
                      validator:(v)=>v==null||v.isEmpty?t.t('Required'):null
                  ),
                  const SizedBox(height:12),
                ],
                ElevatedButton(
                  onPressed:_submitting?null:_submit,
                  child: Text(_submitting?t.t('Submitting...'):t.t('Save')),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical:16),
                      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
