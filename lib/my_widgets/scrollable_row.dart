import 'package:flutter/material.dart';

class ScrollableRow extends StatelessWidget {
  final List<Widget> children;
  final double height;

  const ScrollableRow({
    super.key,
    required this.children,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}
