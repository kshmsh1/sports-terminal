import '../models/generated_terminal_report.dart';
import '../models/research_object.dart';
import '../models/terminal_board.dart';
import 'generated_report_research_service.dart';
import 'research_object_service.dart';
import 'terminal_board_store.dart';

class TerminalResearchWorkflowService {
  const TerminalResearchWorkflowService({
    this.bridge = const GeneratedReportResearchService(),
    this.researchService = const ResearchObjectService(),
    this.boardStore = const TerminalBoardStore(),
  });

  final GeneratedReportResearchService bridge;
  final ResearchObjectService researchService;
  final TerminalBoardStore boardStore;

  Future<ResearchObject> saveGeneratedReport(
    GeneratedTerminalReport report, {
    required String authorId,
  }) async {
    final object = bridge.fromReport(report, authorId: authorId);
    return researchService.saveIfNewFingerprint(object);
  }

  Future<TerminalBoard> addGeneratedReportToBoard(
    GeneratedTerminalReport report, {
    required String authorId,
    String boardId = 'institutional-research-board',
    String boardTitle = 'Institutional Research Board',
  }) async {
    final research = await saveGeneratedReport(report, authorId: authorId);
    final panel = TerminalBoardPanel(
      id: 'research-${research.contentFingerprint.isEmpty ? research.revisionKey : research.contentFingerprint}',
      kind: 'research-report',
      title: research.title,
      payload: {
        'researchRevisionKey': research.revisionKey,
        'artifactType': research.artifactType,
        'contentFingerprint': research.contentFingerprint,
        'dataRelease': research.dataRelease,
        'status': research.status,
        'research': research.toJson(),
      },
      width: 2,
      height: 2,
    );
    return boardStore.appendPanel(
      boardId: boardId,
      boardTitle: boardTitle,
      description: 'Durable generated reports and reproducible Sports Terminal research objects.',
      panel: panel,
    );
  }
}
