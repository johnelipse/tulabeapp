import 'package:shared_preferences/shared_preferences.dart';

/// Client-side download quota, mirroring the web's localStorage
/// `tulabe-downloads` store: at most [downloadLimit] downloads per
/// [downloadWindowMin]-minute window. The server independently enforces the
/// same 5-per-6-min window per client IP, so this mirror prevents tapping into
/// "silent" server-side blocks.
class DownloadQuotaStore {
  static final DownloadQuotaStore instance = DownloadQuotaStore._();

  DownloadQuotaStore._();

  static const int downloadLimit = 5;
  static const int downloadWindowMin = 6;

  static const String _prefsKey = 'tulabe_downloads_v1';

  /// Returns the download timestamps from the current window, pruning anything
  /// expired (mirrors the web `store/downloads.ts` windowing check).
  Future<List<int>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - downloadWindowMin * 60 * 1000;
    final fresh = raw
        .map(int.tryParse)
        .whereType<int>()
        .where((t) => t > cutoff)
        .toList()
      ..sort();
    if (fresh.length != raw.length) {
      await prefs.setStringList(_prefsKey, fresh.map((t) => '$t').toList());
    }
    return fresh;
  }

  /// Remaining downloads in the current window, without recording.
  Future<int> remaining() async => downloadLimit - (await _load()).length;

  /// Gates [amount] (default 1) new download(s) against the quota, recording
  /// their timestamps when allowed. Mirrors web `checkAndRecord`.
  Future<DownloadQuotaCheck> checkAndRecord({int amount = 1}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ts = await _load();
    final prefs = await SharedPreferences.getInstance();

    if (ts.length + amount > downloadLimit) {
      final oldest = ts.isEmpty ? now : ts.first;
      final resetIn = (oldest + downloadWindowMin * 60 * 1000 - now) ~/ 1000;
      return DownloadQuotaCheck(
        allowed: false,
        remaining: downloadLimit - ts.length,
        resetInSeconds: resetIn < 0 ? 0 : resetIn,
      );
    }

    final updated = [...ts];
    for (var i = 0; i < amount; i++) {
      updated.add(now);
    }
    await prefs.setStringList(_prefsKey, updated.map((t) => '$t').toList());
    return DownloadQuotaCheck(
      allowed: true,
      remaining: downloadLimit - updated.length,
      resetInSeconds: 0,
    );
  }

  /// Formats a seconds count like the web's `Xm|Ys` helper.
  static String formatReset(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

class DownloadQuotaCheck {
  final bool allowed;
  final int remaining;
  final int resetInSeconds;

  const DownloadQuotaCheck({
    required this.allowed,
    required this.remaining,
    required this.resetInSeconds,
  });
}