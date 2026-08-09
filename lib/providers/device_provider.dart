/// providers/device_provider.dart
/// هذا هو المكوّن الذي يطبّق كل قرارات التصميم التي اتفقنا عليها:
///   - التحكم يُفضّل المسار المحلي دائماً عند توفره
///   - عند فشل المحلي خلال 800ms، يُعاد المحاولة صامتاً عبر السحابة تلقائياً
///   - بعد فشلين متتاليين خلال دقيقة، يظهر تنبيه خفيف (وليس مباشرة)
///   - عند عودة أي اتصال: يُطلب Snapshot كامل للحالة أولاً، ثم تُصفّى
///     الأوامر المعلّقة القديمة/المكررة، ثم تُرسل الباقية فقط
///   - الواجهة لا تتحدث أبداً بناءً على "الأمر المُرسل" — فقط من "الحالة الفعلية"
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/connection_status.dart';
import '../models/control_item.dart';
import '../models/discovered_device.dart';
import '../services/local_ws_service.dart';
import '../services/firebase_service.dart';
import '../services/command_queue_service.dart';
import '../services/local_storage_service.dart';
import '../services/mdns_discovery_service.dart';

class DeviceProvider extends ChangeNotifier {
  final LocalWsService _localWs = LocalWsService();
  final FirebaseService _firebase = FirebaseService();
  final CommandQueueService _queue = CommandQueueService();
  final LocalStorageService _localStorage = LocalStorageService();
  final MdnsDiscoveryService _mdns = MdnsDiscoveryService();

  late String deviceId;
  DiscoveredDevice? discovered;

  ConnectionStatus status = const ConnectionStatus();
  List<ControlItem> items = [];
  bool showLocalInstabilityWarning = false;

  final List<DateTime> _recentLocalFailures = [];

  StreamSubscription? _cloudConnSub;
  StreamSubscription? _deviceOnlineSub;
  StreamSubscription? _relayStateSub;
  StreamSubscription? _sensorStateSub;
  StreamSubscription? _localMsgSub;

  /// نقطة الدخول الرئيسية: تُستدعى بعد اختيار المستخدم للوحة من قائمة لوحاته
  /// المملوكة. لا تتطلب كلمة سر محلية يدوياً بعد الآن — تُجلب تلقائياً من
  /// السحابة (مسموح فقط للمالك بقراءتها، راجع database.rules.json)، ثم
  /// يُحاول الاتصال المحلي تلقائياً في الخلفية دون حجب الواجهة عن العمل
  /// سحابياً بالتوازي.
  Future<void> initForDevice(String deviceId, {DiscoveredDevice? discovered}) async {
    this.deviceId = deviceId;
    this.discovered = discovered;

    // الخانة الثانية: اتصال هاتف المستخدم بالسحابة — مستقلة تماماً
    _cloudConnSub = _firebase.cloudConnectionStream.listen((connected) {
      final wasConnected = status.isCloudConnected;
      status = status.copyWith(isCloudConnected: connected);
      notifyListeners();
      if (connected && !wasConnected) _onAnyConnectionRestored();
    });

    // الخانة الثالثة: حالة اللوحة نفسها (last_seen)
    _deviceOnlineSub = _firebase.deviceOnlineStream(deviceId).listen((online) {
      status = status.copyWith(isDeviceOnline: online);
      notifyListeners();
    });

    // الحالة الفعلية للريليهات — من السحابة (يعمل دائماً بغض النظر عن المحلي)
    _relayStateSub = _firebase.relayStateStream(deviceId).listen(_applyRelayStateSnapshot);
    _sensorStateSub = _firebase.sensorStateStream(deviceId).listen(_applySensorStateSnapshot);

    // تحميل بنية اللوحة (Capabilities) لبناء الواجهة — سحابياً كخط أساس
    final caps = await _firebase.fetchCapabilities(deviceId);
    _buildItemsFromCapabilities(caps);

    // محاولة الاتصال المحلي التلقائي بالخلفية (لا تُعطّل الواجهة السحابية
    // بالانتظار — القاعدة الذهبية: التطبيق يعمل سحابياً فوراً، ويترقّى
    // للمحلي تلقائياً بصمت فور توفره)
    _attemptAutoLocalConnect();
  }

  Future<void> _attemptAutoLocalConnect() async {
    try {
      final wsPassword = await _firebase.fetchWsPassword(deviceId);
      if (wsPassword == null) return; // اللوحة لم تتصل بالسحابة ولو مرة بعد

      final ip = discovered?.ip ?? await _mdns.resolveDeviceIp(deviceId);
      if (ip == null) return; // اللوحة ليست على نفس الشبكة حالياً — طبيعي تماماً

      await connectLocal(ip, wsPassword);
    } catch (_) {
      // فشل صامت — النظام يستمر بالعمل سحابياً بلا أي تعطيل للمستخدم
    }
  }

  /// يُستدعى من شاشة الاكتشاف بعد إدخال المستخدم كلمة سر التحكم المحلي
  Future<bool> connectLocal(String ip, String wsPassword) async {
    final ok = await _localWs.connect(ip, wsPassword);
    status = status.copyWith(isLocalConnected: ok);
    notifyListeners();

    if (ok) {
      _localMsgSub?.cancel();
      _localMsgSub = _localWs.messages.listen(_handleLocalMessage);
      // نطلب بنية اللوحة محلياً أيضاً — أدق وأسرع من نسخة السحابة المحتملة القِدَم
      _localWs.requestMetadata();
      _onAnyConnectionRestored();

      // نجاح فعلي (مصادقة صحيحة) → نحفظ بيانات الاتصال لإعادة الدخول السريع لاحقاً
      await _localStorage.saveLastDevice(SavedDevice(
        deviceId: deviceId,
        ip: ip,
        port: AppConstants.wsPort,
        wsPassword: wsPassword,
      ));
    }
    return ok;
  }

  // ---------------------------------------------------------------------
  // إرسال الأوامر — القاعدة الذهبية: محلي أولاً دائماً، ثم سحابة تلقائياً
  // ---------------------------------------------------------------------
  Future<void> sendRelayCommand(int relayIndex, bool state) async {
    final relayNumber = relayIndex + 1;

    if (status.isLocalConnected) {
      final confirmed = await _sendLocalWithTimeout(relayNumber, state);
      if (confirmed) return;
      _recordLocalFailure();
      // فشل المحلي رغم أنه "يبدو" متصلاً → تحويل صامت فوري للسحابة
    }

    if (status.isCloudConnected) {
      await _firebase.sendCommand(deviceId, relayNumber, state);
      return;
    }

    // لا محلي ولا سحابة متاحان الآن → يُحفظ للمحاولة عند عودة أي اتصال
    _queue.enqueue(relayNumber, state);
    notifyListeners();
  }

  Future<bool> _sendLocalWithTimeout(int relayNumber, bool state) async {
    final completer = Completer<bool>();
    late StreamSubscription sub;

    sub = _localWs.messages.listen((data) {
      if (data['relay'] == relayNumber && data['state'] == state) {
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    _localWs.sendRelayCommand(relayNumber, state);

    final result = await completer.future.timeout(
      const Duration(milliseconds: AppConstants.localCommandTimeoutMs),
      onTimeout: () => false,
    );
    await sub.cancel();
    return result;
  }

  void _recordLocalFailure() {
    final now = DateTime.now();
    _recentLocalFailures.add(now);
    _recentLocalFailures.removeWhere(
      (t) => now.difference(t).inMilliseconds > AppConstants.localInstabilityWindowMs,
    );
    if (_recentLocalFailures.length >= AppConstants.localInstabilityMaxFailures) {
      showLocalInstabilityWarning = true;
      notifyListeners();
    }
  }

  void dismissInstabilityWarning() {
    showLocalInstabilityWarning = false;
    _recentLocalFailures.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // إعادة المزامنة (Reconciliation) عند عودة أي اتصال
  // ---------------------------------------------------------------------
  Future<void> _onAnyConnectionRestored() async {
    // الخطوة 1: الحالة الفعلية القادمة من الـ Stream (محلي أو سحابي) لها
    // الأولوية دائماً — لا شيء إضافي مطلوب هنا لأن الـ Stream يُحدّث نفسه تلقائياً.

    // الخطوة 2: تصفية ثم إعادة إرسال الأوامر المعلّقة (إن وُجدت)
    if (_queue.isEmpty) return;
    final pending = _queue.drainValid();
    for (final cmd in pending) {
      await sendRelayCommand(cmd.relayNumber - 1, cmd.state);
    }
  }

  // ---------------------------------------------------------------------
  // معالجة تحديثات الحالة الواردة (محلياً أو سحابياً) — تُحدّث الواجهة فقط
  // ---------------------------------------------------------------------
  void _handleLocalMessage(Map<String, dynamic> data) {
    if (data.containsKey('items')) {
      _buildItemsFromCapabilities(data);
      return;
    }
    if (data.containsKey('relay') && data.containsKey('state')) {
      final relayNumber = data['relay'] as int;
      final state = data['state'] as bool;
      _updateRelayValue(relayNumber, state);
    }
  }

  void _applyRelayStateSnapshot(Map<String, dynamic> relays) {
    relays.forEach((key, value) {
      if (value is! Map) return;
      final relayNumber = int.tryParse(key.replaceAll('relay_', ''));
      if (relayNumber == null) return;
      final v = value['value'];
      _updateRelayValue(relayNumber, v == true || v == 1);
    });
  }

  void _applySensorStateSnapshot(Map<String, dynamic> sensors) {
    final tank = sensors['tank_level'];
    final grid = sensors['grid_status'];
    if (tank is Map) _updateItemValue('tank_level', (tank['value'] as num?) ?? 0);
    if (grid is Map) _updateItemValue('grid_status', (grid['value'] as num?) ?? 0);
    notifyListeners();
  }

  void _updateRelayValue(int relayNumber, bool state) {
    _updateItemValue('relay_${relayNumber}', state ? 1 : 0);
  }

  void _updateItemValue(String id, num value) {
    final idx = items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      items[idx].value = value;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // بناء الواجهة تلقائياً (Auto-UI) — أو الوضع الافتراضي عند غياب البيانات
  // ---------------------------------------------------------------------
  void _buildItemsFromCapabilities(Map<String, dynamic>? caps) {
    if (caps == null || caps['items'] == null) {
      items = _buildDefaultItems();
      notifyListeners();
      return;
    }
    final rawItems = List<Map<String, dynamic>>.from(
      (caps['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    items = rawItems.map((e) => ControlItem.fromCapabilityJson(e)).toList();
    notifyListeners();
  }

  List<ControlItem> _buildDefaultItems() {
    final list = <ControlItem>[];
    for (int i = 0; i < AppConstants.defaultRelayCount; i++) {
      list.add(ControlItem(
        id: 'relay_${i + 1}',
        type: ControlItemType.relaySwitch,
        relayIndex: i,
        value: 0,
        displayName: 'سويتش ${i + 1}',
        colorValue: 0xFF2196F3,
      ));
    }
    list.add(ControlItem(
      id: 'tank_level',
      type: ControlItemType.tank,
      value: 0,
      displayName: 'خزان المياه',
      colorValue: 0xFF03A9F4,
    ));
    list.add(ControlItem(
      id: 'grid_status',
      type: ControlItemType.indicator,
      value: 0,
      displayName: 'جهد الشبكة',
      colorValue: 0xFF4CAF50,
    ));
    return list;
  }

  @override
  void dispose() {
    _cloudConnSub?.cancel();
    _deviceOnlineSub?.cancel();
    _relayStateSub?.cancel();
    _sensorStateSub?.cancel();
    _localMsgSub?.cancel();
    _localWs.disconnect();
    super.dispose();
  }
}
