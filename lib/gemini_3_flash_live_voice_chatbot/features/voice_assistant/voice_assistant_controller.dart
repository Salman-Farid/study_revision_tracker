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
import '../../../app/data/services/supabase_service.dart';
import '../../../app/data/services/image_search_service.dart';
import '../../../app/core/services/notification_service.dart';
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

  final RxBool _micMuted = false.obs;
  bool get isMuted => _micMuted.value;
  bool _mutedByFunctionCall = false;

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
  Timer? _reconnectTimer;
  bool _userInitiatedStop = false;
  bool _isStopping = false;

  // ── FIX: _summaryCache is now actually read before querying the DB.
  // Previously it was written on every getAllData call but never read,
  // making it dead code. Now: cache hit → return immediately (no DB scan);
  // any write op (add/delete) sets _summaryCache = null to invalidate.
  Map<String, dynamic>? _summaryCache;

  // Tools blocked in routine mode — routine can only fetch data, never modify subjects/topics
  static const _routineBlockedTools = {
    'addSubjectsBulk', 'addSubject', 'addTopic', 'addMultipleTopics',
    'deleteAllSubjects', 'deleteSubjectByName', 'deleteTopicByName',
    'markFirstReadCompleted', 'markRevisionCompleted',
  };

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
    _sheetAnimCtrl?.dispose();
    _expandAnimCtrl?.dispose();
    textCtrl.dispose();
    scrollCtrl.dispose();
    focusNode.dispose();
    _service.stopSession();
    super.onClose();
  }

  void sendText(String text) {
    if (connectionState.value != ws.ConnectionState.connected) {
      debugPrint('[Gemini] 🚫 Cannot send text — not connected');
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: 'Not connected yet — please wait a moment and try again.',
      ));
      _triggerUiUpdate();
      return;
    }
    try {
      _showThinking();
      _service.sendText(text);
    } catch (e) {
      debugPrint('[Gemini] ⚠️ sendText failed: $e');
      _clearThinking();
      _exitLoading('sendText-failed');
      messages.add(ChatMessage(role: ChatRole.system, text: 'Failed to send message: $e'));
      _triggerUiUpdate();
    }
  }
}
