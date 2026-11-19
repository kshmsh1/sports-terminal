import 'package:flutter/material.dart';

class TerminalFilterDropdown extends StatelessWidget {
  const TerminalFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.width = 230,
    this.displayBuilder,
  });

  final String label;
  final String value;
  final Iterable<String> values;
  final ValueChanged<String> onChanged;
  final double width;
  final String Function(String value)? displayBuilder;

  @override
  Widget build(BuildContext context) {
    final items = values.toSet().toList(growable: false);
    final colors = Theme.of(context).colorScheme;
    if (items.isEmpty) return const SizedBox.shrink();

    final selectedValue = items.contains(value) ? value : items.first;

    return SizedBox(
      key: ValueKey('terminal-filter-$label'),
      width: width,
      child: DropdownButtonFormField<String>(
        key: ValueKey('terminal-filter-selected-$label-$selectedValue'),
        initialValue: selectedValue,
        isExpanded: true,
        menuMaxHeight: 420,
        borderRadius: BorderRadius.circular(14),
        dropdownColor: colors.surface,
        style: TextStyle(color: colors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colors.onSurfaceVariant),
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
        selectedItemBuilder: (context) => [
          for (final item in items)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayBuilder?.call(item) ?? item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        items: [
          for (final item in items)
            DropdownMenuItem<String>(
              value: item,
              child: Text(
                displayBuilder?.call(item) ?? item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (nextValue) {
          if (nextValue != null) onChanged(nextValue);
        },
      ),
    );
  }
}
