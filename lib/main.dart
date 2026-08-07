import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MoradTkApp());
}

class MoradTkApp extends StatelessWidget {
  const MoradTkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MORAD_TK Smart Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  bool isOnline = false;
  bool isLocalConnected = false;
  String localDeviceIp = "";
  
  // بيانات السويتشات
  List<Map<String, dynamic>> switches = List.generate(12, (index) => {
    "id": index,
    "name": "سويتش ${index + 1}",
    "state": false,
    "color": Colors.blueAccent.value,
    "timerStart": "00:00",
    "timerEnd": "00:00",
    "timerEnabled": false,
  });

  // المدخلات المخصصة (Pins 34 & 35)
  int analog34Value = 0; // خزان المياه
  int analog35Value = 0; // جهد الشبكة
  
  String tankName = "خزان المياه الرئيسي";
  int tankColor = Colors.cyan.value;

  @override
  void initState() {
    super.initState();
    _discoverLocalDevice();
    _initFirebaseSync();
  }

  // 1. البحث المحلي عن اللوحة عبر الراوتر
  Future<void> _discoverLocalDevice() async {
    try {
      // محاولة الاتصال بالاسم المحلي للوحة MORAD_TK ESP32
      final response = await http.get(Uri.parse('http://morad-relay.local/api/config')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          isLocalConnected = true;
          localDeviceIp = "192.168.1.X"; // IP المكتشف
        });
      }
    } catch (_) {
      setState(() => isLocalConnected = false);
    }
  }

  // 2. المزامنة السحابية ومعرفة حالة اللوحة (Online/Offline)
  void _initFirebaseSync() {
    _dbRef.child('status/isOnline').onValue.listen((event) {
      setState(() {
        isOnline = (event.snapshot.value as bool?) ?? false;
      });
    });

    _dbRef.child('switches').onValue.listen((event) {
      if (event.snapshot.value != null) {
        List<dynamic> data = jsonDecode(jsonEncode(event.snapshot.value));
        setState(() {
          for (int i = 0; i < data.length && i < 12; i++) {
            switches[i]['state'] = data[i]['state'] ?? false;
            switches[i]['name'] = data[i]['name'] ?? "سويتش ${i + 1}";
            switches[i]['color'] = data[i]['color'] ?? Colors.blueAccent.value;
          }
        });
      }
    });

    // قراءات Pins 34 & 35
    _dbRef.child('inputs/pin34_tank').onValue.listen((event) {
      setState(() => analog34Value = (event.snapshot.value as int?) ?? 0);
    });
    _dbRef.child('inputs/pin35_voltage').onValue.listen((event) {
      setState(() => analog35Value = (event.snapshot.value as int?) ?? 0);
    });
  }

  // التحكم المتزامن المزدوج
  void _toggleSwitch(int index) {
    bool newState = !switches[index]['state'];
    setState(() => switches[index]['state'] = newState);

    // تحديث سحابي
    _dbRef.child('switches/$index/state').set(newState);

    // تحديث محلي مباشر إذا كانت اللوحة على نفس الراوتر
    if (isLocalConnected) {
      http.post(Uri.parse('http://$localDeviceIp/api/switch'), body: jsonEncode({'id': index, 'state': newState}));
    }
  }

  // نافذة إعدادات السويتش (الاسم، اللون، والمؤقت الزمني)
  void _openSwitchSettings(int index) {
    TextEditingController nameCtrl = TextEditingController(text: switches[index]['name']);
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إعدادات سويتش ${index + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم السويتش')),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('توقيت التشغيل Daily:'),
                TextButton(
                  onPressed: () async {
                    var picked = await showTimePicker(context: context, initialTime: startTime);
                    if (picked != null) startTime = picked;
                  },
                  child: const Text('تحديد الوقت'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                switches[index]['name'] = nameCtrl.text;
                switches[index]['timerStart'] = "${startTime.hour}:${startTime.minute}";
              });
              _dbRef.child('switches/$index').update({
                'name': nameCtrl.text,
                'timerStart': "${startTime.hour}:${startTime.minute}",
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double voltageVal = (analog35Value / 4095.0) * 250.0; // تحويل الجهد
    double tankLevelPercent = (analog34Value / 4095.0).clamp(0.0, 1.0); // نسبة الخزان

    return Scaffold(
      appBar: AppBar(
        title: const Text('MORAD_TK Smart Relay'),
        actions: [
          Icon(isLocalConnected ? Icons.wifi : Icons.wifi_off, color: isLocalConnected ? Colors.green : Colors.grey),
          const SizedBox(width: 10),
          Container(
            margin: const EdgeInsets.only(left: 15),
            child: CircleAvatar(
              radius: 6,
              backgroundColor: isOnline ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. قسم المدخلات المخصصة =================
            Row(
              children: [
                // شكل خزان المياه
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tankName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.settings, size: 16), onPressed: () {}),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 100,
                            width: 60,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.cyan, width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  height: 100 * tankLevelPercent,
                                  width: double.infinity,
                                  color: Colors.cyan.withOpacity(0.6),
                                ),
                                Center(child: Text("${(tankLevelPercent * 100).toInt()}%")),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // مقياس جهد الشبكة
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('جهد الشبكة (Pin 35)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Text('${voltageVal.toStringAsFixed(1)} V', style: const TextStyle(fontSize: 26, color: Colors.amber, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: voltageVal / 250.0, color: Colors.amber),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ================= 2. شبكة السويتشات (12 Relays) =================
            const Text('مفاتيح التحكم (12 Relays)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: 12,
              itemBuilder: (context, i) {
                bool isOn = switches[i]['state'];
                return Card(
                  color: isOn ? Color(switches[i]['color']).withOpacity(0.3) : const Color(0xFF1E1E1E),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // زر ضبط الاسم والتوقيت فوق السويتش
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onPressed: () => _openSwitchSettings(i),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleSwitch(i),
                        child: Icon(
                          isOn ? Icons.power_settings_new : Icons.power_off,
                          size: 36,
                          color: isOn ? Colors.greenAccent : Colors.grey,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          switches[i]['name'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
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
