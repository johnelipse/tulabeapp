import 'package:flutter/material.dart';
import 'package:tulabe/models/movies.dart';
import 'movie_card.dart';

class MovieList extends StatelessWidget {
  final List<Movie> movies;
  final ValueChanged<Movie>? onMovieTap;
  final bool isSeries;

  const MovieList({
    super.key,
    required this.movies,
    this.onMovieTap,
    this.isSeries = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final movie = movies[index];
          return SizedBox(
            width: 120,
            child: MovieCard(
              movie: movie,
              isSeries: isSeries,
              onTap: () => onMovieTap?.call(movie),
            ),
          );
        },
      ),
    );
  }
}
