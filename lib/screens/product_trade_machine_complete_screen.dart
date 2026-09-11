import 'package:flutter/material.dart';

import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_future_draft_asset_repository.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
import '../services/trade_machine_engine.dart';

const _bg = Color(0xFF08111D);
const _panel = Color(0xFF0D1927);
const _panel2 = Color(0xFF122235);
const _line = Color(0xFF20364D);
const _text = Color(0xFFF4F7FB);
const _muted = Color(0xFF91A2B5);
const _blue = Color(0xFF62A9FF);
const _cyan = Color(0xFF58D6D1);
const _green = Color(0xFF65D19E);
const _amber = Color(0xFFF2C66D);
const _red = Color(0xFFFF7C83);

const _cap = 166000000.0;
const _tax = 201690000.0;
const _first = 210690000.0;
const _second = 223690000.0;

class ProductTradeMachineCompleteScreen extends StatefulWidget {
  const ProductTradeMachineCompleteScreen({super.key});

  @override
  State<ProductTradeMachineCompleteScreen> createState() => _ProductTradeMachineCompleteScreenState();
}

class _ProductTradeMachineCompleteScreenState extends State<ProductTradeMachineCompleteScreen> {
  final contracts = const NbaTradeContractRepository();
  final draft = const NbaCompleteDraftAssetRepository();
  final engine = const TradeMachineEngine();
  late final Future<NbaTradeContractSnapshot> future = contracts.load();

  final Map<String, String> routes = {};
  final Map<String, String> searches = {};
  final Map<String, int> tabs = {};
  final Map<String, String> selectedTpeByTeam = {};
  List<String> teams = ['BOS', 'PHI'];
  DateTime tradeDate = DateTime(2026, 9, 11);
  bool routedOnly = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTradeContractSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: _bg,
            alignment: Alignment.center,
            child: snapshot.hasError
                ? Text('Unable to load trade data: ${snapshot.error}', style: const TextStyle(color: _red))
                : const CircularProgressIndicator(),
          );
        }
        final data = snapshot.data!;
        final validTeams = data.teams.toSet();
        teams = teams.where(validTeams.contains).toList();
        if (teams.length < 2) teams = ['BOS', 'PHI'];
        final allAssets = draft.all();
        final validAssetIds = <String>{...data.records.map((e) => e.id), ...allAssets.map((e) => e.id)};
        routes.removeWhere((id, destination) => !validAssetIds.contains(id) || !teams.contains(destination));
        selectedTpeByTeam.removeWhere((team, _) => !teams.contains(team));

        final scenario = _scenario(data, allAssets);
        final baseReport = engine.validate(scenario);
        final report = _withTpeValidation(baseReport, scenario);

        return Container(
          color: _bg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SPORTS TERMINAL / FRONT OFFICE', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 7),
              const Text('NBA Trade Machine', style: TextStyle(color: _text, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('2026-27 transaction workbench with complete player salary routing, first- and second-round draft rights, live TPEs, signing-exception context, team cap ledgers, hard caps, and explainable CBA validation.', style: TextStyle(color: _muted, height: 1.4)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _pill('2026-27', _blue),
                _pill('${data.records.length} CONTRACTS', _green),
                _pill('${allAssets.length} DRAFT RIGHTS', _cyan),
                _pill('${NbaTradeExceptionReference202627.tpes.where((e) => !e.exhausted).length} LIVE TPE RECORDS', _amber),
                _pill('${teams.length} TEAMS', _cyan),
              ]),
            ])),
            const SizedBox(height: 12),
            _controls(data),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final width = c.maxWidth >= 1120 ? (c.maxWidth - 12) / 2 : c.maxWidth;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final team in teams) SizedBox(width: width, child: _teamBoard(data, team)),
              ]);
            }),
            const SizedBox(height: 12),
            _tradeFlow(data, allAssets),
            const SizedBox(height: 12),
            _validation(report),
            const SizedBox(height: 12),
            _financials(report),
            const SizedBox(height: 12),
            _methodology(),
          ]),
        );
      },
    );
  }

  Widget _controls(NbaTradeContractSnapshot data) {
    final available = data.teams.where((t) => !teams.contains(t)).toList();
    return _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('TRADE SETUP'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ActionChip(
          avatar: const Icon(Icons.calendar_today_rounded, size: 15),
          label: Text('${tradeDate.month.toString().padLeft(2,'0')}/${tradeDate.day.toString().padLeft(2,'0')}/${tradeDate.year}'),
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: tradeDate, firstDate: DateTime(2026, 7, 1), lastDate: DateTime(2033, 6, 30));
            if (picked != null) setState(() => tradeDate = picked);
          },
        ),
        for (final team in teams)
          InputChip(
            label: Text(team),
            onDeleted: teams.length <= 2 ? null : () => setState(() {
              teams.remove(team);
              routes.removeWhere((id, destination) => destination == team || id.startsWith('$team:') || id.startsWith('$team-'));
              selectedTpeByTeam.remove(team);
            }),
          ),
        if (teams.length < 5)
          PopupMenuButton<String>(
            onSelected: (team) => setState(() => teams = [...teams, team]),
            itemBuilder: (_) => [for (final team in available) PopupMenuItem(value: team, child: Text(team))],
            child: const Chip(avatar: Icon(Icons.add_rounded, size: 15), label: Text('Add team')),
          ),
        FilterChip(label: const Text('Routed only'), selected: routedOnly, onSelected: (v) => setState(() => routedOnly = v)),
        ActionChip(
          avatar: const Icon(Icons.restart_alt_rounded, size: 15),
          label: const Text('Reset'),
          onPressed: () => setState(() { routes.clear(); selectedTpeByTeam.clear(); searches.clear(); routedOnly = false; }),
        ),
      ]),
      const SizedBox(height: 8),
      const Text('Operating thresholds: $166.0M salary cap · $201.69M tax · $210.69M first apron · $223.69M second apron.', style: TextStyle(color: _muted, fontSize: 10)),
    ]));
  }

  Widget _teamBoard(NbaTradeContractSnapshot data, String team) {
    final active = data.payroll(team, '2026-27');
    final ledger = NbaTeamCapReference202627.forTeam(team);
    final total = ledger?.totalCap ?? active;
    final tab = tabs[team] ?? 0;
    return _panelBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _blue), color: _panel2), child: Text(team, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 10))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(team, style: const TextStyle(color: _text, fontSize: 19, fontWeight: FontWeight.w900)),
          Text('${_money(total)} total cap · ${_money(ledger?.active ?? active)} active', style: const TextStyle(color: _muted, fontSize: 10)),
        ])),
        _pill(_tier(total), _tierColor(total)),
      ]),
      const SizedBox(height: 9),
      Wrap(spacing: 16, runSpacing: 8, children: [
        _mini(_signed(_cap-total), 'CAP ROOM'), _mini(_signed(_tax-total), 'TAX ROOM'), _mini(_signed(_first-total), '1ST APRON'), _mini(_signed(_second-total), '2ND APRON'),
        _mini((NbaTeamCapReference202627.hardCap[team] ?? 'none').toUpperCase(), 'HARD CAP'),
      ]),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value:0,label:Text('Players'),icon:Icon(Icons.person_rounded,size:15)),
          ButtonSegment(value:1,label:Text('Draft Picks'),icon:Icon(Icons.sports_basketball_rounded,size:15)),
          ButtonSegment(value:2,label:Text('Money / Exceptions'),icon:Icon(Icons.account_balance_wallet_rounded,size:15)),
          ButtonSegment(value:3,label:Text('Cap Table'),icon:Icon(Icons.table_chart_rounded,size:15)),
        ],
        selected:{tab}, showSelectedIcon:false,
        onSelectionChanged:(value)=>setState(()=>tabs[team]=value.first),
      ),
      const SizedBox(height: 10),
      if (tab==0) _players(data,team),
      if (tab==1) _picks(team),
      if (tab==2) _exceptions(team,total),
      if (tab==3) _capTable(team,ledger,active),
    ]));
  }

  Widget _players(NbaTradeContractSnapshot data, String team) {
    final query=(searches[team]??'').trim().toLowerCase();
    var rows=data.forTeam(team,'2026-27').where((p)=>query.isEmpty||p.player.toLowerCase().contains(query));
    if(routedOnly) rows=rows.where((p)=>routes.containsKey(p.id));
    return Column(children:[
      TextField(onChanged:(v)=>setState(()=>searches[team]=v),style:const TextStyle(color:_text),decoration:const InputDecoration(isDense:true,border:OutlineInputBorder(),prefixIcon:Icon(Icons.search),hintText:'Search roster')),
      const SizedBox(height:6),
      for(final p in rows) _assetRow(
        title:p.player,
        subtitle:p.guaranteed==null?'2026-27 contract':'Guaranteed field ${_money(p.guaranteed!)}',
        trailing:_money(p.salaryFor('2026-27')),
        control:_routeMenu(p.id,team),
      ),
    ]);
  }

  Widget _picks(String team) {
    var rows=draft.forTeam(team);
    if(routedOnly) rows=rows.where((p)=>routes.containsKey(p.id)).toList();
    return Column(children:[
      for(final p in rows) _assetRow(
        title:'${p.year} · ${p.round==1?'1st':'2nd'}',
        subtitle:p.description,
        badges:[if(p.frozen)_pill('FROZEN',_red),if(!p.tradable&&!p.frozen)_pill('OUT / UNAVAILABLE',_muted),if(p.swapRight)_pill('SWAP',_cyan),if(p.conditional)_pill('CONDITIONAL',_amber)],
        control:p.tradable?_routeMenu(p.id,team):null,
      ),
      if(rows.isEmpty) const Align(alignment:Alignment.centerLeft,child:Text('No draft rights under the current filter.',style:TextStyle(color:_muted))),
    ]);
  }

  Widget _exceptions(String team,double totalCap) {
    final balances=NbaTradeExceptionReference202627.signingExceptions[team]??const <String,double>{};
    final tpes=NbaTradeExceptionReference202627.forTeam(team,asOfIso:_dateIso(tradeDate));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(balances.isNotEmpty) ...[
        const Text('SIGNING EXCEPTIONS',style:TextStyle(color:_cyan,fontSize:9,fontWeight:FontWeight.w900)),
        const SizedBox(height:6),
        for(final e in balances.entries) _assetRow(title:_exceptionName(e.key),subtitle:_mleExplanation(e.key,totalCap),trailing:_money(e.value)),
      ],
      const SizedBox(height:8),
      const Text('TRADED PLAYER EXCEPTIONS',style:TextStyle(color:_cyan,fontSize:9,fontWeight:FontWeight.w900)),
      const SizedBox(height:6),
      if(tpes.isEmpty) const Text('No unexpired, unused TPE is recorded for this team on the selected trade date.',style:TextStyle(color:_muted)),
      for(final tpe in tpes)
        _assetRow(
          title:tpe.sourceTransaction,
          subtitle:'Expires ${tpe.expires}${tpe.note==null?'':' · ${tpe.note}'}',
          trailing:_money(tpe.available),
          badges:[if(tpe.original!=tpe.available)_pill('PARTIALLY USED',_amber),if(tpe.unusableAboveSecondApron)_pill('2ND APRON RESTRICTED',_red)],
          control:Radio<String>(value:tpe.id,groupValue:selectedTpeByTeam[team],onChanged:(v)=>setState(()=>selectedTpeByTeam[team]=v!)),
        ),
      if(selectedTpeByTeam[team]!=null)
        TextButton.icon(onPressed:()=>setState(()=>selectedTpeByTeam.remove(team)),icon:const Icon(Icons.close),label:const Text('Do not use a TPE')),
      const SizedBox(height:4),
      const Text('A TPE is selected as an acquisition mechanism for this team; it is not transferred to the other team. MLE/BAE balances are signing tools and are not used for trade salary matching.',style:TextStyle(color:_muted,fontSize:9,height:1.35)),
    ]);
  }

  Widget _capTable(String team,NbaTeamCapLedgerEntry? ledger,double fallbackActive) {
    if(ledger==null) return Text('No team cap ledger for $team.',style:const TextStyle(color:_muted));
    final rows=<MapEntry<String,double>>[
      MapEntry('Active salary',ledger.active),MapEntry('Dead money',ledger.dead),MapEntry('Retained salary',ledger.retained),MapEntry('Cap holds',ledger.capHolds),MapEntry('Incomplete-roster charges',ledger.incompleteRosterCharges),MapEntry('Other / unresolved cap adjustments',ledger.otherAdjustments),MapEntry('TOTAL CAP ALLOCATION',ledger.totalCap),
    ];
    return Column(children:[for(final row in rows) Container(padding:const EdgeInsets.symmetric(vertical:7),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_line))),child:Row(children:[Expanded(child:Text(row.key,style:TextStyle(color:row.key.startsWith('TOTAL')?_text:_muted,fontWeight:row.key.startsWith('TOTAL')?FontWeight.w900:FontWeight.w500))),Text(_money(row.value),style:const TextStyle(color:_text,fontWeight:FontWeight.w800))]))]);
  }

  Widget _assetRow({required String title,required String subtitle,String? trailing,Widget? control,List<Widget> badges=const[]}) => Container(
    width:double.infinity,padding:const EdgeInsets.symmetric(vertical:8),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_line))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(title,style:const TextStyle(color:_text,fontWeight:FontWeight.w900))),...badges.map((e)=>Padding(padding:const EdgeInsets.only(left:4),child:e))]),
        const SizedBox(height:2),Text(subtitle,style:const TextStyle(color:_muted,fontSize:9,height:1.3)),
      ])),
      if(trailing!=null)...[const SizedBox(width:8),Text(trailing,style:const TextStyle(color:_text,fontWeight:FontWeight.w900))],
      if(control!=null)...[const SizedBox(width:8),SizedBox(width:132,child:control)],
    ]),
  );

  Widget _routeMenu(String id,String origin)=>DropdownButtonFormField<String>(
    value:teams.where((t)=>t!=origin).contains(routes[id])?routes[id]:null,
    hint:const Text('Route to…'),isDense:true,
    items:[for(final t in teams.where((t)=>t!=origin)) DropdownMenuItem(value:t,child:Text(t))],
    onChanged:(v)=>setState((){if(v==null){routes.remove(id);}else{routes[id]=v;}}),
  );

  TradeScenario _scenario(NbaTradeContractSnapshot data,List<NbaFutureDraftAsset> allAssets) {
    final assignments=<TradeAssignment>[];
    final byPlayer={for(final p in data.records)p.id:p};
    final byPick={for(final p in allAssets)p.id:p};
    for(final route in routes.entries){
      final p=byPlayer[route.key];
      if(p!=null){
        assignments.add(TradeAssignment(asset:TradeAsset(id:p.id,type:TradeAssetType.player,label:p.player,originTeam:p.team,salary:p.salaryFor('2026-27'),metadata:{'guaranteed_amount':p.guaranteed,'source_status':p.sourceStatus}),destinationTeam:route.value));
        continue;
      }
      final pick=byPick[route.key];
      if(pick!=null){
        assignments.add(TradeAssignment(asset:TradeAsset(id:pick.id,type:TradeAssetType.draftPick,label:pick.label,originTeam:pick.team,metadata:{'draft_year':pick.year,'round':'${pick.round}','frozen':pick.frozen,'swap_right':pick.swapRight,'stepien_safe':pick.stepienSafe,'protection':pick.protection??'','conveyance_uncertain':pick.conditional,'source':pick.source}),destinationTeam:route.value));
      }
    }
    return TradeScenario(
      id:'sports-terminal-complete-2026-27',name:'2026-27 Trade',operatingSeason:'2026-27',asOfDateIso:_dateIso(tradeDate),teams:List.of(teams),assignments:assignments,
      capContexts:{for(final team in teams) team:TeamCapContext(team:team,teamSalary:NbaTeamCapReference202627.teamSalary(team,data.payroll(team,'2026-27')),salaryCap:_cap,taxLine:_tax,firstApron:_first,secondApron:_second,hardCappedAt:NbaTeamCapReference202627.hardCapAt(team,_first,_second),standardRosterPlayers:data.forTeam(team,'2026-27').length)},
    );
  }

  TradeValidationReport _withTpeValidation(TradeValidationReport base,TradeScenario scenario){
    final findings=[...base.findings];
    for(final team in teams){
      final selected=selectedTpeByTeam[team];
      if(selected==null) continue;
      final tpe=NbaTradeExceptionReference202627.tpes.where((e)=>e.id==selected).firstOrNull;
      if(tpe==null){
        findings.add(TradeValidationFinding(code:'TPE_MISSING',message:'$team selected a TPE that is not in the live ledger.',severity:TradeValidationSeverity.error,team:team));
        continue;
      }
      final expiry=DateTime.tryParse(tpe.expires);
      if(expiry!=null&&expiry.isBefore(tradeDate)){
        findings.add(TradeValidationFinding(code:'TPE_EXPIRED',message:'${tpe.sourceTransaction} expired ${tpe.expires}.',severity:TradeValidationSeverity.error,team:team));
        continue;
      }
      final context=scenario.capContexts[team]!;
      final incomingPlayers=scenario.incomingFor(team).where((a)=>a.asset.type==TradeAssetType.player).toList();
      final incoming=incomingPlayers.fold<double>(0,(sum,a)=>sum+a.asset.salary);
      if(incoming<=0){
        findings.add(TradeValidationFinding(code:'TPE_UNUSED',message:'$team selected ${_money(tpe.available)} TPE but is not receiving player salary.',severity:TradeValidationSeverity.warning,team:team));
        continue;
      }
      if(context.aboveSecondApron||tpe.unusableAboveSecondApron){
        findings.add(TradeValidationFinding(code:'TPE_APRON',message:'$team cannot use the selected TPE under the modeled second-apron restriction.',severity:TradeValidationSeverity.error,team:team));
        continue;
      }
      if(incoming>tpe.available+100000){
        findings.add(TradeValidationFinding(code:'TPE_AMOUNT',message:'$team receives ${_money(incoming)} in player salary, above the selected TPE capacity of ${_money(tpe.available)} plus the modeled $100K allowance.',severity:TradeValidationSeverity.error,team:team));
        continue;
      }
      findings.removeWhere((f)=>f.team==team&&f.code=='SALARY_MATCH');
      findings.add(TradeValidationFinding(code:'TPE_OK',message:'$team can absorb ${_money(incoming)} with ${tpe.sourceTransaction} (${_money(tpe.available)} available; expires ${tpe.expires}).',severity:TradeValidationSeverity.info,team:team));
    }
    return TradeValidationReport(findings:findings,teamSummaries:base.teamSummaries);
  }

  Widget _tradeFlow(NbaTradeContractSnapshot data,List<NbaFutureDraftAsset> assets)=>_panelBox(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    _section('TRADE FLOW'),const SizedBox(height:8),
    if(routes.isEmpty) const Text('Route at least one player or draft right to begin.',style:TextStyle(color:_muted))
    else for(final team in teams) Builder(builder:(_){
      final sent=<String>[],received=<String>[];
      for(final p in data.records){if(p.team==team&&routes[p.id]!=null)sent.add('${p.player} → ${routes[p.id]}');if(routes[p.id]==team)received.add(p.player);}
      for(final p in assets){if(p.team==team&&routes[p.id]!=null)sent.add('${p.label} → ${routes[p.id]}');if(routes[p.id]==team)received.add(p.label);}
      if(sent.isEmpty&&received.isEmpty)return const SizedBox.shrink();
      return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:_panel2,border:Border.all(color:_line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(team,style:const TextStyle(color:_text,fontWeight:FontWeight.w900)),Text('Sends: ${sent.join(' • ')}',style:const TextStyle(color:_red,fontSize:10)),Text('Receives: ${received.join(' • ')}',style:const TextStyle(color:_green,fontSize:10)),if(selectedTpeByTeam[team]!=null)Text('Uses TPE: ${NbaTradeExceptionReference202627.tpes.where((e)=>e.id==selectedTpeByTeam[team]).firstOrNull?.sourceTransaction??'selected exception'}',style:const TextStyle(color:_cyan,fontSize:10))]));
    })
  ]));

  Widget _validation(TradeValidationReport report)=>_panelBox(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:_section('CBA / STRUCTURAL VALIDATION')),_pill(report.isValid?'PASS':'${report.errorCount} ERRORS',report.isValid?_green:_red),const SizedBox(width:6),_pill('${report.warningCount} WARNINGS',report.warningCount==0?_green:_amber)]),
    const SizedBox(height:8),
    for(final f in report.findings) Padding(padding:const EdgeInsets.only(bottom:6),child:Text('${f.code}: ${f.message}',style:TextStyle(color:f.severity==TradeValidationSeverity.error?_red:f.severity==TradeValidationSeverity.warning?_amber:_muted,height:1.3))),
  ]));

  Widget _financials(TradeValidationReport report)=>_panelBox(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    _section('POST-TRADE FINANCIALS'),const SizedBox(height:8),
    for(final e in report.teamSummaries.entries) Container(width:double.infinity,margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:_panel2,border:Border.all(color:_line)),child:Wrap(spacing:20,runSpacing:8,children:[_mini(e.key,'TEAM'),_mini(_money(e.value.outgoingSalary),'MATCH OUT'),_mini(_money(e.value.incomingSalary),'MATCH IN'),_mini(_money(e.value.maximumIncomingSalary),'BASE MAX IN'),_mini(_money(e.value.postTradeSalary),'POST CAP'),_mini('${e.value.projectedRosterPlayers}','ROSTER'),_mini(e.value.apronStatus.toUpperCase(),'STATUS')]))
  ]));

  Widget _methodology()=>_panelBox(const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('SOURCE / ACCOUNTING NOTES',style:TextStyle(color:_cyan,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.9)),SizedBox(height:7),
    Text('Player matching uses the supplied 2026-27 salary schedule. Team cap position uses the supplied Spotrac-style total-cap ledger and exposes active salary, dead money, retained salary, cap holds, incomplete-roster charges, and unresolved adjustments separately. Draft rights cover both rounds for every team for 2027-2033, with conditional/frozen/outgoing interests retained instead of converted to fake clean picks. TPEs use the supplied live exception ledger with source transaction, remaining amount, and expiration date. Signing exceptions are reference/acquisition tools, not trade-matching salary.',style:TextStyle(color:_muted,height:1.45)),
  ]));
}

Widget _panelBox(Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_panel,border:Border.all(color:_line),borderRadius:BorderRadius.circular(14)),child:child);
Widget _section(String text)=>Text(text,style:const TextStyle(color:_cyan,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.9));
Widget _pill(String text,Color color)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:_panel2,border:Border.all(color:color.withValues(alpha:.55)),borderRadius:BorderRadius.circular(99)),child:Text(text,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900)));
Widget _mini(String value,String label)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(color:_text,fontWeight:FontWeight.w900,fontSize:12)),Text(label,style:const TextStyle(color:_muted,fontSize:8,fontWeight:FontWeight.w800))]);
String _money(double v){final sign=v<0?'-':'';final a=v.abs();if(a>=1000000)return '$sign\$${(a/1000000).toStringAsFixed(2)}M';if(a>=1000)return '$sign\$${(a/1000).toStringAsFixed(0)}K';return '$sign\$${a.toStringAsFixed(0)}';}
String _signed(double v)=>v>=0?'+${_money(v)}':_money(v);
String _tier(double p){if(p>_second)return '2ND APRON';if(p>_first)return '1ST APRON';if(p>_tax)return 'TAX';if(p>_cap)return 'OVER CAP';return 'CAP SPACE';}
Color _tierColor(double p){if(p>_second)return _red;if(p>_tax)return _amber;if(p>_cap)return _blue;return _green;}
String _dateIso(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
String _exceptionName(String k)=>switch(k){'room_mle'=>'Room MLE','non_tax_mle'=>'Non-Taxpayer MLE','tax_mle'=>'Taxpayer MLE','bae'=>'Bi-Annual Exception',_=>k};
String _mleExplanation(String k,double total)=>switch(k){'room_mle'=>NbaMleRules202627.roomRule,'non_tax_mle'=>NbaMleRules202627.nonTaxpayerRule,'tax_mle'=>NbaMleRules202627.taxpayerRule,'bae'=>'Bi-Annual Exception remaining balance.',_=>'Remaining signing-exception balance.'};
