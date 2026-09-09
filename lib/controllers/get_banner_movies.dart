import 'package:tulabe/models/movies.dart';
import 'package:tulabe/services/api_client.dart';

class MovieBannerController {
  final ApiClient _apiClient = ApiClient();

  Future<List<HeroItem>> getBannerMovies() async {
    try {
      final response = await _apiClient.dio.get('/movies-hero');

      final data = response.data;
      List items = const [];
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          final rawItems = inner['items'];
          if (rawItems is List) items = rawItems;
        }
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(HeroItem.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('Error fetching movies: $e');
      rethrow;
    }
  }
}
