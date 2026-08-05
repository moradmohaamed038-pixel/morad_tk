import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase (تأكد من إدخال خيارات الويب/منصتك الفعلية عند الإنتاج)
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD-MockApiKeyForMoradTkProject",
        appId: "1:23456789:web:abcdef",
        messagingSenderId: "123456789",
        projectId: "morad-tk-iot-platform",
      ),
    );
  } catch (e) {
    // في حال كانت تهيئة السحابة تعمل مسبقاً أو قيد المحاكاة
  }

  runApp(const MoradTkApp());
}

class MoradTkApp extends StatelessWidget {
  const MoradTkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MORAD_TK IoT Platform',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,
      ),
      home: const ConnectionSetupScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({Key? key}) : super(key: key);

  @override
  _ConnectionSetupScreenState createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  bool _isScanning = false;
  final TextEditingController _passController = TextEditingController();

  void _scanForDevices() {
    setState(() {
      _isScanning = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _showAuthDialog("MORAD_TK_Relay_Hub (ws://morad-relay.local:81)");
      }
    });
  }

  void _showAuthDialog(String deviceName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("المصادقة المحلية للجهاز", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("أدخل كلمة المرور الخاصة باللوحة (افتراضياً: 12345678):", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "كلمة المرور",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(deviceAddress: "ws://morad-relay.local:81"),
                  ),
                );
              },
              child: const Text("دخول وحفظ الجلسة"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MORAD_TK - Device Discovery', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "اكتشاف اللوحة عبر الشبكة المحلية أو السحابة",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 10),
            const Text(
              "منصة MORAD_TK تتيح التحكم المحلي عبر الواي فاي والتحكم السحابي عبر Firebase.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanForDevices,
                icon: _isScanning 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_isScanning ? "جاري البحث في الشبكة..." : "بحث عن اللوحات المتاحة"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceItemConfig {
  final String id;          
  final String type;        
  String customName;        
  Color customColor;        
  bool state;               
  int rawValue;             
  String textValue;         
  bool alarmTriggered;      
  
  bool timerEnabled;
  TimeOfDay startTime;
  TimeOfDay endTime;
  List<bool> activeDays;

  DeviceItemConfig({
    required this.id,
    required this.type,
    required this.customName,
    required this.customColor,
    this.state = false,
    this.rawValue = 0,
    this.textValue = "",
    this.alarmTriggered = false,
    this.timerEnabled = false,
    this.startTime = const TimeOfDay(hour: 8, minute: 0),
    this.endTime = const TimeOfDay(hour: 17, minute: 0),
    List<bool>? activeDays,
  }) : activeDays = activeDays ?? List.generate(7, (index) => true);
}

class DashboardScreen extends StatefulWidget {
  final String deviceAddress;
  const DashboardScreen({Key? key, required this.deviceAddress}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<DeviceItemConfig> _deviceItems = [];
  bool _isInitializedFromDevice = false;

  WebSocketChannel? _channel;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  // مزامنة حالة العنصر وتحديثها في Firestore السحابي
  Future<void> _syncToCloud(DeviceItemConfig item) async {
    try {
      await FirebaseFirestore.instance
          .collection('morad_tk_devices')
          .doc('hub_main_unit')
          .collection('items')
          .doc(item.id)
          .set({
        'name': item.customName,
        'color': item.customColor.value,
        'state': item.state,
        'rawValue': item.rawValue,
        'textValue': item.textValue,
        'timerEnabled': item.timerEnabled,
        'startHour': item.startTime.hour,
        'startMinute': item.startTime.minute,
        'endHour': item.endTime.hour,
        'endMinute': item.endTime.minute,
        'activeDays': item.activeDays,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // التعامل مع حالة عدم الاتصال بالإنترنت بشكل صامت محلياً
    }
  }

  Future<void> _saveItemPreferences(DeviceItemConfig item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name_${item.id}', item.customName);
    await prefs.setInt('color_${item.id}', item.customColor.value);
    
    await prefs.setBool('timer_en_${item.id}', item.timerEnabled);
    await prefs.setInt('timer_sh_${item.id}', item.startTime.hour);
    await prefs.setInt('timer_sm_${item.id}', item.startTime.minute);
    await prefs.setInt('timer_eh_${item.id}', item.endTime.hour);
    await prefs.setInt('timer_em_${item.id}', item.endTime.minute);
    await prefs.setString('timer_days_${item.id}', jsonEncode(item.activeDays));

    // رفع التحديثات للسحابة
    await _syncToCloud(item);
  }

  Future<void> _loadItemPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var item in _deviceItems) {
        String? savedName = prefs.getString('name_${item.id}');
        int? savedColorVal = prefs.getInt('color_${item.id}');
        if (savedName != null && savedName.isNotEmpty) {
          item.customName = savedName;
        }
        if (savedColorVal != null) {
          item.customColor = Color(savedColorVal);
        }

        item.timerEnabled = prefs.getBool('timer_en_${item.id}') ?? false;
        int? sh = prefs.getInt('timer_sh_${item.id}');
        int? sm = prefs.getInt('timer_sm_${item.id}');
        if (sh != null && sm != null) {
          item.startTime = TimeOfDay(hour: sh, minute: sm);
        }
        int? eh = prefs.getInt('timer_eh_${item.id}');
        int? em = prefs.getInt('timer_em_${item.id}');
        if (eh != null && em != null) {
          item.endTime = TimeOfDay(hour: eh, minute: em);
        }
        String? daysJson = prefs.getString('timer_days_${item.id}');
        if (daysJson != null) {
          List<dynamic> decodedDays = jsonDecode(daysJson);
          item.activeDays = decodedDays.map((e) => e as bool).toList();
        }
      }
    });
  }

  void _connectToDevice() {
    if (_isConnected && _channel != null) return;
    
    Timer(const Duration(seconds: 1), () {
      if (!_isInitializedFromDevice && mounted) {
        _loadDefaultMockMetadata();
      }
    });

    try {
      _channel = WebSocketChannel.connect(Uri.parse(widget.deviceAddress));
      if (mounted) setState(() => _isConnected = true);

      _channel!.sink.add(jsonEncode({"command": "GET_METADATA"}));

      _channel!.stream.listen((message) {
        _handleIncomingData(message);
      }, onError: (error) {
        if (mounted) {
          setState(() => _isConnected = false);
          if (!_isInitializedFromDevice) _loadDefaultMockMetadata();
        }
      }, onDone: () {
        if (mounted) {
          setState(() => _isConnected = false);
          if (!_isInitializedFromDevice) _loadDefaultMockMetadata();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isConnected = false);
        if (!_isInitializedFromDevice) _loadDefaultMockMetadata();
      }
    }
  }

  void _handleIncomingData(String message) {
    try {
      final data = jsonDecode(message);
      setState(() {
        if (data.containsKey('items') && !_isInitializedFromDevice) {
          List<dynamic> itemsList = data['items'];
          _deviceItems = itemsList.map((item) {
            return DeviceItemConfig(
              id: item['id'],
              type: item['type'],
              customName: item['name'] ?? item['id'],
              customColor: Colors.blueAccent,
              state: item['state'] == 1,
            );
          }).toList();
          _isInitializedFromDevice = true;
          _loadItemPreferences();
        } 
      });
    } catch (e) {
      if (!_isInitializedFromDevice) {
        _loadDefaultMockMetadata();
      }
    }
  }

  void _loadDefaultMockMetadata() {
    setState(() {
      _deviceItems = [
        DeviceItemConfig(id: 'A34', type: 'sensor', customName: 'مستوى خزان المياه', customColor: Colors.cyan, rawValue: 2500),
        DeviceItemConfig(id: 'l1', type: 'indicator', customName: 'حالة المضخة الرئيسية', customColor: Colors.amber, state: true),
        DeviceItemConfig(id: 'al1', type: 'alarm', customName: 'إنذار ارتفاع الحرارة', customColor: Colors.redAccent, alarmTriggered: false),
        DeviceItemConfig(id: 't1', type: 'input', customName: 'اسم الموقع / رسالة الشاشة', customColor: Colors.purpleAccent, textValue: 'مزرعة رقم 1'),
        ...List.generate(12, (index) => DeviceItemConfig(
          id: 'v${index + 1}',
          type: 'relay',
          customName: 'Relay ${index + 1} (v${index + 1})',
          customColor: Colors.blueAccent,
          state: false,
        )),
      ];
      _isInitializedFromDevice = true;
      _loadItemPreferences();
    });
  }

  void _toggleRelay(DeviceItemConfig item) {
    setState(() {
      item.state = !item.state;
    });

    _syncToCloud(item);

    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({"id": item.id, "state": item.state ? 1 : 0}));
    }
  }

  void _sendTextValue(DeviceItemConfig item, String val) {
    setState(() {
      item.textValue = val;
    });
    _syncToCloud(item);

    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({"id": item.id, "value": val}));
    }
  }

  void _openSettings(DeviceItemConfig item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemSettingsScreen(
          item: item,
          onSave: (updatedItem) {
            setState(() {
              item.customName = updatedItem.customName;
              item.customColor = updatedItem.customColor;
              item.timerEnabled = updatedItem.timerEnabled;
              item.startTime = updatedItem.startTime;
              item.endTime = updatedItem.endTime;
              item.activeDays = updatedItem.activeDays;
            });
            _saveItemPreferences(item);

            if (_isConnected && _channel != null) {
              _channel!.sink.add(jsonEncode({
                "id": item.id,
                "timer_config": {
                  "enabled": item.timerEnabled,
                  "start": "${item.startTime.hour}:${item.startTime.minute}",
                  "end": "${item.endTime.hour}:${item.endTime.minute}",
                  "days": item.activeDays,
                }
              }));
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var sensors = _deviceItems.where((i) => i.type == 'sensor').toList();
    var indicators = _deviceItems.where((i) => i.type == 'indicator').toList();
    var alarms = _deviceItems.where((i) => i.type == 'alarm').toList();
    var inputs = _deviceItems.where((i) => i.type == 'input').toList();
    var relays = _deviceItems.where((i) => i.type == 'relay').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MORAD_TK Cloud Platform', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isConnected ? Colors.green : Colors.red),
                ),
                child: Text(
                  _isConnected ? "Cloud & Local Synced" : "Cloud Active / Local Offline",
                  style: TextStyle(color: _isConnected ? Colors.greenAccent : Colors.amberAccent, fontSize: 11),
                ),
              ),
            ),
          )
        ],
      ),
      body: !_isInitializedFromDevice
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sensors.map((sensor) {
                    double percentage = (sensor.rawValue / 4095.0) * 100.0;
                    if (percentage > 100) percentage = 100;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sensor.customColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                width: 60,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: sensor.customColor, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.black26,
                                ),
                              ),
                              Container(
                                width: 56,
                                height: 96 * (percentage / 100.0),
                                decoration: BoxDecoration(
                                  color: sensor.customColor.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Positioned(
                                top: 38,
                                child: Text(
                                  "${percentage.toStringAsFixed(0)}%",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(sensor.customName, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.settings, size: 18, color: Colors.white60),
                                      onPressed: () => _openSettings(sensor),
                                    ),
                                  ],
                                ),
                                Text("المعرف: (${sensor.id}) | القراءة: ${sensor.rawValue}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  if (indicators.isNotEmpty || alarms.isNotEmpty) ...[
                    const Text("المؤشرات وحالة النظام (Indicators & Alarms)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...indicators.map((ind) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ind.state ? ind.customColor : Colors.grey,
                                  boxShadow: ind.state ? [BoxShadow(color: ind.customColor, blurRadius: 8)] : [],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(ind.customName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          Text(ind.state ? "ACTIVE" : "IDLE", style: TextStyle(color: ind.state ? Colors.greenAccent : Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )),
                    ...alarms.map((alarm) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: alarm.alarmTriggered ? Colors.red.withOpacity(0.2) : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: alarm.alarmTriggered ? Colors.red : Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: alarm.alarmTriggered ? Colors.redAccent : Colors.grey),
                              const SizedBox(width: 12),
                              Text(alarm.customName, style: TextStyle(color: alarm.alarmTriggered ? Colors.redAccent : Colors.white70, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(alarm.alarmTriggered ? "WARNING!" : "NORMAL", style: TextStyle(color: alarm.alarmTriggered ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 10),
                  ],

                  if (inputs.isNotEmpty) ...[
                    const Text("حقول الإدخال السحابية (Cloud Inputs)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...inputs.map((inp) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inp.customName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(text: inp.textValue),
                            onSubmitted: (val) => _sendTextValue(inp, val),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "أدخل القيمة واضغط Enter للتحديث بالسحابة",
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 10),
                  ],

                  const Text("التحكم بالمخارج (12-Relay Cloud Control)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: relays.length,
                    itemBuilder: (context, index) {
                      final relay = relays[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: relay.state ? relay.customColor.withOpacity(0.3) : const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: relay.state ? relay.customColor : Colors.white12,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  onTap: () => _openSettings(relay),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(Icons.settings, size: 16, color: Colors.white60),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => _toggleRelay(relay),
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        relay.state ? Icons.power : Icons.power_off,
                                        color: relay.state ? Colors.cyanAccent : Colors.grey,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 2),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Text(
                                          relay.customName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: relay.state ? Colors.white : Colors.white60,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            relay.state ? "ON" : "OFF",
                                            style: TextStyle(
                                              color: relay.state ? Colors.greenAccent : Colors.redAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (relay.timerEnabled) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.timer, size: 12, color: Colors.amberAccent),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class ItemSettingsScreen extends StatefulWidget {
  final DeviceItemConfig item;
  final Function(DeviceItemConfig) onSave;

  const ItemSettingsScreen({
    Key? key,
    required this.item,
    required this.onSave,
  }) : super(key: key);

  @override
  _ItemSettingsScreenState createState() => _ItemSettingsScreenState();
}

class _ItemSettingsScreenState extends State<ItemSettingsScreen> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  late bool _timerEnabled;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<bool> _activeDays;

  final List<String> _dayNames = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

  final List<Color> _availableColors = [
    Colors.blueAccent,
    Colors.deepOrange,
    Colors.green,
    Colors.purple,
    Colors.amber,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.redAccent,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.customName);
    _selectedColor = widget.item.customColor;
    _timerEnabled = widget.item.timerEnabled;
    _startTime = widget.item.startTime;
    _endTime = widget.item.endTime;
    _activeDays = List.from(widget.item.activeDays);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRelay = widget.item.type == 'relay';

    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات العنصر (${widget.item.id})', style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("تعديل اسم العنصر (Custom Name):", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "أدخل الاسم الجديد",
              ),
            ),
            const SizedBox(height: 20),
            const Text("تخصيص لون العنصر في الواجهة:", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((color) {
                bool isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),

            if (isRelay) ...[
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("تفعيل المؤقت الزمني الأسبوعي:", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  Switch(
                    value: _timerEnabled,
                    onChanged: (val) => setState(() => _timerEnabled = val),
                  ),
                ],
              ),
              if (_timerEnabled) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectTime(context, true),
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text("البدء: ${_startTime.format(context)}"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectTime(context, false),
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text("الإيقاف: ${_endTime.format(context)}"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text("أيام العمل الأسبوعية:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (index) {
                    return FilterChip(
                      label: Text(_dayNames[index], style: const TextStyle(fontSize: 11)),
                      selected: _activeDays[index],
                      onSelected: (val) {
                        setState(() {
                          _activeDays[index] = val;
                        });
                      },
                    );
                  }),
                ),
              ],
            ],

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.item.customName = _nameController.text;
                  widget.item.customColor = _selectedColor;
                  widget.item.timerEnabled = _timerEnabled;
                  widget.item.startTime = _startTime;
                  widget.item.endTime = _endTime;
                  widget.item.activeDays = _activeDays;

                  widget.onSave(widget.item);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("حفظ ومزامنة مع السحابة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
