import 'package:flutter/material.dart';
import '../models/movies.dart';
import '../theme/app_colors.dart';

/// A bottom sheet mirroring the web's "Filter Content" drawer.
/// UI only — selection is reported back via [onChanged].
class FiltersSheet extends StatefulWidget {
  final bool showLatest;
  final bool latestOnly;
  final bool showYear;
  final bool showStatus;
  final String activeGenre;
  final String activeVJ;
  final String activeYear;
  final String activeStatus;
  final List<String>? genreLabels;
  final List<String>? vjLabels;
  final ValueChanged<bool> onLatestChanged;
  final ValueChanged<String> onGenreChanged;
  final ValueChanged<String> onVJChanged;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String>? onStatusChanged;

  const FiltersSheet({
    super.key,
    this.showLatest = true,
    required this.latestOnly,
    this.showYear = true,
    this.showStatus = false,
    required this.activeGenre,
    required this.activeVJ,
    required this.activeYear,
    this.activeStatus = '',
    this.genreLabels,
    this.vjLabels,
    required this.onLatestChanged,
    required this.onGenreChanged,
    required this.onVJChanged,
    required this.onYearChanged,
    this.onStatusChanged,
  });

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late bool _latestOnly;
  late String _genre;
  late String _vj;
  late String _year;
  late String _status;

  @override
  void initState() {
    super.initState();
    _latestOnly = widget.latestOnly;
    _genre = widget.activeGenre;
    _vj = widget.activeVJ;
    _year = widget.activeYear;
    _status = widget.activeStatus;
  }

  void _apply() {
    widget.onLatestChanged(_latestOnly);
    widget.onGenreChanged(_genre);
    widget.onVJChanged(_vj);
    widget.onYearChanged(_year);
    widget.onStatusChanged?.call(_status);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'FILTER CONTENT',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Narrow down what you want to watch.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showLatest) ...[
                      Row(
                        children: [
                          _ToggleChip(
                            label: 'Latest',
                            selected: _latestOnly,
                            onTap: () => setState(() => _latestOnly = !_latestOnly),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Show only latest picks',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    _FilterGroup(
                      title: 'Genre',
                      selected: _genre,
                      onReset: () => setState(() => _genre = ''),
                      onSelected: (name) => setState(() => _genre = _genre == name ? '' : name),
                      labels: widget.genreLabels ??
                          SampleGenre.all
                              .where((g) => g.isActive)
                              .map((g) => g.name)
                              .toList(),
                    ),
                    const SizedBox(height: 20),
                    _FilterGroup(
                      title: 'VJ',
                      selected: _vj,
                      onReset: () => setState(() => _vj = ''),
                      onSelected: (name) => setState(() => _vj = _vj == name ? '' : name),
                      labels: widget.vjLabels ?? SampleVJ.all.map((v) => v.name).toList(),
                    ),
                    if (widget.showStatus) ...[
                      const SizedBox(height: 20),
                      _FilterGroup(
                        title: 'Status',
                        selected: _status,
                        onReset: () => setState(() => _status = ''),
                        onSelected: (s) => setState(() => _status = _status == s ? '' : s),
                        labels: const ['Ongoing', 'Completed'],
                      ),
                    ],
                    if (widget.showYear) ...[
                      const SizedBox(height: 20),
                      _FilterGroup(
                        title: 'Year',
                        selected: _year,
                        onReset: () => setState(() => _year = ''),
                        onSelected: (y) => setState(() => _year = _year == y ? '' : y),
                        labels: YearOptions.years.map((y) => y.toString()).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'APPLY FILTERS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBg,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final String selected;
  final VoidCallback onReset;
  final ValueChanged<String> onSelected;
  final List<String> labels;

  const _FilterGroup({
    required this.title,
    required this.selected,
    required this.onReset,
    required this.onSelected,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: selected.isEmpty,
              onTap: onReset,
            ),
            for (final label in labels)
              _FilterChip(
                label: label,
                selected: selected == label,
                onTap: () => onSelected(label),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBg,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
