part of '../voice_assistant_controller.dart';

/// ═══════════════════════════════════════════════════════════════════
/// TOOL DISPATCH — single switch from Gemini tool name → handler
///
/// HOW TO ADD A NEW VOICE TOOL (3 steps only):
///
/// 1) `tools_definition.dart`
///    Add a map with `name`, `description`, `parameters` so Gemini
///    knows the tool exists and when to call it.
///
/// 2) The matching `tools_*.dart` file
///    Implement e.g. `Future<void> _myTool(String callId, Map args) async`
///    Call `_respondToFunction(callId, 'myTool', result)` when done.
///
/// 3) THIS FILE
///    Add one `case 'myTool': await _myTool(callId, args);` below.
///
/// Optional: if the tool writes data, set `_summaryCache = null`.
/// Optional: block it on certain screens via `_routineBlockedTools`
///           / `_subjectBlockedTools` in `voice_assistant_controller.dart`.
/// ═══════════════════════════════════════════════════════════════════
extension VoiceAssistantToolDispatch on VoiceAssistantController {
  Future<void> _dispatchVoiceTool(
    String callId,
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      // ── Read ──
      case 'getAllData':
        await _getAllData(callId);
      case 'getSubjectDetail':
        await _getSubjectDetail(callId, args);
      case 'getTopicStatus':
        await _getTopicStatus(callId, args);
      case 'getAllTopicsRevisionDates':
        await _getAllTopicsRevisionDates(callId, args);

      // ── Create / delete subjects & topics ──
      case 'addSubjectsBulk':
        await _addSubjectsBulk(callId, args);
      case 'addSubject':
        await _addSubject(callId, args);
      case 'addTopic':
        await _addTopic(callId, args);
      case 'addMultipleTopics':
        await _addMultipleTopics(callId, args);
      case 'deleteAllSubjects':
        await _deleteAllSubjects(callId, args);
      case 'deleteSubjectByName':
        await _deleteSubjectByName(callId, args);
      case 'deleteTopicByName':
        await _deleteTopicByName(callId, args);

      // ── Revision / first-read progress ──
      case 'markFirstReadCompleted':
        await _markFirstReadCompleted(callId, args);
      case 'markRevisionCompleted':
        await _markRevisionCompleted(callId, args);

      // ── Class & daily routines ──
      case 'registerClassRoutine':
        await _registerClassRoutine(callId, args);
      case 'registerDailyRoutine':
        await _registerDailyRoutine(callId, args);
      case 'deleteClassRoutine':
        await _deleteClassRoutine(callId, args);
      case 'deleteDailyRoutine':
        await _deleteDailyRoutine(callId, args);

      default:
        debugPrint('[Gemini] ⚠️ Unknown function: $name');
        _respondToFunction(callId, name, {
          'success': false,
          'error': 'Unknown function "$name"',
        }, params: args);
    }
  }
}
