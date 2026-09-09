import 'package:flutter/material.dart';
import 'package:tulabe/models/movies.dart';
import 'movie_card.dart';
import 'section_header.dart';

class GenreRow extends StatelessWidget {
  final String genreName;
  final List<Movie> movies;
  final VoidCallback? onSeeAll;
  final ValueChanged<Movie>? onMovieTap;

  const GenreRow({
    super.key,
    required this.genreName,
    required this.movies,
    this.onSeeAll,
    this.onMovieTap,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: genreName, onSeeAll: onSeeAll),
        const SizedBox(height: 10),
        SizedBox(
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
                  onTap: () => onMovieTap?.call(movie),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
