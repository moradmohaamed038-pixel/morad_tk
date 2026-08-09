/// services/local_ws_service.dart
/// يطابق تماماً بروتوكول ws_local.h في الفيرموير:
///   → {"auth": "<password>"}
///   → {"command": "GET_METADATA"}
///   → {"relay": 1, "state": true}
///   ← {"relay": 1, "state": true, "source": "local"}  (بث تلقائي)
library;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';

class LocalWsService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messagesController;
  bool _authenticated = false;
  String? _connectedIp;

  bool get isConnected => _channel != null && _authenticated;
  String? get connectedIp => _connectedIp;

  Stream<Map<String, dynamic>> get messages =>
      _messagesController?.stream ?? const Stream.empty();

  /// يتصل باللوحة محلياً ويصادق بكلمة السر الخاصة بها.
  /// يُرجع true فقط لو نجحت المصادقة فعلياً (وليس فقط فتح القناة).
  Future<bool> connect(String ip, String wsPassword) async {
    await disconnect();

    try {
      final uri = Uri.parse('ws://$ip:${AppConstants.wsPort}');
      _channel = WebSocketChannel.connect(uri);
      _messagesController = StreamController<Map<String, dynamic>>.broadcast();
      _connectedIp = ip;

      final authCompleter = Completer<bool>();

      _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data.containsKey('auth')) {
              final ok = data['auth'] == 'ok';
              _authenticated = ok;
              if (!authCompleter.isCompleted) authCompleter.complete(ok);
              return;
            }
            _messagesController?.add(data);
          } catch (_) {
            // رسالة غير قابلة للتحليل — تُتجاهل بأمان
          }
        },
        onDone: () {
          _authenticated = false;
        },
        onError: (_) {
          _authenticated = false;
          if (!authCompleter.isCompleted) authCompleter.complete(false);
        },
      );

      _channel!.sink.add(jsonEncode({'auth': wsPassword}));

      return await authCompleter.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      _authenticated = false;
      return false;
    }
  }

  /// يرسل أمر تشغيل/إيقاف ريلاي. لا ينتظر تأكيداً هنا — طبقة connection_manager
  /// هي من تدير مهلة الـ 800ms والتحويل التلقائي للسحابة عند الفشل.
  void sendRelayCommand(int relayNumber, bool state) {
    if (!isConnected) return;
    _channel?.sink.add(jsonEncode({'relay': relayNumber, 'state': state}));
  }

  void requestMetadata() {
    if (!isConnected) return;
    _channel?.sink.add(jsonEncode({'command': 'GET_METADATA'}));
  }

  Future<void> disconnect() async {
    _authenticated = false;
    _connectedIp = null;
    await _channel?.sink.close();
    await _messagesController?.close();
    _channel = null;
    _messagesController = null;
  }
}
