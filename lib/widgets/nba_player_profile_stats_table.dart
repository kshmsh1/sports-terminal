import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/nba_player_profile_format.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'nba_percentage_heat_cell.dart';
import 'website_sticky_stats_table.dart';

/// Shares the same season data, metric resolver, and sticky table as Stats.
class NbaPlayerProfileStatsTable extends StatefulWidget {
  const NbaPlayerProfileStatsTable({super.key, required this.dossier,
    required this.playerId, required this.playerName,
    required this.seasonType, required this.advanced});
  final Map<String, dynamic> dossier;
  final String playerId, playerName, seasonType;
  final bool advanced;
  @override
  State<NbaPlayerProfileStatsTable> createState() =>
      _NbaPlayerProfileStatsTableState();
}
class _NbaPlayerProfileStatsTableState extends State<NbaPlayerProfileStatsTable> {
  static const _engine = NbaStatsWorkstationEngine();
  static const _resolver = NbaTerminalMetricResolver();
  static const _basic = ['gp','mpg','ppg','rpg','apg','spg','bpg','tpg',
    'pf','fg_pct','two_pct','three_pct','ft_pct','ts_pct'];
  static const _overview = ['gp','mpg','ppg','rpg','apg','spg','bpg','tpg',
    'fg_pct','three_pct','ft_pct','ts_pct','per','bpm','vorp'];

  static const _customFamilies = <NbaTerminalStatFamily>[
    NbaTerminalStatFamily(
      id: 'shooting_efficiency',
      label: 'Shooting & Efficiency',
      description: 'Consolidated shooting percentages and possession efficiency.',
      metrics: [
        'fg_pct', 'two_pct', 'three_pct', 'ft_pct', 'rim_fg_pct',
        'midrange_fg_pct', 'efg_pct', 'ts_pct', 'ftr', 'three_par',
        'pps', 'pie', 'assisted_fg_pct', 'unassisted_fg_pct',
        'assisted_ppg', 'unassisted_ppg',
      ],
    ),
    NbaTerminalStatFamily(
      id: 'isolation',
      label: 'Isolation',
      description: 'Isolation scoring and related self-creation measures.',
      metrics: [
        'isolation_ppp', 'usage', 'unassisted_fg_pct',
        'unassisted_ppg', 'drive_ppg', 'drive_apg',
      ],
    ),
    NbaTerminalStatFamily(
      id: 'rate_adjusted',
      label: 'Rate Adjusted',
      description: 'Counting production under the selected rate basis.',
      metrics: [
        'mpg', 'ppg', 'rpg', 'apg', 'spg', 'bpg', 'tpg',
        'fgm', 'three_pm', 'ftm',
      ],
    ),
  ];
  static final List<NbaTerminalStatFamily> _families = [
    ..._customFamilies, ...nbaTerminalStatFamilies,
  ];

  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _family = 'overview';
  String _sort = 'season_id';
  bool _descending = true;
  int _page = 0, _pageSize = 20;
  final Set<String> _expanded = {};

  @override
  void didUpdateWidget(covariant NbaPlayerProfileStatsTable old) {
    super.didUpdateWidget(old);
    if (old.seasonType != widget.seasonType || old.playerId != widget.playerId) {
      _page = 0;
      _expanded.clear();
    }
  }
  List<Map<String,dynamic>> _rawRows() {
    final dense = widget.dossier['stat_seasons'];
    final source = dense is List ? dense :
      widget.dossier[widget.seasonType == 'playoffs' ?
          'playoff_seasons' : 'regular_seasons'];
    if (source is! List) return [];
    final result = <Map<String,dynamic>>[];
    for (final entry in source) {
      if (entry is! Map) continue;
      final raw = entry.map((k,v) => MapEntry(k.toString(),v));
      if ((raw['season_type'] ?? '').toString().toLowerCase() != widget.seasonType) continue;
      result.add({...raw,
        'player_id': raw['player_id'] ?? raw['player_key'] ?? widget.playerId,
        'player_label': raw['player_label'] ?? raw['player_name'] ?? widget.playerName,
        'team_ids': raw['team_ids'] ?? raw['team_abbreviation'] ?? '—',
        'position': raw['position'] ?? raw['positions'] ?? '',
      });
    }
    return result;
  }
  NbaTerminalStatFamily? get _category {
    for (final family in _families) {
      if (family.id == _family) return family;
    }
    return null;
  }
  List<String> get _parents {
    if (!widget.advanced) return _basic;
    if (_family == 'overview') return _overview;
    final keys = _category?.metrics ?? _overview;
    if (_family == 'physical') return [...keys, 'bio_college', 'bio_country'];
    return keys;
  }
  List<String> _keys() {
    final keys = <String>[];
    for (final key in _parents) {
      keys.add(key);
      if (_expanded.contains(key)) {
        keys.addAll(_category?.expansionOverrides[key] ??
          nbaTerminalMetricByKey[key]?.children ?? const <String>[]);
      }
    }
    return keys.toSet().toList();
  }
  double? _value(NbaStatsRow row, String key) =>
    _resolver.value(row,key) ?? row.value(key);
  bool _isText(String key) => key == 'bio_college' || key == 'bio_country';
  String _txt(NbaStatsRow row,String key) => (row.raw[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final snapshot = NbaTerminalSeedSnapshot.fromMap({
      'players':[{'player_id':widget.playerId,'player_name':widget.playerName}],
      'player_season_totals':_rawRows(),
    });
    final values = _engine.buildRows(snapshot, basis:_basis,
      seasonType:NbaStatsSeasonType.combined);
    final keys = _keys().where((key) => values.any((row) =>
      _value(row,key) != null || (_isText(key) && _txt(row,key).isNotEmpty))).toList();
    values.sort((a,b) {
      if (_sort == 'season_id') {
        final l = (a.raw['season_id'] ?? '').toString(),
          r = (b.raw['season_id'] ?? '').toString();
        return _descending ? r.compareTo(l) : l.compareTo(r);
      }
      final l = _value(a,_sort), r = _value(b,_sort);
      if (l == null && r == null) return 0;
      if (l == null) return 1;
      if (r == null) return -1;
      return _descending ? r.compareTo(l) : l.compareTo(r);
    });
    final count = math.max(1,(values.length/_pageSize).ceil());
    _page = _page.clamp(0,count-1);
    final shown = values.skip(_page*_pageSize).take(_pageSize).toList();
    final colors = Theme.of(context).colorScheme;
    final childTint = Theme.of(context).brightness == Brightness.dark ?
      colors.primaryContainer.withValues(alpha:.25) :
      colors.primaryContainer.withValues(alpha:.45);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if (widget.advanced) ...[
        Wrap(spacing:7,runSpacing:7,children:[
          ChoiceChip(label:const Text('Overview'),selected:_family=='overview',
            onSelected:(_) => setState(() {
              _family='overview'; _expanded.clear(); _page=0;
            })),
          for (final f in _families)
            ChoiceChip(label:Text(f.label),selected:_family==f.id,
              onSelected:(_) => setState(() {
                _family=f.id; _expanded.clear(); _page=0;
              })),
        ]),
        if (_category != null)
          Padding(padding:const EdgeInsets.symmetric(vertical:10),
            child:Text(_category!.description,style:TextStyle(
              color:colors.onSurfaceVariant,fontSize:12))),
      ],
      Row(children:[
        const Text('Rate',style:TextStyle(fontWeight:FontWeight.w700,fontSize:12)),
        const SizedBox(width:10),
        DropdownButton<NbaStatsBasis>(value:_basis,isDense:true,items:[
          for(final b in NbaStatsBasis.values)
            DropdownMenuItem(value:b,child:Text(b.label))
        ],onChanged:(b) => setState(() {
          _basis=b ?? _basis; _page=0;
        })),
        const Spacer(),
        Text('${values.length} seasons',
          style:TextStyle(color:colors.onSurfaceVariant,fontSize:12)),
        const SizedBox(width:10),
        DropdownButton<int>(value:_pageSize,isDense:true,items:[
          for(final n in [10,20,50,100])
            DropdownMenuItem(value:n,child:Text('$n rows'))
        ],onChanged:(n) => setState(() {
          _pageSize=n??20; _page=0;
        })),
      ]),
      const SizedBox(height:8),
      if(values.isEmpty)
        Padding(padding:const EdgeInsets.all(20),
          child:Text('No source-backed rows for this segment.',
            style:TextStyle(color:colors.onSurfaceVariant)))
      else WebsiteStickyStatsTable(
        firstColumnWidth:94,headerHeight:46,rowHeight:40,maxBodyHeight:900,
        columns:[
          WebsiteStickyStatsColumn(label:const Text('Season'),
            width:94,onTap:()=>_changeSort('season_id')),
          const WebsiteStickyStatsColumn(label:Text('Team'),width:65),
          const WebsiteStickyStatsColumn(label:Text('Pos'),width:71),
          for(final key in keys) WebsiteStickyStatsColumn(
            label:_head(key),width:_width(key),numeric:!_isText(key),
            backgroundColor:_parents.contains(key)?null:childTint,
            onTap:()=>_changeSort(key)),
        ],
        rows:[
          for(final row in shown)
            [
              Text((row.raw['season_id']??'—').toString(),
                style:const TextStyle(fontWeight:FontWeight.w700)),
              Text(row.team,maxLines:1,overflow:TextOverflow.ellipsis),
              Text(nbaOrderedPositions(row.position),maxLines:1,
                overflow:TextOverflow.ellipsis),
              for(final key in keys) _cell(row,key),
            ]
        ],
      ),
      if(count>1) Row(mainAxisAlignment:MainAxisAlignment.end,children:[
        IconButton(onPressed:_page==0?null:()=>setState(()=>_page--),
          icon:const Icon(Icons.chevron_left_rounded)),
        Text('${_page + 1} / $count'),
        IconButton(onPressed:_page+1>=count?null:()=>setState(()=>_page++),
          icon:const Icon(Icons.chevron_right_rounded)),
      ]),
      Padding(padding:const EdgeInsets.only(top:9),
        child:Text(widget.dossier['stat_seasons'] is List ?
          'Published player-season data, identical to the Stats source. Missing fields remain unavailable.' :
          'Legacy player data. Rebuild static NBA data to import all available advanced stats.',
          style:TextStyle(fontSize:11,color:colors.onSurfaceVariant))),
    ]);
  }
  void _changeSort(String key) => setState(() {
    if(_sort==key) _descending=!_descending;
    else { _sort=key; _descending=true; }
    _page=0;
  });
  Widget _head(String key) {
    final m=nbaTerminalMetricByKey[key];
    final children=_category?.expansionOverrides[key] ??
      m?.children ?? const <String>[];
    final label=m?.shortLabel ?? (key == 'bio_college' ? 'College' :
      key == 'bio_country' ? 'Country' : key.toUpperCase());
    if(children.isEmpty || !_parents.contains(key)) {
      return Text(label,maxLines:1,overflow:TextOverflow.ellipsis);
    }
    return InkWell(onTap:()=>setState(() {
      if(!_expanded.add(key)) _expanded.remove(key);
    }),child:Row(mainAxisSize:MainAxisSize.min,children:[
      Icon(_expanded.contains(key)?Icons.arrow_drop_down_rounded:
        Icons.arrow_right_rounded,size:22),
      Flexible(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis))
    ]));
  }
  double _width(String key) {
    if(_isText(key))return 142;
    final m=nbaTerminalMetricByKey[key];
    final children=_category?.expansionOverrides[key]??m?.children??
      const <String>[];
    return math.max(67,math.min(270,(m?.shortLabel.length??key.length)*6.5+
      19+(children.isEmpty?0:28)));
  }
  Widget _cell(NbaStatsRow row,String key) {
    if(_isText(key))return Text(_txt(row,key).isEmpty?'—':_txt(row,key),
      maxLines:1,overflow:TextOverflow.ellipsis);
    final val=_value(row,key);
    final m=nbaTerminalMetricByKey[key];
    final txt=m==null?(val?.toStringAsFixed(1)??'—'):_resolver.format(row,key);
    final label=Text(txt,maxLines:1,overflow:TextOverflow.ellipsis);
    final heat=nbaPercentageHeatMetricForKey(key);
    if(heat==null)return label;
    return Align(alignment:Alignment.centerRight,
      child:NbaPercentageHeatCell(metric:heat,value:val,child:label));
  }
}
