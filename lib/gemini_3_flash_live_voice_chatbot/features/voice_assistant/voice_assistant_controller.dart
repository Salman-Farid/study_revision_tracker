import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/repositories/subject_repository.dart';
import '../../../app/data/repositories/topic_repository.dart';
import '../../../app/data/repositories/revision_repository.dart';
import '../../../app/data/repositories/routine_repository.dart';
import '../../../app/data/models/daily_routine_model.dart';
import '../../../app/data/models/topic_model.dart';
import '../../../app/data/services/supabase_service.dart';
import '../../../app/data/services/image_search_service.dart';
import '../../../app/core/services/notification_service.dart';
import '../../../app/core/services/connectivity_service.dart';
import '../../../app/domain/routine/routine_time_utils.dart';
import '../../../app/modules/routine/widgets/routine_break_taglines.dart';
import '../../../app/modules/routine/widgets/routine_meal_taglines.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../services/gemini_live_service.dart';

part 'controller/dialogue_panel_sizing.dart';

// ─────────────────────────────────────────────────────────────
// Voice assistant controller — file map (start here if new):
//   controller/session_lifecycle.dart     connect / reconnect / stop
//   controller/mic_state.dart             mute / unmute / echo guard
//   controller/function_call_batching.dart batch Gemini tool replies
//   controller/tools_definition.dart      tool schemas for Gemini
//   controller/tool_dispatch.dart         name → handler switch (add tools here)
//   controller/tools_subject_*.dart       subject/topic voice tools
//   controller/tools_topic_revision.dart  mark read / revision done
//   controller/tools_class_daily_routine.dart class + daily routine tools
//   controller/dialogue_panel_sizing.dart floating panel geometry
// ─────────────────────────────────────────────────────────────

part 'controller/function_call_batching.dart';
part 'controller/mic_state.dart';
part 'controller/tools_class_daily_routine.dart';
part 'controller/session_lifecycle.dart';
part 'controller/tool_dispatch.dart';
part 'controller/tools_subject_create_delete.dart';
part 'controller/tools_subject_read.dart';
part 'controller/tools_definition.dart';
part 'controller/tools_topic_revision.dart';

// ── Top-level constants so regex is compiled once, not per-call ──
final _normalizeNonWord = RegExp(r'[^\w\s]');
final _normalizeWhitespace = RegExp(r'\s+');

final _cjkGlyphs = RegExp(r'[\u4e00-\u9fff]+');

String _sanitizeName(String s) => s.replaceAll(_cjkGlyphs, '').trim();

class VoiceAssistantController extends GetxController with GetTickerProviderStateMixin {
  GeminiLiveService get _service => Get.find<GeminiLiveService>();
  SubjectRepository get _subjectRepo => Get.find<SubjectRepository>();
  TopicRepository get _topicRepo => Get.find<TopicRepository>();
  RevisionRepository get _revRepo => Get.find<RevisionRepository>();
  RoutineRepository get _routineRepo => Get.find<RoutineRepository>();

  void refreshClassRoutines() {
    final s = Get.find<SupabaseService>();
    s.refreshClassRoutines();
  }

  void refreshDailyRoutines() {
    final s = Get.find<SupabaseService>();
    s.refreshDailyRoutines();
  }

  String? currentSubjectName;

  /// Parent TOPIC the user is viewing (subtopic screen / topic detail).
  /// Voice writes without an explicit parent must nest under this topic.
  String? currentTopicName;
  String? currentRoutineMode; // 'daily' or 'class' — set by RoutineController
  String toolMode = 'full'; // 'full' or 'routine' — filters available tools

  // ── UI controllers ──
  final textCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  final focusNode = FocusNode();
  AnimationController? _sheetAnimCtrl;
  AnimationController? _expandAnimCtrl;

  // ── Dialogue overlay state ──
  final isExpanded = false.obs;
  final dialogueOffset = Offset(12, 200).obs;
  bool dialogueOffsetInitialized = false;

  /// User-resizable panel size. 0 = not initialized (use defaults).
  final dialogueWidth = 0.0.obs;
  final dialogueHeight = 0.0.obs;
  /// Desktop/tablet: corner press-and-drag resize.
  final isResizingDialogue = false.obs;

  /// Compact card defaults — never stretch to full window width on desktop.
  static const double desktopDialogueW = 400;
  static const double minDialogueW = 300;
  static const double maxDialogueW = 640;
  static const double minDialogueH = 240;
  static const double maxDialogueHRatio = 0.85;

  Animation<double>? get sheetFade => _sheetAnimCtrl != null
      ? CurvedAnimation(parent: _sheetAnimCtrl!, curve: Curves.easeOut)
      : null;
  Animation<Offset>? get sheetSlide => _sheetAnimCtrl != null
      ? Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
      .animate(CurvedAnimation(parent: _sheetAnimCtrl!, curve: Curves.easeOutCubic))
      : null;
  Animation<double>? get expandAnim => _expandAnimCtrl != null
      ? CurvedAnimation(parent: _expandAnimCtrl!, curve: Curves.easeInOutCubic)
      : null;

  void initSheetAnim() {
    _sheetAnimCtrl?.dispose();
    _sheetAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sheetAnimCtrl!.forward();
  }

  void initExpandAnim() {
    _expandAnimCtrl?.dispose();
    _expandAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  }

  void reverseSheetAnim() {
    _sheetAnimCtrl?.reverse().then((_) {
      stopSession();
      if (Get.context != null) Navigator.pop(Get.context!);
    });
  }

  void toggleExpanded() {
    isExpanded.value = !isExpanded.value;
    if (isExpanded.value) {
      _expandAnimCtrl?.forward();
    } else {
      _expandAnimCtrl?.reverse();
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ignore if not attached or attached to more than one ListView
      // (sheet + screen share this controller).
      if (!scrollCtrl.hasClients || scrollCtrl.positions.length != 1) return;
      final pos = scrollCtrl.position;
      if (!pos.hasContentDimensions) return;
      scrollCtrl.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void sendTextFromInput() {
    final text = textCtrl.text.trim();
    if (text.isEmpty) return;
    sendText(text);
    textCtrl.clear();
    focusNode.unfocus();
    scrollToBottom();
  }

  final messages = <ChatMessage>[].obs;
  final connectionState = ws.ConnectionState.disconnected.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;

  final RxBool isLoading = false.obs;

  /// Floor / mic UX — shared by all voice UIs.
  /// Mic stays OFF while assistant is thinking, searching, working, or speaking.
  final RxString floorLabel = 'Connecting...'.obs;
  final RxBool floorBusy = false.obs;
  Timer? _userTurnWatchdog;
  Timer? _silentRecoverTimer;
  /// True once a session was requested this controller lifetime.
  bool _sessionStartRequested = false;
  /// Set when the user spoke/typed; cleared when assistant text arrives.
  bool _awaitingAssistantReply = false;

  /// True if any non-empty assistant bubble exists after the latest user message.
  bool _assistantRepliedSinceUser() {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role == ChatRole.user) return false;
      if (m.role == ChatRole.assistant && m.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  void _removeSilentNotices() {
    messages.removeWhere((m) =>
        m.role == ChatRole.system &&
        (m.text.contains('did not reply') ||
            m.text.contains('Still no reply') ||
            m.text.contains('taking too long') ||
            m.text.contains('No reply from Pootu')));
  }

  /// Delayed recovery — NEVER fire while Pootu is still thinking/working/streaming.
  void _scheduleSilentRecover(Duration delay, {required String reason}) {
    _silentRecoverTimer?.cancel();
    _silentRecoverTimer = Timer(delay, () {
      if (!_awaitingAssistantReply) return;
      if (_assistantRepliedSinceUser()) {
        _awaitingAssistantReply = false;
        _removeSilentNotices();
        return;
      }
      if (_pendingCallIds.isNotEmpty || _batchInProgress) {
        // Tools still running — wait a bit longer for the spoken/text reply.
        _scheduleSilentRecover(const Duration(seconds: 6), reason: reason);
        return;
      }
      if (_streamingMessage != null && _streamingMessage!.text.trim().isNotEmpty) {
        _awaitingAssistantReply = false;
        _removeSilentNotices();
        return;
      }
      debugPrint('[Gemini] ⏰ Silent recover: $reason');
      _noteSilentTurn(reason: reason);
    });
  }

  final RxBool _micMuted = false.obs;
  bool get isMuted => _micMuted.value;
  bool _mutedByFunctionCall = false;

  /// True while the assistant owns the turn (not the user).
  bool get assistantOwnsFloor =>
      isLoading.value ||
      isProcessing.value ||
      _batchInProgress ||
      _pendingCallIds.isNotEmpty ||
      _thinkingMessage != null ||
      _batchProgressMessage != null ||
      _streamingMessage != null;

  /// Mic button state: OFF (muted icon) whenever assistant owns the floor.
  bool get micIconOff => isMuted || assistantOwnsFloor;

  void _updateFloorStatus() {
    final busy = assistantOwnsFloor;
    floorBusy.value = busy;
    floorLabel.value = () {
      if (connectionState.value == ws.ConnectionState.connecting) {
        return 'Connecting...';
      }
      if (connectionState.value == ws.ConnectionState.connected) {
        if (_pendingCallIds.isNotEmpty || _batchInProgress) return 'Working...';
        if (_thinkingMessage != null || isLoading.value) return 'Thinking...';
        if (_streamingMessage != null) return 'Speaking...';
        if (isProcessing.value) return 'Processing...';
        if (_awaitingAssistantReply) return 'No reply — tap mic or send again';
        if (isMuted) return 'Mic off — tap mic';
        return 'Listening';
      }
      // Not connected:
      // - Opening / never started / still coming up → Connecting (not Offline).
      // - Offline ONLY when the phone has no internet.
      final netDown = Get.isRegistered<ConnectivityService>() &&
          !Get.find<ConnectivityService>().isConnected.value;
      if (netDown) return 'Offline';
      if (_sessionStartRequested &&
          _reconnectAttempts >= VoiceAssistantController._maxReconnectAttempts) {
        // Reconnect gave up — stop pretending, tell the user to retry.
        return 'Connection lost — tap mic';
      }
      if (connectionState.value == ws.ConnectionState.error) {
        // Honest failure state — the reconnect loop retries automatically,
        // and the user can tap mic to retry manually.
        return 'Connection failed — retrying…';
      }
      return _sessionStartRequested ? 'Connecting...' : 'Tap mic to connect';
    }();
  }

  /// Controls visibility of the StudyAssistantDialogue overlay.
  final RxBool showDialogue = false.obs;

  int _generation = 0;

  StreamSubscription? _connectionSub;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _functionCallSub;
  StreamSubscription? _turnCompleteSub;

  Timer? _micReconcileTimer;

  String _lastAssistantText = '';
  DateTime? _lastUnmuteAt;
  Timer? _unmuteDebounceTimer;

  final LinkedHashSet<String> _processedCallIds = LinkedHashSet();
  final LinkedHashSet<String> _recentCalls = LinkedHashSet();
  final LinkedHashSet<String> _pendingCallIds = LinkedHashSet();
  final List<Map<String, dynamic>> _pendingResponses = [];
  Timer? _pendingCallsSafetyTimer;
  Timer? _batchFlushTimer;

  static const int _maxPendingCalls = 60;

  static const int _bulkChunkSize = 8;
  static const int _bulkConcurrency = 4;
  static const int _maxReportedFailures = 15;

  final Map<String, Completer<dynamic>> _subjectCreationCompleters = {};

  Timer? _uiRefreshDebounce;

  bool _batchInProgress = false;
  bool _batchJustCompleted = false;
  int _batchTotal = 0;
  int _batchCompleted = 0;
  int _batchCompletedCount = 0;
  int _batchRetryCount = 0;
  static const int _maxBatchRetries = 2;
  ChatMessage? _batchProgressMessage;
  ChatMessage? _thinkingMessage;

  ChatMessage? _streamingMessage;

  static const int _maxReconnectAttempts = 3;
  int _reconnectAttempts = 0;
  bool _reconnectGiveUpNotified = false;
  Timer? _reconnectTimer;
  bool _userInitiatedStop = false;
  bool _isStopping = false;
  bool _isStarting = false;
  /// Completes when the in-flight stopSession body has fully finished.
  /// startSession awaits this so stop+start fired back-to-back cannot race.
  Future<void>? _stopFuture;

  // Short TTL — stale cache after delete/create caused ghost routines + Thinking loops.
  Map<String, dynamic>? _summaryCache;
  DateTime? _summaryCachedAt;
  Timer? _thinkingSafetyTimer;

  // Tools blocked in routine mode — routine can only fetch data, never modify subjects/topics
  static const _routineBlockedTools = {
    'addSubjectsBulk', 'addSubject', 'addTopic', 'addSubtopics',
    'addMultipleTopics', 'deleteAllSubjects', 'deleteSubjectByName',
    'deleteTopicByName', 'markFirstReadCompleted', 'markRevisionCompleted',
  };

  /// Topics just created that still need "want subtopics under X?" asked.
  /// Gate blocks further subject-level topic writes until answered / confirmed.
  final List<Map<String, String>> pendingSubtopicAsks = [];

  void _noteTopicCreated(String subjectName, String topicName) {
    pendingSubtopicAsks.removeWhere((e) =>
        e['subject']!.toLowerCase() == subjectName.toLowerCase() &&
        e['topic']!.toLowerCase() == topicName.toLowerCase());
    pendingSubtopicAsks.add({'subject': subjectName, 'topic': topicName});
  }

  void _clearPendingSubtopicAsk(String subjectName, String topicName) {
    pendingSubtopicAsks.removeWhere((e) =>
        e['subject']!.toLowerCase() == subjectName.toLowerCase() &&
        e['topic']!.toLowerCase() == topicName.toLowerCase());
  }

  void _clearPendingSubtopicAsksForSubject(String subjectName) {
    pendingSubtopicAsks.removeWhere(
        (e) => e['subject']!.toLowerCase() == subjectName.toLowerCase());
  }

  String? _pendingAskForSubject(String subjectName) {
    final names = pendingSubtopicAsks
        .where((e) => e['subject']!.toLowerCase() == subjectName.toLowerCase())
        .map((e) => e['topic']!)
        .toList();
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  bool _confirmNewTopicsArg(Map<String, dynamic> args) =>
      args['confirmNewTopics'] == true;

  String _mustAskSubtopicsMessage(String subjectName, List<String> topicNames) {
    final list = topicNames.join(', ');
    final pronoun = topicNames.length == 1 ? 'it' : 'them';
    return 'MANDATORY NEXT STEP — do not skip. '
        'In the USER\'S language ask once: "Do you want any subtopics under $list?" then WAIT. '
        'If they name subtopics under a topic → call ONLY '
        'addSubtopics(subjectName: "$subjectName", topicName: "<that topic>", names: [user-said names]). '
        'SUBTOPIC ≠ TOPIC. Subtopics go UNDER a topic, never as new subject-level topics. '
        'Do NOT call addTopic/addMultipleTopics/addSubjectsBulk for those subtopic names. '
        'If they want NEW subject-level topics instead, call the write tool again with confirmNewTopics: true. '
        'Parent $pronoun Done only when ALL subtopics finish first-read + all 6 revisions.';
  }

  /// Returns true when the call was blocked (pending subtopic question).
  bool _gatePendingSubtopicAsk(
    String callId,
    String toolName,
    String subjectName,
    Map<String, dynamic> args,
    List<String> names,
  ) {
    if (_confirmNewTopicsArg(args)) return false;
    final pending = _pendingAskForSubject(subjectName);
    if (pending == null || pending.isEmpty) return false;
    final pendingLower =
        pending.split(', ').map((n) => n.toLowerCase()).toSet();
    final newLower = names.map((n) => n.toLowerCase()).toSet();
    if (newLower.isNotEmpty && newLower.every(pendingLower.contains)) {
      return false;
    }
    _respondToFunction(callId, toolName, {
      'success': false,
      'blocked': 'hierarchy_pending_subtopic_question',
      'error':
          'HIERARCHY GATE: Topic(s) "$pending" under subject "$subjectName" were just created. '
          'You MUST ask the user first (their language): '
          '"Do you want any subtopics under $pending?" WAIT. '
          'If the user listed subtopics under one of those topics → call '
          'addSubtopics(subjectName: "$subjectName", topicName: "<parent topic>", names: [...]). '
          'Subtopic goes UNDER the topic, NOT as a new subject-level topic. '
          'If the user explicitly wants NEW subject-level topics → call $toolName again with confirmNewTopics: true. '
          'Names you attempted now: ${names.join(', ')}.',
      'pending_subtopic_question_for': pending,
      'must_use_tool_if_subtopics': 'addSubtopics',
    }, params: args);
    return true;
  }

  // Tools blocked on subject/topic screens — never create class/daily routines here
  static const _subjectBlockedTools = {
    'registerClassRoutine', 'registerDailyRoutine',
    'deleteClassRoutine', 'deleteDailyRoutine',
  };

  final List<Map<String, dynamic>> _tools = buildVoiceAssistantTools();

  @override
  void onInit() {
    super.onInit();
    _setupListeners();
    _startMicReconcileTimer();
    // Always keep the chat pinned to the latest message.
    ever(messages, (_) => scrollToBottom());
    ever(isProcessing, (_) => scrollToBottom());
    ever(connectionState, (_) => scrollToBottom());
  }

  @override
  void onClose() {
    _generation++;
    _connectionSub?.cancel();
    _transcriptSub?.cancel();
    _audioSub?.cancel();
    _functionCallSub?.cancel();
    _turnCompleteSub?.cancel();
    _pendingCallsSafetyTimer?.cancel();
    _batchFlushTimer?.cancel();
    _micReconcileTimer?.cancel();
    _reconnectTimer?.cancel();
    _unmuteDebounceTimer?.cancel();
    _uiRefreshDebounce?.cancel();
    _userTurnWatchdog?.cancel();
    _thinkingSafetyTimer?.cancel();
    _silentRecoverTimer?.cancel();
    _sheetAnimCtrl?.dispose();
    _expandAnimCtrl?.dispose();
    textCtrl.dispose();
    scrollCtrl.dispose();
    focusNode.dispose();
    _service.stopSession();
    super.onClose();
  }

  /// User-visible recovery when the model goes silent (empty turn / timeout).
  /// [force] unsticks Thinking even if a tool batch looks "in progress".
  void _noteSilentTurn({String reason = '', bool force = false}) {
    if (force) {
      _pendingCallIds.clear();
      _batchInProgress = false;
      _batchJustCompleted = false;
    } else {
      if (_pendingCallIds.isNotEmpty || _batchInProgress) return;
    }
    if (!_awaitingAssistantReply && _thinkingMessage == null && !isLoading.value) {
      return;
    }
    if (_assistantRepliedSinceUser() ||
        (_streamingMessage != null &&
            _streamingMessage!.text.trim().isNotEmpty)) {
      _awaitingAssistantReply = false;
      _removeSilentNotices();
      _clearThinking();
      isProcessing.value = false;
      _exitLoading('reply-seen');
      return;
    }
    _awaitingAssistantReply = false;
    _clearThinking();
    isProcessing.value = false;
    _exitLoading('silent-turn');
    messages.add(ChatMessage(
      role: ChatRole.system,
      text: reason.isEmpty
          ? 'Still waiting for Pootu… Tap mic or send again if it stays quiet.'
          : reason,
    ));
    _updateFloorStatus();
    _triggerUiUpdate();
  }

  void sendText(String text) {
    if (connectionState.value != ws.ConnectionState.connected) {
      debugPrint('[Gemini] 🚫 Cannot send text — not connected');
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Not connected yet — please wait a moment and try again.',
      ));
      _updateFloorStatus();
      _triggerUiUpdate();
      return;
    }
    try {
      // Always show the user's bubble immediately (even if Live has no echo).
      messages.add(ChatMessage(role: ChatRole.user, text: text));
      _removeSilentNotices();
      // User floor ends — assistant is about to work/speak. Mic stays OFF.
      isProcessing.value = true;
      _awaitingAssistantReply = true;
      _setMicMuted(true, reason: 'user message — assistant turn');
      _showThinking();
      _service.sendText(text);
      _userTurnWatchdog?.cancel();
      _silentRecoverTimer?.cancel();
      // getAllData + speech can take >20s — only flag silence much later.
      _userTurnWatchdog = Timer(const Duration(seconds: 40), () {
        if (_assistantRepliedSinceUser() || !_awaitingAssistantReply) {
          _awaitingAssistantReply = false;
          _removeSilentNotices();
          return;
        }
        if (_pendingCallIds.isNotEmpty || _batchInProgress) {
          _updateFloorStatus();
          _triggerUiUpdate();
          return;
        }
        _noteSilentTurn(
          reason:
              'Still waiting for Pootu… Tap mic or send again if it stays quiet.',
        );
      });
      _updateFloorStatus();
      _triggerUiUpdate();
    } catch (e) {
      debugPrint('[Gemini] ⚠️ sendText failed: $e');
      _clearThinking();
      isProcessing.value = false;
      _awaitingAssistantReply = false;
      _exitLoading('sendText-failed');
      messages.add(ChatMessage(role: ChatRole.system, text: 'Failed to send message: $e'));
      _updateFloorStatus();
      _triggerUiUpdate();
    }
  }
}


