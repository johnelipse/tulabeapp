import 'content.dart';
import 'movie.dart';
import 'search.dart';
import 'series.dart';

// Re-export the API-matching models so `package:tulabe/models/movies.dart`
// exposes everything the app needs to consume the Go backend. `playlist.dart`
// (the API Playlist) is intentionally NOT re-exported here because the UI
// keeps its own lightweight `Playlist` below; import it directly when needed.
export 'cast.dart';
export 'content.dart';
export 'genre.dart';
export 'movie.dart';
export 'search.dart';
export 'series.dart';
export 'vj.dart';

/// Simple data model representing a movie shown in cards/lists.
///
/// Kept source-compatible with the existing UI (fields: [title], [subtitle],
/// [imageUrl], [badge]) while providing adapters to map backend models into
/// these card items.
class Movie {
  final String title;
  final String? subtitle; // e.g. "2026 - Action"
  final String imageUrl;
  final String? badge; // e.g. "VJ JUNIOR", "VJ ICEP"
  final String? id;

  const Movie({
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.badge,
    this.id,
  });

  /// Build a card item from a backend [StreamMovie].
  factory Movie.fromStreamMovie(StreamMovie m) {
    final year = m.releaseYear > 0 ? '${m.releaseYear}' : '';
    final genres = m.genres;
    final subtitle = [if (year.isNotEmpty) year, if (genres.isNotEmpty) genres.join(', ')]
        .join(' - ');
    return Movie(
      id: m.id,
      title: m.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      imageUrl: m.thumbnailUrl,
      badge: m.firstVjName,
    );
  }

  /// Build a card item from a backend [Series].
  factory Movie.fromSeries(Series s) {
    final year = s.releaseYear > 0 ? '${s.releaseYear}' : '';
    final genres = _splitComma(s.genreNames);
    final subtitle = [if (year.isNotEmpty) year, if (genres.isNotEmpty) genres.join(', ')]
        .join(' - ');
    return Movie(
      id: '${s.id}',
      title: s.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      imageUrl: s.posterUrl,
      badge: _firstComma(s.vjNames),
    );
  }

  /// Build a card item from a backend [SearchResult].
  factory Movie.fromSearchResult(SearchResult r) {
    final genre = _splitComma(r.genreNames);
    final subtitle = [
      if (r.releaseYear > 0) '${r.releaseYear}',
      if (genre.isNotEmpty) genre.join(', '),
    ].join(' - ');
    return Movie(
      id: r.id,
      title: r.title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      imageUrl: r.thumbnailUrl,
      badge: _firstComma(r.vjNames),
    );
  }

  /// Build a card item from a backend [FavoriteItem].
  factory Movie.fromFavoriteItem(FavoriteItem f) {
    return Movie(
      id: f.contentId,
      title: f.title,
      subtitle: f.releaseYear > 0 ? '${f.releaseYear}' : null,
      imageUrl: f.thumbnailUrl,
    );
  }

  /// Build a card item from a backend [PlaylistItem] (in models/playlist.dart).
  factory Movie.fromPlaylistItem(Object item, {String? thumbnail, String? title}) {
    // Generic mapping used by the playlist detail screen; prefers the passed
    // values, otherwise introspects common getters.
    String str(Object? v, String key) {
      if (v is! Map) return '';
      return v[key]?.toString() ?? '';
    }

    final map = item is Map ? item : null;
    final genre = _splitComma(str(map, 'genre_names'));
    final year = (map?['release_year'] as num?)?.toInt() ?? 0;
    final yearStr = year > 0 ? '$year' : '';
    final subtitle = [
      yearStr,
      if (genre.isNotEmpty) genre.join(', '),
    ].where((s) => s.isNotEmpty).join(' - ');
    return Movie(
      id: str(map, 'id'),
      title: title ?? str(map, 'title'),
      subtitle: subtitle.isEmpty ? null : subtitle,
      imageUrl: thumbnail ?? str(map, 'thumbnail_url'),
      badge: _firstComma(str(map, 'vj_names')),
    );
  }

  static List<String> _splitComma(String value) {
    if (value.isEmpty) return const <String>[];
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String? _firstComma(String value) {
    final parts = _splitComma(value);
    return parts.isEmpty ? null : parts.first;
  }
}

/// Extended model used for the big featured hero banner at the top.
class FeaturedMovie {
  final String tag; // e.g. "VJ ICEP"
  final String title;
  final String description;
  final String imageUrl;
  final String year;
  final String genre;
  final String duration;

  const FeaturedMovie({
    required this.tag,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.year,
    required this.genre,
    required this.duration,
  });

  /// Build a hero banner entry from a backend [HeroItem].
  factory FeaturedMovie.fromHeroItem(HeroItem h) {
    return FeaturedMovie(
      tag: _firstComma(h.vjNames) ?? 'LATEST',
      title: h.title,
      description: h.description,
      imageUrl: h.imageUrl,
      year: h.releaseYear > 0 ? '${h.releaseYear}' : '',
      genre: h.genreNames,
      duration: h.durationSeconds > 0 ? '${h.durationSeconds ~/ 60} min' : '',
    );
  }

  static String? _firstComma(String value) {
    if (value.isEmpty) return null;
    return value.split(',')[0].trim();
  }
}

/// Static list of years shown in the "Browse by Year" section.
class YearOptions {
  static const List<int> years = [
    2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026,
  ];
}

/// Static sample VJ data for the Available VJs section (UI only).
class SampleVJ {
  final String name;
  final bool isActive;
  const SampleVJ({required this.name, this.isActive = false});

  static const List<SampleVJ> all = [
    SampleVJ(name: 'VJ Junior', isActive: true),
    SampleVJ(name: 'VJ Icep', isActive: true),
    SampleVJ(name: 'VJ Manchomanz'),
    SampleVJ(name: 'VJ Sid'),
    SampleVJ(name: 'VJ Kat'),
    SampleVJ(name: 'VJ Emtee'),
  ];
}

/// Static sample genre list (UI only).
class SampleGenre {
  final String name;
  final bool isActive;
  const SampleGenre({required this.name, this.isActive = true});

  static const List<SampleGenre> all = [
    SampleGenre(name: 'Action'),
    SampleGenre(name: 'Drama'),
    SampleGenre(name: 'Romance'),
    SampleGenre(name: 'Thriller'),
    SampleGenre(name: 'Comedy'),
    SampleGenre(name: 'Horror'),
    SampleGenre(name: 'Sci-Fi'),
    SampleGenre(name: 'Crime'),
    SampleGenre(name: 'Cartoon'),
    SampleGenre(name: 'Documentary'),
  ];
}

/// Static sample movie catalog (UI only).
class SampleMovies {
  static const List<Movie> all = [
    Movie(title: 'Top Gun: Maverick', subtitle: '2022 - Action', imageUrl: 'https://picsum.photos/id/1011/400/600', badge: 'VJ Icep'),
    Movie(title: 'The Whisper Man', subtitle: '2021 - Thriller', imageUrl: 'https://picsum.photos/id/1005/400/600', badge: 'VJ Junior'),
    Movie(title: 'The Mongoose', subtitle: '2020 - Crime', imageUrl: 'https://picsum.photos/id/1015/400/600', badge: 'VJ Manchomanz'),
    Movie(title: 'Dune: Part Two', subtitle: '2024 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1025/400/600', badge: 'VJ Icep'),
    Movie(title: 'Oppenheimer', subtitle: '2023 - Drama', imageUrl: 'https://picsum.photos/id/1035/400/600', badge: 'VJ Junior'),
    Movie(title: 'John Wick 4', subtitle: '2023 - Action', imageUrl: 'https://picsum.photos/id/1045/400/600', badge: 'VJ Sid'),
    Movie(title: 'The Dark Knight', subtitle: '2008 - Action', imageUrl: 'https://picsum.photos/id/1095/400/600', badge: 'VJ Icep'),
    Movie(title: 'The Notebook', subtitle: '2004 - Romance', imageUrl: 'https://picsum.photos/id/1000/400/600', badge: 'VJ Kat'),
    Movie(title: 'La La Land', subtitle: '2016 - Romance', imageUrl: 'https://picsum.photos/id/1065/400/600', badge: 'VJ Junior'),
    Movie(title: 'Interstellar', subtitle: '2014 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1030/400/600', badge: 'VJ Icep'),
    Movie(title: 'Inception', subtitle: '2010 - Action', imageUrl: 'https://picsum.photos/id/1018/400/600', badge: 'VJ Manchomanz'),
    Movie(title: 'Mad Max: Fury Road', subtitle: '2015 - Action', imageUrl: 'https://picsum.photos/id/1082/400/600', badge: 'VJ Sid'),
    Movie(title: 'The Matrix', subtitle: '1999 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1027/400/600', badge: 'VJ Icep'),
    Movie(title: 'Gladiator', subtitle: '2000 - Action', imageUrl: 'https://picsum.photos/id/1049/400/600', badge: 'VJ Junior'),
    Movie(title: 'The Silence of the Lambs', subtitle: '1991 - Thriller', imageUrl: 'https://picsum.photos/id/1052/400/600', badge: 'VJ Kat'),
    Movie(title: 'Parasite', subtitle: '2019 - Drama', imageUrl: 'https://picsum.photos/id/1015/400/600', badge: 'VJ Emtee'),
    Movie(title: 'Avatar: The Way of Water', subtitle: '2022 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1024/400/600', badge: 'VJ Icep'),
    Movie(title: 'Titanic', subtitle: '1997 - Romance', imageUrl: 'https://picsum.photos/id/1050/400/600', badge: 'VJ Junior'),
    Movie(title: 'Sonic 3', subtitle: '2024 - Cartoon', imageUrl: 'https://picsum.photos/id/1016/400/600', badge: 'VJ Sid'),
    Movie(title: 'Puss in Boots', subtitle: '2022 - Cartoon', imageUrl: 'https://picsum.photos/id/1048/400/600', badge: 'VJ Kat'),
  ];

  static const List<Movie> series = [
    Movie(title: 'Game of Thrones', subtitle: '2019 - Fantasy', imageUrl: 'https://picsum.photos/id/1055/400/600', badge: 'VJ Icep'),
    Movie(title: 'Breaking Bad', subtitle: '2013 - Drama', imageUrl: 'https://picsum.photos/id/1065/400/600', badge: 'VJ Junior'),
    Movie(title: 'Money Heist', subtitle: '2021 - Action', imageUrl: 'https://picsum.photos/id/1075/400/600', badge: 'VJ Kat'),
    Movie(title: 'Stranger Things', subtitle: '2022 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1085/400/600', badge: 'VJ Emtee'),
    Movie(title: 'The Boys', subtitle: '2022 - Action', imageUrl: 'https://picsum.photos/id/1012/400/600', badge: 'VJ Sid'),
    Movie(title: 'The Witcher', subtitle: '2021 - Fantasy', imageUrl: 'https://picsum.photos/id/1022/400/600', badge: 'VJ Icep'),
    Movie(title: 'Squid Game', subtitle: '2021 - Drama', imageUrl: 'https://picsum.photos/id/1032/400/600', badge: 'VJ Junior'),
    Movie(title: 'Sherlock', subtitle: '2017 - Crime', imageUrl: 'https://picsum.photos/id/1042/400/600', badge: 'VJ Manchomanz'),
    Movie(title: 'Peaky Blinders', subtitle: '2022 - Crime', imageUrl: 'https://picsum.photos/id/1056/400/600', badge: 'VJ Kat'),
  ];
}

/// Simple playlist model used for UI-only sample data.
class Playlist {
  final String id;
  final String title;
  final String ownerName;
  final bool isPublic;
  final int movieCount;
  final int likeCount;
  final int viewCount;
  final List<Movie> movies;

  const Playlist({
    required this.id,
    required this.title,
    required this.ownerName,
    this.isPublic = true,
    required this.movieCount,
    this.likeCount = 0,
    this.viewCount = 0,
    this.movies = const [],
  });
}

class SamplePlaylists {
  static const List<Playlist> all = [
    Playlist(
      id: 'p1',
      title: 'Top Action Picks',
      ownerName: 'VJ Icep',
      isPublic: true,
      movieCount: 5,
      likeCount: 124,
      viewCount: 890,
      movies: [
        Movie(title: 'Top Gun: Maverick', subtitle: '2022 - Action', imageUrl: 'https://picsum.photos/id/1011/400/600', badge: 'VJ Icep'),
        Movie(title: 'Dune: Part Two', subtitle: '2024 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1025/400/600', badge: 'VJ Icep'),
        Movie(title: 'John Wick 4', subtitle: '2023 - Action', imageUrl: 'https://picsum.photos/id/1045/400/600', badge: 'VJ Sid'),
        Movie(title: 'Mad Max: Fury Road', subtitle: '2015 - Action', imageUrl: 'https://picsum.photos/id/1082/400/600', badge: 'VJ Sid'),
        Movie(title: 'Gladiator', subtitle: '2000 - Action', imageUrl: 'https://picsum.photos/id/1049/400/600', badge: 'VJ Junior'),
      ],
    ),
    Playlist(
      id: 'p2',
      title: 'Weekend Binge',
      ownerName: 'VJ Junior',
      isPublic: true,
      movieCount: 6,
      likeCount: 87,
      viewCount: 430,
      movies: [
        Movie(title: 'Oppenheimer', subtitle: '2023 - Drama', imageUrl: 'https://picsum.photos/id/1035/400/600', badge: 'VJ Junior'),
        Movie(title: 'Inception', subtitle: '2010 - Action', imageUrl: 'https://picsum.photos/id/1018/400/600', badge: 'VJ Manchomanz'),
        Movie(title: 'Interstellar', subtitle: '2014 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1030/400/600', badge: 'VJ Icep'),
        Movie(title: 'The Matrix', subtitle: '1999 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1027/400/600', badge: 'VJ Icep'),
        Movie(title: 'The Dark Knight', subtitle: '2008 - Action', imageUrl: 'https://picsum.photos/id/1095/400/600', badge: 'VJ Icep'),
        Movie(title: 'Parasite', subtitle: '2019 - Drama', imageUrl: 'https://picsum.photos/id/1015/400/600', badge: 'VJ Emtee'),
      ],
    ),
    Playlist(
      id: 'p3',
      title: 'Romance Collection',
      ownerName: 'VJ Kat',
      isPublic: true,
      movieCount: 3,
      likeCount: 56,
      viewCount: 210,
      movies: [
        Movie(title: 'The Notebook', subtitle: '2004 - Romance', imageUrl: 'https://picsum.photos/id/1000/400/600', badge: 'VJ Kat'),
        Movie(title: 'La La Land', subtitle: '2016 - Romance', imageUrl: 'https://picsum.photos/id/1065/400/600', badge: 'VJ Junior'),
        Movie(title: 'Titanic', subtitle: '1997 - Romance', imageUrl: 'https://picsum.photos/id/1050/400/600', badge: 'VJ Junior'),
      ],
    ),
    Playlist(
      id: 'p4',
      title: 'My Watchlist',
      ownerName: 'You',
      isPublic: false,
      movieCount: 4,
      likeCount: 0,
      viewCount: 3,
      movies: [
        Movie(title: 'Sonic 3', subtitle: '2024 - Cartoon', imageUrl: 'https://picsum.photos/id/1016/400/600', badge: 'VJ Sid'),
        Movie(title: 'Puss in Boots', subtitle: '2022 - Cartoon', imageUrl: 'https://picsum.photos/id/1048/400/600', badge: 'VJ Kat'),
        Movie(title: 'Avatar: The Way of Water', subtitle: '2022 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1024/400/600', badge: 'VJ Icep'),
        Movie(title: 'La La Land', subtitle: '2016 - Romance', imageUrl: 'https://picsum.photos/id/1065/400/600', badge: 'VJ Junior'),
      ],
    ),
    Playlist(
      id: 'p5',
      title: 'Sci-Fi Marathon',
      ownerName: 'VJ Emtee',
      isPublic: true,
      movieCount: 5,
      likeCount: 201,
      viewCount: 1250,
      movies: [
        Movie(title: 'Dune: Part Two', subtitle: '2024 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1025/400/600', badge: 'VJ Icep'),
        Movie(title: 'Interstellar', subtitle: '2014 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1030/400/600', badge: 'VJ Icep'),
        Movie(title: 'Inception', subtitle: '2010 - Action', imageUrl: 'https://picsum.photos/id/1018/400/600', badge: 'VJ Manchomanz'),
        Movie(title: 'The Matrix', subtitle: '1999 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1027/400/600', badge: 'VJ Icep'),
        Movie(title: 'Avatar: The Way of Water', subtitle: '2022 - Sci-Fi', imageUrl: 'https://picsum.photos/id/1024/400/600', badge: 'VJ Icep'),
      ],
    ),
    Playlist(
      id: 'p6',
      title: 'Late Night Thrills',
      ownerName: 'VJ Manchomanz',
      isPublic: true,
      movieCount: 4,
      likeCount: 93,
      viewCount: 670,
      movies: [
        Movie(title: 'The Silence of the Lambs', subtitle: '1991 - Thriller', imageUrl: 'https://picsum.photos/id/1052/400/600', badge: 'VJ Kat'),
        Movie(title: 'The Whisper Man', subtitle: '2021 - Thriller', imageUrl: 'https://picsum.photos/id/1005/400/600', badge: 'VJ Junior'),
        Movie(title: 'The Mongoose', subtitle: '2020 - Crime', imageUrl: 'https://picsum.photos/id/1015/400/600', badge: 'VJ Manchomanz'),
        Movie(title: 'Parasite', subtitle: '2019 - Drama', imageUrl: 'https://picsum.photos/id/1015/400/600', badge: 'VJ Emtee'),
      ],
    ),
  ];
}
