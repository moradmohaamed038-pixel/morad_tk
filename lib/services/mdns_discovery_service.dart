/// services/mdns_discovery_service.dart
/// يبحث عن كل لوحات MORAD_TK المعلنة عبر mDNS على نفس شبكة الراوتر.
/// يطابق تماماً ما تُعلنه اللوحة في MORAD_TK.ino:
///   MDNS.addService("morad", "tcp", 81);
library;

import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';
import '../core/constants.dart';
import '../models/discovered_device.dart';

class MdnsDiscoveryService {
  Future<List<DiscoveredDevice>> scan({
    Duration timeout = const Duration(milliseconds: AppConstants.mdnsScanDurationMs),
  }) async {
    final MDnsClient client = MDnsClient();
    final List<DiscoveredDevice> found = [];

    try {
      await client.start();

      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(AppConstants.mdnsServiceType),
          )
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
            final deviceId = _extractDeviceId(srv.target);
            found.add(DiscoveredDevice(
              deviceId: deviceId,
              hostname: srv.target,
              ip: ip.address.address,
              port: srv.port,
            ));
          }
        }
      }
    } finally {
      client.stop();
    }

    // إزالة التكرار (قد تصل عدة استجابات لنفس اللوحة)
    final unique = <String, DiscoveredDevice>{};
    for (final d in found) {
      unique[d.deviceId] = d;
    }
    return unique.values.toList();
  }

  /// يستخرج deviceId من اسم المضيف "morad-<id>.local" → "<id>"
  String _extractDeviceId(String hostname) {
    final clean = hostname.replaceAll('.local.', '').replaceAll('.local', '');
    return clean.startsWith('morad-') ? clean.substring(6) : clean;
  }

  /// يبحث عن IP لوحة محددة بالذات (يُستخدم من ControlScreen للاتصال المحلي
  /// التلقائي بعد أن يكون المستخدم قد أثبت ملكيتها سحابياً بالفعل).
  /// يُرجع null لو لم توجد اللوحة على نفس الشبكة حالياً (خارج المنزل مثلاً)
  /// — وهذا وضع طبيعي تماماً وليس خطأ، النظام يعمل حينها سحابياً فقط.
  Future<String?> resolveDeviceIp(String deviceId, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final results = await scan(timeout: timeout);
    for (final d in results) {
      if (d.deviceId == deviceId) return d.ip;
    }
    return null;
  }
}
