import 'package:flutter/foundation.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

/// VJ directory ("THE VJs") — mirrors the web `/vjs` page: a searchable grid
/// of VJs wired to `GET /api/vjs` (server-side search, ordered by priority /
/// live content / name).
class VJsController extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<VJ> _vjs = const [];
  bool _loading = false;
  String? _error;
  String _search = '';

  List<VJ> get vjs => _vjs;
  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;

  Future<void> load({String search = ''}) async {
    _search = search;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{'limit': 100};
      final trimmed = search.trim();
      if (trimmed.isNotEmpty) params['search'] = trimmed;
      final response = await _apiClient.dio.get('/vjs', queryParameters: params);
      final body = response.data;
      List raw = const [];
      if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final list = data['vjs'];
          if (list is List) raw = list;
        }
      }
      _vjs = raw
          .whereType<Map<String, dynamic>>()
          .map(VJ.fromJson)
          .toList(growable: false);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }
}