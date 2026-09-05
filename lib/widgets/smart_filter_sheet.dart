import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/smart_filter.dart';
import '../providers/filter_provider.dart';

/// Opens the Smart Filters bottom sheet for the current screen.
///
/// [provider] lets a screen bind the sheet to its own filter state (e.g.
/// Hidden Media). Defaults to the global Search filters.
Future<void> showSmartFilterSheet(
  BuildContext context, {
  NotifierProvider<SmartFilterController, SmartFilterState>? provider,
}) {
  final effectiveProvider = provider ?? smartFilterProvider;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => SmartFilterSheet(provider: effectiveProvider),
  );
}

/// Bottom-sheet UI for editing the combinable Smart Filters.
/// All changes are applied live to [provider] — changing a filter
/// recomputes on the existing index and never triggers a filesystem re-scan.
class SmartFilterSheet extends ConsumerWidget {
  SmartFilterSheet({
    super.key,
    NotifierProvider<SmartFilterController, SmartFilterState>? provider,
  }) : provider = provider ?? smartFilterProvider;

  final NotifierProvider<SmartFilterController, SmartFilterState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Text(
                'Smart Filters',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (filter.isActive)
                TextButton.icon(
                  onPressed: notifier.clear,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear all'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── File type ─────────────────────────────────────────────────
          Text(
            'File type',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SmartTypeFilter.values.map((type) {
              final selected = filter.types.contains(type);
              return FilterChip(
                label: Text(_typeLabel(type)),
                selected: selected,
                onSelected: (_) => notifier.toggleType(type),
              );
            }).toList(),
          ),

          const Divider(height: 32),

          // ── File size ─────────────────────────────────────────────────
          Text(
            'Size',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _FilterRadioGroup<FileSizeFilter>(
            value: filter.sizeFilter,
            onChanged: notifier.setSizeFilter,
            options: const [
              (FileSizeFilter.any, 'Any size'),
              (FileSizeFilter.above10mb, '> 10 MB'),
              (FileSizeFilter.above100mb, '> 100 MB'),
              (FileSizeFilter.above500mb, '> 500 MB'),
              (FileSizeFilter.above1gb, '> 1 GB'),
            ],
          ),

          const Divider(height: 16),

          // ── Date ──────────────────────────────────────────────────────
          Text(
            'Date',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _FilterRadioGroup<ModifiedDateFilter>(
            value: filter.dateFilter,
            onChanged: notifier.setDateFilter,
            options: const [
              (ModifiedDateFilter.any, 'Any date'),
              (ModifiedDateFilter.today, 'Today'),
              (ModifiedDateFilter.last7Days, '7 days'),
              (ModifiedDateFilter.last30Days, '30 days'),
              (ModifiedDateFilter.lastYear, '1 year'),
            ],
          ),

          const Divider(height: 16),

          // ── Location ─────────────────────────────────────────────────
          Text(
            'Storage',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text('Internal Storage'),
            subtitle: const Text('/storage/emulated/0'),
            value: filter.internalStorage,
            onChanged: (v) => notifier.setInternalStorage(v ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text('SD Card'),
            subtitle: const Text('/storage/XXXX-XXXX'),
            value: filter.sdCard,
            onChanged: (v) => notifier.setSdCard(v ?? true),
          ),
        ],
      ),
    );
  }
}

String _typeLabel(SmartTypeFilter type) {
  switch (type) {
    case SmartTypeFilter.images:
      return 'Images';
    case SmartTypeFilter.videos:
      return 'Videos';
    case SmartTypeFilter.audio:
      return 'Audio';
    case SmartTypeFilter.documents:
      return 'Documents';
    case SmartTypeFilter.pdfs:
      return 'PDFs';
    case SmartTypeFilter.archives:
      return 'Archives';
    case SmartTypeFilter.hidden:
      return 'Hidden';
  }
}

/// A single-selection (radio) list. Uses Flutter's [RadioGroup] ancestor to
/// manage the group value so per-tile `groupValue`/`onChanged` aren't needed.
class _FilterRadioGroup<T> extends StatelessWidget {
  const _FilterRadioGroup({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String)> options;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: value,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        children: options
            .map(
              (option) => RadioListTile<T>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(option.$2),
                value: option.$1,
              ),
            )
            .toList(),
      ),
    );
  }
}
