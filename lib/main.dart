import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCn9tedGF...", 
      appId: "1:126630633315:web:...", 
      messagingSenderId: "126630633315",
      projectId: "morad-tk",
      authDomain: "morad-tk.firebaseapp.com",
      storageBucket: "morad-tk.appspot.com",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MORAD_TK Cloud Platform',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.cyanAccent,
      ),
      home: const ConnectionSetupScreen(),
    );
  }
}

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  bool _isScanning = false;

  void _scanForDevices() async {
    setState(() {
      _isScanning = true;
    });

    bool isDeviceReachable = await _pingLocalDevice("ws://morad-relay.local:81");

    if (!mounted) return;

    setState(() {
      _isScanning = false;
    });

    if (isDeviceReachable) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen(wsUrl: "ws://morad-relay.local:81")),
      );
    } else {
      _showErrorDialog("لم يتم العثور على اللوحة محلياً. تأكد من إيقاف الـ VPN وأن الهاتف واللوحة على نفس شبكة الواي فاي.");
    }
  }

  Future<bool> _pingLocalDevice(String url) async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready.timeout(const Duration(seconds: 3));
      channel.sink.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("خطأ في الاتصال", style: TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MORAD_TK - Device Discovery"),
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "اكتشاف اللوحة عبر الشبكة المحلية أو السحابة",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 10),
            const Text(
              "تتيح التحكم المحلي عبر الواي فاي والتحكم عبر منصة MORAD_TK Firebase السحابي.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A607A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _isScanning ? null : _scanForDevices,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: Colors.cyanAccent),
                  label: Text(
                    _isScanning ? "جاري البحث..." : "بحث عن اللوحات المتاحة",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String wsUrl;
  const DashboardScreen({super.key, required this.wsUrl});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late WebSocketChannel _channel;
  double tankLevel = 61.0;
  int tankRaw = 2500;
  bool mainPumpActive = true;
  bool highTempAlarm = false;
  String siteName = "مزرعة رقم 1";
  List<bool> relays = List.generate(12, (index) => false);
  
  List<String> relayNames = List.generate(12, (index) => "Relay ${index + 1}");
  List<int> relayTimers = List.generate(12, (index) => 0);

  bool isCloudOnline = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _checkCloudStatus();
  }

  void _checkCloudStatus() {
    FirebaseFirestore.instance
        .collection('devices')
        .doc('morad_relay_hub')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null && data['last_seen'] != null) {
          Timestamp lastSeen = data['last_seen'];
          DateTime lastSeenDate = lastSeen.toDate();
          bool online = DateTime.now().difference(lastSeenDate).inMinutes < 2;
          setState(() {
            isCloudOnline = online;
          });
        }
      }
    });
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(widget.wsUrl));
      _channel.stream.listen((message) {
        final data = jsonDecode(message);
        setState(() {
          if (data['tank'] != null) tankLevel = data['tank'].toDouble();
          if (data['raw'] != null) tankRaw = data['raw'];
          if (data['pump'] != null) mainPumpActive = data['pump'];
          if (data['temp_alarm'] != null) highTempAlarm = data['temp_alarm'];
          if (data['relays'] != null) relays = List<bool>.from(data['relays']);
        });
      });
    } catch (e) {
      // الاتصال المحلي مفصول
    }
  }

  void _toggleRelay(int index, bool value) {
    setState(() {
      relays[index] = value;
    });
    _channel.sink.add(jsonEncode({"relay": index + 1, "state": value ? 1 : 0}));
  }

  void _showRelaySettingsDialog(int index) {
    final TextEditingController nameController = TextEditingController(text: relayNames[index]);
    final TextEditingController timerController = TextEditingController(text: relayTimers[index].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("تخصيص Relay ${index + 1}", style: const TextStyle(color: Colors.cyanAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("اسم السويتش:", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 5),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 15),
            const Text("مؤقت التشغيل التلقائي (بالثواني):", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 5),
            TextField(
              controller: timerController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              setState(() {
                relayNames[index] = nameController.text;
                relayTimers[index] = int.tryParse(timerController.text) ?? 0;
              });
              Navigator.pop(context);
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MORAD_TK Cloud Platform"),
        backgroundColor: const Color(0xFF1F1F1F),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCloudOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  border: Border.all(color: isCloudOnline ? Colors.greenAccent : Colors.redAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCloudOnline ? "Cloud Active / Local Connected" : "Cloud Offline / Local Connected",
                  style: TextStyle(color: isCloudOnline ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
                ),
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 90 * (tankLevel / 100),
                          color: Colors.blueAccent,
                          alignment: Alignment.center,
                          child: Text("${tankLevel.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("مستوى خزان المياه", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.settings, color: Colors.white70), onPressed: () {}),
                          ],
                        ),
                        Text("القراءة: $tankRaw | (A34) :المعرف", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          const Text("المؤشرات وحالة النظام (Indicators & Alarms)", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: mainPumpActive ? Colors.amber : Colors.grey)),
                    const SizedBox(width: 10),
                    const Text("حالة المضخة الرئيسية", style: TextStyle(color: Colors.white)),
                  ],
                ),
                const Text("ACTIVE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 15),

          const Text("حقول الإدخال السحابية (Cloud Inputs)", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: siteName),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "اسم الموقع / رسالة الشاشة",
              labelStyle: const TextStyle(color: Colors.white60),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white30), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),

          const Text("التحكم بالمخارج (12-Relay Cloud Control)", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              bool isOn = relays[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isOn ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(isOn ? Icons.power : Icons.power_off, color: isOn ? Colors.greenAccent : Colors.redAccent, size: 20),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white54, size: 18),
                          onPressed: () => _showRelaySettingsDialog(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    Text(relayNames[index], style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                    Text(isOn ? "ACTIVE" : "OFF", style: TextStyle(color: isOn ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    Switch(
                      value: isOn,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) => _toggleRelay(index, val),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
