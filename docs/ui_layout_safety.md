# UI Layout Safety

Dense terminal panels often place metric cards inside responsive grids. Avoid using full `TerminalCard` padding inside tight grid cells because it can cause `RenderFlex overflowed` exceptions on smaller Chrome windows.

## Safe metric pattern

Use:

```dart
CompactMetricCard(label: 'Teams', value: '30', detail: 'connected')
```

The component lives at:

```text
lib/widgets/compact_metric_card.dart
```

It is covered by:

```text
test/compact_metric_card_test.dart
```

## Rule

For metric grids, prefer `CompactMetricCard`. Use `TerminalCard` for larger free-form sections, tables, and panels with enough vertical space.
