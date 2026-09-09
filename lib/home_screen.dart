import 'package:flutter/material.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/controllers/home_controller.dart';
import 'package:tulabe/controllers/watch_progress_store.dart';
import 'package:tulabe/models/movies.dart';
import 'package:tulabe/my_widgets/bottom_nav_bar.dart';
import 'package:tulabe/my_widgets/genre_row.dart';
import 'package:tulabe/my_widgets/hero_banner.dart';
import 'package:tulabe/my_widgets/continue_watching_card.dart';
import 'package:tulabe/my_widgets/movie_card.dart';
import 'package:tulabe/my_widgets/section_header.dart';
import 'package:tulabe/my_widgets/top_bar.dart';
import 'package:tulabe/my_widgets/vj_card.dart';
import 'package:tulabe/my_widgets/year_chip.dart';
import 'package:tulabe/screens/movies_screen.dart';
import 'package:tulabe/screens/series_screen.dart';
import 'package:tulabe/screens/playlists_screen.dart';
import 'package:tulabe/screens/series_detail_screen.dart';
import 'package:tulabe/screens/search_screen.dart';
import 'package:tulabe/screens/saved_screen.dart';
import 'package:tulabe/screens/settings_screen.dart';
import 'package:tulabe/screens/movie_detail_screen.dart';
import 'package:tulabe/screens/genre_screen.dart';
import 'package:tulabe/screens/category_screen.dart';
import 'package:tulabe/screens/vjs_screen.dart';
import 'package:tulabe/screens/year_screen.dart';
import 'package:tulabe/screens/vj_detail_screen.dart';
import 'package:tulabe/screens/request_movie_screen.dart';
import 'package:tulabe/screens/login_screen.dart';
import 'package:tulabe/my_widgets/menu_drawer.dart';
import 'package:tulabe/my_widgets/responsive_grid.dart';

import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  bool _menuOpen = false;

  final _screens = const [
    HomeScreenBody(),
    MoviesScreen(),
    SeriesScreen(),
    PlaylistsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TopBar(
                onSearchTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                onNotificationTap: () => _openMyStuff(context),
              ),
            ),
          ),
          Expanded(child: _screens[_navIndex]),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (index) => setState(() => _navIndex = index),
        onMenuTap: _toggleMenu,
        menuActive: _menuOpen,
      ),
    );
  }

  void _toggleMenu() {
    if (_menuOpen) {
      Navigator.pop(context);
      setState(() => _menuOpen = false);
    } else {
      setState(() => _menuOpen = true);
      _openMenu();
    }
  }

  Future<void> _openMenu() async {
    final home = HomeController();
    final genres = await home.fetchAllGenres();
    final vjs = await home.fetchAllVJs();
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        pageBuilder: (_, _, _) => MenuDrawer(
          genres: genres,
          vjs: vjs,
          onClose: _toggleMenu,
          onNavigate: _navigateFromMenu,
          onLatestDrops: () =>
              _menuPush(const CategoryScreen(categoryId: 'latest')),
          onSearch: () => _menuPush(const SearchScreen()),
          onSaved: () => _menuPush(const SavedScreen()),
          onClearHistory: () {
            Navigator.pop(context);
            setState(() => _menuOpen = false);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'Watch history cleared',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  backgroundColor: Colors.black87,
                  duration: Duration(seconds: 2),
                ),
              );
          },
          onGenre: () => _menuPush(const CategoryScreen(categoryId: 'movies')),
          onGenreTap: (genre) =>
              _menuPush(GenreScreen(genre: genre.name, genreId: '${genre.id}')),
          onVJAll: () => _menuPush(const VJsScreen()),
          onVJTap: (vj) => _menuPush(VJDetailScreen(vjId: '${vj.id}')),
        ),
      ),
    );
  }

  void _navigateFromMenu(int index) {
    Navigator.pop(context);
    setState(() {
      _menuOpen = false;
      _navIndex = index;
    });
  }

  void _menuPush(Widget screen) {
    Navigator.pop(context);
    setState(() => _menuOpen = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openMyStuff(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MY STUFF',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            _MyStuffTile(
              icon: Icons.bookmark_border,
              label: 'Saved / Favorites',
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedScreen()),
                );
              },
            ),
            _MyStuffTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            _MyStuffTile(
              icon: Icons.movie_filter_outlined,
              label: 'Request a Movie',
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestMovieScreen()),
                );
              },
            ),
            _AccountTile(
              signedIn: AuthController.instance.isAuthenticated,
              displayName: AuthController.instance.displayName,
              onSignIn: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              onOpenAccount: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              onSignOut: () {
                Navigator.pop(sheet);
                AuthController.instance.logout();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Signed out',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      backgroundColor: Colors.black87,
                      duration: Duration(seconds: 2),
                    ),
                  );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The home tab body, mirroring the web homepage layout.
// class HomeScreenBody extends StatelessWidget {
//   HomeScreenBody({super.key});

//   final MovieBannerController movieBannerController = MovieBannerController();

//   final List<FeaturedMovie> _hero = const [
//     FeaturedMovie(
//       tag: 'VJ ICEP',
//       title: 'TOP GUN: MAVERICK',
//       description:
//           'After more than thirty years of service as one of the Navy\'s top '
//           'aviators, and dodging the advancement in rank that would ground '
//           'him, Pete "Maverick" Mitchell finds himself training a detachment '
//           'of graduates for a special mission.',
//       imageUrl: 'https://picsum.photos/id/1011/1200/800',
//       year: '2022',
//       genre: 'ACTION, DRAMA',
//       duration: '151 min',
//     ),
//     FeaturedMovie(
//       tag: 'VJ JUNIOR',
//       title: 'THE WHISPER MAN',
//       description:
//           'After Thought House Productions and Autumn Productions acquire the '
//           'rights to this chilling thriller, a father and son must confront '
//           'a dark presence in their new home.',
//       imageUrl: 'https://picsum.photos/id/1005/1200/800',
//       year: '2021',
//       genre: 'THRILLER, HORROR',
//       duration: '104 min',
//     ),
//     FeaturedMovie(
//       tag: 'VJ MANCHOMANZ',
//       title: 'THE MONGOOSE',
//       description:
//           'A gripping crime drama following a relentless investigator as he '
//           'pursues the truth behind a series of mysterious incidents.',
//       imageUrl: 'https://picsum.photos/id/1015/1200/800',
//       year: '2020',
//       genre: 'ACTION, CRIME',
//       duration: '118 min',
//     ),
//   ];

//   final List<Movie> _latestMovies = const [
//     Movie(
//       title: 'Top Gun: Maverick',
//       subtitle: '2022 - Action',
//       imageUrl: 'https://picsum.photos/id/1011/400/600',
//       badge: 'VJ ICEP',
//     ),
//     Movie(
//       title: 'The Whisper Man',
//       subtitle: '2021 - Thriller',
//       imageUrl: 'https://picsum.photos/id/1005/400/600',
//       badge: 'VJ JUNIOR',
//     ),
//     Movie(
//       title: 'The Mongoose',
//       subtitle: '2020 - Crime',
//       imageUrl: 'https://picsum.photos/id/1015/400/600',
//       badge: 'VJ MANCHOMANZ',
//     ),
//     Movie(
//       title: 'Dune: Part Two',
//       subtitle: '2024 - Sci-Fi',
//       imageUrl: 'https://picsum.photos/id/1025/400/600',
//       badge: 'VJ ICEP',
//     ),
//     Movie(
//       title: 'Oppenheimer',
//       subtitle: '2023 - Drama',
//       imageUrl: 'https://picsum.photos/id/1035/400/600',
//       badge: 'VJ JUNIOR',
//     ),
//     Movie(
//       title: 'John Wick 4',
//       subtitle: '2023 - Action',
//       imageUrl: 'https://picsum.photos/id/1045/400/600',
//       badge: 'VJ SID',
//     ),
//   ];

//   final List<Movie> _latestSeries = const [
//     Movie(
//       title: 'Game of Thrones',
//       subtitle: '2019 - Fantasy',
//       imageUrl: 'https://picsum.photos/id/1055/400/600',
//       badge: 'VJ ICEP',
//     ),
//     Movie(
//       title: 'Breaking Bad',
//       subtitle: '2013 - Drama',
//       imageUrl: 'https://picsum.photos/id/1065/400/600',
//       badge: 'VJ JUNIOR',
//     ),
//     Movie(
//       title: 'Money Heist',
//       subtitle: '2021 - Action',
//       imageUrl: 'https://picsum.photos/id/1075/400/600',
//       badge: 'VJ KAT',
//     ),
//     Movie(
//       title: 'Stranger Things',
//       subtitle: '2022 - Sci-Fi',
//       imageUrl: 'https://picsum.photos/id/1085/400/600',
//       badge: 'VJ EM',
//     ),
//   ];

//   final Map<String, List<Movie>> _genreMovies = const {
//     'Action': [
//       Movie(
//         title: 'John Wick 4',
//         subtitle: '2023',
//         imageUrl: 'https://picsum.photos/id/1045/400/600',
//       ),
//       Movie(
//         title: 'Top Gun: Maverick',
//         subtitle: '2022',
//         imageUrl: 'https://picsum.photos/id/1011/400/600',
//       ),
//       Movie(
//         title: 'The Dark Knight',
//         subtitle: '2008',
//         imageUrl: 'https://picsum.photos/id/1095/400/600',
//       ),
//     ],
//     'Romance': [
//       Movie(
//         title: 'The Notebook',
//         subtitle: '2004',
//         imageUrl: 'https://picsum.photos/id/1000/400/600',
//       ),
//       Movie(
//         title: 'La La Land',
//         subtitle: '2016',
//         imageUrl: 'https://picsum.photos/id/1065/400/600',
//       ),
//       Movie(
//         title: 'A Star Is Born',
//         subtitle: '2018',
//         imageUrl: 'https://picsum.photos/id/1030/400/600',
//       ),
//     ],
//   };

//   final List<Map<String, dynamic>> _continueWatching = const [
//     {
//       'title': 'Top Gun: Maverick',
//       'image': 'https://picsum.photos/id/1011/400/600',
//       'progress': 0.65,
//       'remaining': 2140,
//     },
//     {
//       'title': 'Breaking Bad',
//       'image': 'https://picsum.photos/id/1065/400/600',
//       'progress': 0.35,
//       'remaining': 3180,
//     },
//   ];

//   void _openMovie(BuildContext context, Movie movie) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
//     );
//   }

//   void _openSeries(BuildContext context, Movie series) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.only(top: 8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Hero carousel
//           HeroBanner(movies: _hero, onWatchNow: () {}, onLatestMovies: () {}),
//           // Continue Watching (if any)
//           if (_continueWatching.isNotEmpty) ...[
//             const SizedBox(height: 16),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 children: const [
//                   Text(
//                     'CONTINUE WATCHING',
//                     style: TextStyle(
//                       color: AppColors.textPrimary,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                   Spacer(),
//                   Text(
//                     'CLEAR',
//                     style: TextStyle(
//                       color: AppColors.textTertiary,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 1,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             SizedBox(
//               height: 200,
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 itemCount: _continueWatching.length,
//                 separatorBuilder: (_, _) => const SizedBox(width: 10),
//                 itemBuilder: (context, index) {
//                   final item = _continueWatching[index];
//                   return ContinueWatchingCard(
//                     title: item['title'] as String,
//                     imageUrl: item['image'] as String?,
//                     progress: (item['progress'] as num).toDouble(),
//                     remainingSeconds: item['remaining'] as int,
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 16),
//           ],
//           // Latest Movies (grid)
//           SectionHeader(
//             title: 'Latest Movies',
//             onSeeAll: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => const CategoryScreen(categoryId: 'latest'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: movieColumns(context),
//               mainAxisSpacing: 12,
//               crossAxisSpacing: 12,
//               mainAxisExtent: movieCardExtent(context),
//             ),
//             itemCount: _latestMovies.length,
//             itemBuilder: (context, index) => MovieCard(
//               movie: _latestMovies[index],
//               onTap: () => _openMovie(context, _latestMovies[index]),
//             ),
//           ),
//           // Available VJs
//           if (SampleVJ.all.isNotEmpty) ...[
//             const SizedBox(height: 24),
//             SectionHeader(
//               title: 'Available VJs',
//               onSeeAll: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const VJsScreen()),
//               ),
//             ),
//             const SizedBox(height: 10),
//             SizedBox(
//               height: 120,
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 itemCount: SampleVJ.all.length,
//                 separatorBuilder: (_, _) => const SizedBox(width: 10),
//                 itemBuilder: (context, index) {
//                   final vj = SampleVJ.all[index];
//                   return VJCard(
//                     name: vj.name,
//                     isActive: vj.isActive,
//                     onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => VJDetailScreen(vj: vj)),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//           // Latest Series (grid)
//           const SizedBox(height: 24),
//           SectionHeader(
//             title: 'Latest Series',
//             onSeeAll: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => const CategoryScreen(categoryId: 'series'),
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: movieColumns(context),
//               mainAxisSpacing: 12,
//               crossAxisSpacing: 12,
//               mainAxisExtent: movieCardExtent(context),
//             ),
//             itemCount: _latestSeries.length,
//             itemBuilder: (context, index) => MovieCard(
//               movie: _latestSeries[index],
//               isSeries: true,
//               onTap: () => _openSeries(context, _latestSeries[index]),
//             ),
//           ),
//           // For You
//           const SizedBox(height: 24),
//           SectionHeader(title: 'For You'),
//           const SizedBox(height: 10),
//           GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: movieColumns(context),
//               mainAxisSpacing: 12,
//               crossAxisSpacing: 12,
//               mainAxisExtent: movieCardExtent(context),
//             ),
//             itemCount: _latestMovies.length,
//             itemBuilder: (context, index) => MovieCard(
//               movie: _latestMovies[index],
//               onTap: () => _openMovie(context, _latestMovies[index]),
//             ),
//           ),
//           // Genre rows
//           for (final entry in _genreMovies.entries) ...[
//             const SizedBox(height: 24),
//             GenreRow(
//               genreName: entry.key,
//               movies: entry.value,
//               onSeeAll: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => GenreScreen(genre: entry.key),
//                 ),
//               ),
//               onMovieTap: (m) => _openMovie(context, m),
//             ),
//           ],
//           // Browse by Year
//           const SizedBox(height: 24),
//           SectionHeader(title: 'Browse by Year'),
//           const SizedBox(height: 10),
//           GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 4,
//               mainAxisSpacing: 8,
//               crossAxisSpacing: 8,
//               childAspectRatio: 2.4,
//             ),
//             itemCount: YearOptions.years.length,
//             itemBuilder: (context, index) =>
//                 YearChip(year: YearOptions.years[index]),
//           ),
//           const SizedBox(height: 24),
//         ],
//       ),
//     );
//   }
// }

class HomeScreenBody extends StatefulWidget {
  const HomeScreenBody({super.key});

  @override
  State<HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<HomeScreenBody> {
  final HomeController _homeController = HomeController();
  final WatchProgressStore _watchProgress = WatchProgressStore.instance;

  HomeData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait<Object?>([
        _homeController.fetchHomeData(),
        _watchProgress.ensureLoaded(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as HomeData?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openMovie(BuildContext context, Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
    );
  }

  void _openSeries(BuildContext context, Movie series) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
    );
  }

  /// Resume a saved position from the "Continue Watching" row. Series entries
  /// reopen the series page with the episode auto-selected; movies reopen the
  /// movie detail with the player seeking to the saved position.
  void _resume(WatchProgressEntry entry) {
    if (entry.seriesId != null && entry.seriesId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            series: Movie(
              id: entry.seriesId!,
              title: entry.title,
              imageUrl: entry.thumbnailUrl,
            ),
            initialEpisodeMovieId: entry.movieId,
            resumeFrom: entry.currentTime,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            movie: Movie(
              id: entry.movieId,
              title: entry.title,
              imageUrl: entry.thumbnailUrl,
            ),
            resumeFrom: entry.currentTime,
          ),
        ),
      );
    }
  }

  List<Movie> _movieCards(List<StreamMovie> movies) =>
      movies.map(Movie.fromStreamMovie).toList(growable: false);

  List<Movie> _seriesCards(List<Series> series) =>
      series.map(Movie.fromSeries).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Failed to load home content'));
    }

    final data = _data!;
    final latestMovies = _movieCards(data.latestMovies);
    final latestSeries = _seriesCards(data.latestSeries);
    final forYou = _movieCards(data.forYou);

    // Rebuild when watch progress changes so the "Continue Watching" row
    // appears/updates live after the user watches something and returns.
    return ListenableBuilder(
      listenable: _watchProgress,
      builder: (context, _) {
        final continueWatching = _watchProgress.inProgress;
        return _buildScroll(
          latestMovies,
          latestSeries,
          forYou,
          continueWatching,
        );
      },
    );
  }

  Widget _buildScroll(
    List<Movie> latestMovies,
    List<Movie> latestSeries,
    List<Movie> forYou,
    List<WatchProgressEntry> continueWatching,
  ) {
    final data = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.hero.isNotEmpty)
            HeroBanner(
              movies: data.hero,
              onWatchNow: () {},
              onLatestMovies: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryScreen(categoryId: 'latest'),
                ),
              ),
            ),
          // Continue Watching (resumable playback progress)
          if (continueWatching.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CONTINUE WATCHING',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(_watchProgress.clear),
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: continueWatching.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final entry = continueWatching[index];
                  final progress = entry.duration > 0
                      ? (entry.currentTime / entry.duration).clamp(0.0, 1.0)
                      : 0.0;
                  return ContinueWatchingCard(
                    title: entry.title,
                    imageUrl: entry.thumbnailUrl,
                    progress: progress,
                    remainingSeconds: (entry.duration - entry.currentTime)
                        .round(),
                    onTap: () => _resume(entry),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Latest Movies (grid)
          if (latestMovies.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(
              title: 'Latest Movies',
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryScreen(categoryId: 'latest'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: movieColumns(context),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: movieCardExtent(context),
              ),
              itemCount: latestMovies.length,
              itemBuilder: (context, index) => MovieCard(
                movie: latestMovies[index],
                onTap: () => _openMovie(context, latestMovies[index]),
              ),
            ),
          ],
          // Available VJs
          if (data.vjs.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Available VJs',
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VJsScreen()),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: data.vjs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final vj = data.vjs[index];
                  return VJCard(
                    name: vj.name,
                    isActive: vj.isActive,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VJDetailScreen(vjId: '${vj.id}'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          // Latest Series (grid)
          if (latestSeries.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Latest Series',
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryScreen(categoryId: 'series'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: movieColumns(context),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: movieCardExtent(context),
              ),
              itemCount: latestSeries.length,
              itemBuilder: (context, index) => MovieCard(
                movie: latestSeries[index],
                isSeries: true,
                onTap: () => _openSeries(context, latestSeries[index]),
              ),
            ),
          ],
          // For You
          if (forYou.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(title: 'For You'),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: movieColumns(context),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: movieCardExtent(context),
              ),
              itemCount: forYou.length,
              itemBuilder: (context, index) => MovieCard(
                movie: forYou[index],
                onTap: () => _openMovie(context, forYou[index]),
              ),
            ),
          ],
          // Genre rows
          for (final entry in data.genreMovies.entries) ...[
            const SizedBox(height: 24),
            GenreRow(
              genreName: entry.key.name,
              movies: _movieCards(entry.value),
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GenreScreen(
                    genre: entry.key.name,
                    genreId: '${entry.key.id}',
                  ),
                ),
              ),
              onMovieTap: (m) => _openMovie(context, m),
            ),
          ],
          // Browse by Year
          const SizedBox(height: 24),
          SectionHeader(title: 'Browse by Year'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
            ),
            itemCount: YearOptions.years.length,
            itemBuilder: (context, index) => YearChip(
              year: YearOptions.years[index],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => YearScreen(year: YearOptions.years[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MyStuffTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MyStuffTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Account-aware replacement for the old static "Sign In / Register" tile:
/// signed out it opens the login screen; signed in it shows the account tile
/// plus a "Sign Out" action.
class _AccountTile extends StatelessWidget {
  final bool signedIn;
  final String displayName;
  final VoidCallback onSignIn;
  final VoidCallback onOpenAccount;
  final VoidCallback onSignOut;

  const _AccountTile({
    required this.signedIn,
    required this.displayName,
    required this.onSignIn,
    required this.onOpenAccount,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    if (signedIn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MyStuffTile(
            icon: Icons.person_outline,
            label: displayName.isEmpty
                ? 'My Account'
                : 'Account · $displayName',
            onTap: onOpenAccount,
          ),
          _MyStuffTile(icon: Icons.logout, label: 'Sign Out', onTap: onSignOut),
        ],
      );
    }
    return _MyStuffTile(
      icon: Icons.login,
      label: 'Sign In / Register',
      onTap: onSignIn,
    );
  }
}
