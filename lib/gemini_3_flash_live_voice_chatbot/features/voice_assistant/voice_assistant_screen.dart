import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/core/constants/app_constants.dart';
import '../../../app/theme/app_theme.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../shared/widgets/thinking_dots.dart';
import 'voice_assistant_controller.dart';
import 'widgets/shared/chat_bubbles.dart';
import 'widgets/shared/error_bar.dart';
part 'widgets/full_screen/chat_bubbles.dart';
part 'widgets/full_screen/error_bar.dart';
part 'widgets/full_screen/screen_layout.dart';
part 'widgets/full_screen/sheet_layout.dart';

class VoiceAssistantScreen extends StatelessWidget {
  const VoiceAssistantScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (_) => const VoiceAssistantScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceAssistantController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (c.connectionState.value == ws.ConnectionState.disconnected) {
      c.startSession();
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) c.stopSession();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(c, isDark),
              Expanded(
                child: Obx(() {
                  final msgs = c.messages;
                  final processing = c.isProcessing.value;

                  if (msgs.isEmpty &&
                      c.connectionState.value == ws.ConnectionState.connecting) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppConstants.primaryColor,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Connecting...',
                            style: TextStyle(
                              color: (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                  .withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  c.scrollToBottom();
                  return ListView.builder(
                    controller: c.scrollCtrl,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: msgs.length + (processing ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == msgs.length && processing) {
                        return const _ThinkingBubble();
                      }
                      return _ChatBubble(
                        message: msgs[i],
                        isDark: isDark,
                      );
                    },
                  );
                }),
              ),
              Obx(() {
                final st = c.connectionState.value;
                if (st == ws.ConnectionState.error) {
                  final err = c.errorMessage.value;
                  return _ErrorBar(
                    message: err.isNotEmpty ? err : 'Connection lost',
                    onRetry: () => c.startSession(),
                    isDark: isDark,
                  );
                }
                return const SizedBox.shrink();
              }),
              Obx(() {
                final st = c.connectionState.value;
                if (st == ws.ConnectionState.connecting) return const SizedBox.shrink();

                final muted = c.isMuted;
                final processing = c.isProcessing.value;
                final statusText = processing
                    ? 'Processing your request...'
                    : muted
                        ? 'Muted — tap mic to unmute'
                        : 'Listening... speak now';
                final statusColor = processing
                    ? AppConstants.warningColor
                    : muted
                        ? AppColors.textMutedDark
                        : AppConstants.successColor;

                return Container(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => c.toggleListening(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: muted
                                ? AppConstants.warningColor
                                : AppConstants.successColor,
                            boxShadow: !muted
                                ? [
                                    BoxShadow(
                                      color: AppConstants.successColor
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: TextField(
                            controller: c.textCtrl,
                            focusNode: c.focusNode,
                            textInputAction: TextInputAction.send,
                            maxLines: 4,
                            minLines: 1,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: statusText,
                              hintStyle: TextStyle(
                                color: !muted
                                    ? statusColor.withOpacity(0.6)
                                    : (isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                            ),
                            onSubmitted: (_) => c.sendTextFromInput(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: c.sendTextFromInput,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppConstants.primaryColor,
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceAssistantSheet extends StatelessWidget {
  const VoiceAssistantSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceAssistantController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (c.connectionState.value == ws.ConnectionState.disconnected) {
      c.startSession();
    }
    c.initSheetAnim();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return FadeTransition(
          opacity: c.sheetFade!,
          child: SlideTransition(
            position: c.sheetSlide!,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _buildHandle(),
                  _buildSheetHeader(c, isDark),
                  Expanded(
                    child: Obx(() {
                      final msgs = c.messages;
                      final processing = c.isProcessing.value;
                      if (msgs.isEmpty &&
                          c.connectionState.value ==
                              ws.ConnectionState.connecting) {
                        return Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                    color: AppConstants.primaryColor,
                                    strokeWidth: 3),
                                const SizedBox(height: 16),
                                Text('Connecting...',
                                    style: TextStyle(
                                        color: (isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight)
                                            .withOpacity(0.6),
                                        fontSize: 13)),
                              ]),
                        );
                      }
                      c.scrollToBottom();
                      return ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: msgs.length + (processing ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == msgs.length && processing) {
                            return const _ThinkingBubble();
                          }
                          return _ChatBubble(
                              message: msgs[i], isDark: isDark);
                        },
                      );
                    }),
                  ),
                  Obx(() {
                    final st = c.connectionState.value;
                    if (st == ws.ConnectionState.error) {
                      return _ErrorBar(
                          message: c.errorMessage.value.isNotEmpty
                              ? c.errorMessage.value
                              : 'Connection lost',
                          onRetry: () => c.startSession(),
                          isDark: isDark);
                    }
                    return const SizedBox.shrink();
                  }),
                  _buildInputRow(c, isDark),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
