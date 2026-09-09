import 'package:flutter/material.dart';

/// Responsive movie-card grid sizing based on the device's screen width.
///
/// Portrait: always 3 columns.
/// Landscape: the number of columns is derived from how wide the screen is,
/// so wider phones can fit more cards per row (with a floor of 4).
int movieColumns(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (MediaQuery.of(context).orientation == Orientation.landscape) {
    final usable = width - 32; // 16px horizontal padding on each side
    // Aim for cards at least ~150px wide; clamp between 4 and 6 columns.
    final count = (usable / 150).floor();
    return count.clamp(4, 6);
  }
  return 3;
}

/// Row height for movie cards, tuned per orientation so the posters stay in a
/// portrait aspect whether in the 3-col portrait or the width-derived
/// landscape layouts. Tighter cards use a taller ratio than wider ones so the
/// poster always reads as portrait.
double movieCardExtent(BuildContext context) {
  if (MediaQuery.of(context).orientation == Orientation.landscape) {
    final columns = movieColumns(context);
    // More columns -> narrower cells -> relatively taller poster.
    return switch (columns) {
      4 => 250.0,
      5 => 260.0,
      _ => 275.0,
    };
  }
  return 175.0;
}
