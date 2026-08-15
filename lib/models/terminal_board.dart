import 'dart:convert';

class TerminalBoardPanel {
  const TerminalBoardPanel({
    required this.id,
    required this.kind,
    required this.title,
    required this.payload,
    this.column = 0,
    this.row = 0,
    this.width = 1,
    this.height = 1,
  });

  final String id;
  final String kind;
  final String title;
  final Map<String, dynamic> payload;
  final int column;
  final int row;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'payload': payload,
        'column': column,
        'row': row,
        'width': width,
        'height': height,
      };

  factory TerminalBoardPanel.fromJson(Map<String, dynamic> json) => TerminalBoardPanel(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'object',
        title: json['title']?.toString() ?? 'Panel',
        payload: json['payload'] is Map
            ? (json['payload'] as Map).map((key, value) => MapEntry(key.toString(), value))
            : const {},
        column: (json['column'] as num?)?.toInt() ?? 0,
        row: (json['row'] as num?)?.toInt() ?? 0,
        width: (json['width'] as num?)?.toInt() ?? 1,
        height: (json['height'] as num?)?.toInt() ?? 1,
      );
}

class TerminalBoard {
  const TerminalBoard({
    required this.id,
    required this.title,
    required this.updatedAtIso,
    this.description = '',
    this.sport = 'NBA',
    this.filters = const {},
    this.panels = const [],
    this.collaborators = const [],
    this.liveRefresh = false,
  });

  final String id;
  final String title;
  final String updatedAtIso;
  final String description;
  final String sport;
  final Map<String, dynamic> filters;
  final List<TerminalBoardPanel> panels;
  final List<String> collaborators;
  final bool liveRefresh;

  TerminalBoard copyWith({
    String? title,
    String? description,
    String? updatedAtIso,
    Map<String, dynamic>? filters,
    List<TerminalBoardPanel>? panels,
    List<String>? collaborators,
    bool? liveRefresh,
  }) => TerminalBoard(
        id: id,
        title: title ?? this.title,
        updatedAtIso: updatedAtIso ?? this.updatedAtIso,
        description: description ?? this.description,
        sport: sport,
        filters: filters ?? this.filters,
        panels: panels ?? this.panels,
        collaborators: collaborators ?? this.collaborators,
        liveRefresh: liveRefresh ?? this.liveRefresh,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'sport': sport,
        'updatedAtIso': updatedAtIso,
        'filters': filters,
        'panels': [for (final panel in panels) panel.toJson()],
        'collaborators': collaborators,
        'liveRefresh': liveRefresh,
      };

  factory TerminalBoard.fromJson(Map<String, dynamic> json) => TerminalBoard(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Untitled Board',
        description: json['description']?.toString() ?? '',
        sport: json['sport']?.toString() ?? 'NBA',
        updatedAtIso: json['updatedAtIso']?.toString() ?? '',
        filters: json['filters'] is Map
            ? (json['filters'] as Map).map((key, value) => MapEntry(key.toString(), value))
            : const {},
        panels: json['panels'] is List
            ? [
                for (final raw in json['panels'] as List)
                  if (raw is Map)
                    TerminalBoardPanel.fromJson(
                      raw.map((key, value) => MapEntry(key.toString(), value)),
                    ),
              ]
            : const [],
        collaborators: json['collaborators'] is List
            ? [for (final value in json['collaborators'] as List) value.toString()]
            : const [],
        liveRefresh: json['liveRefresh'] == true,
      );

  String encode() => jsonEncode(toJson());
}
