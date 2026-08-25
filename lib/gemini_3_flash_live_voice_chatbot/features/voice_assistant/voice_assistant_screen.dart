import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/core/constants/app_constants.dart';
import '../../../app/theme/app_theme.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../shared/widgets/thinking_dots.dart';
import 'voice_assistant_controller.dart';

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

  Widget _buildHeader(VoiceAssistantController c, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            onPressed: () {
              c.stopSession();
              Navigator.pop(Get.context!);
            },
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
            child: Icon(Icons.smart_toy_rounded,
                color: AppConstants.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Assistant',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Obx(() {
                  final st = c.connectionState.value;
                  final processing = c.isProcessing.value;
                  final (color, label) = switch (processing) {
                    true => (AppConstants.warningColor, 'Processing...'),
                    false => switch (st) {
                      ws.ConnectionState.connecting =>
                        (AppConstants.warningColor, 'Connecting...'),
                      ws.ConnectionState.connected =>
                        (AppConstants.successColor, 'Listening'),
                      ws.ConnectionState.error =>
                        (AppConstants.errorColor, 'Offline'),
                      _ => (AppColors.textMutedDark, 'Offline'),
                    },
                  };
                  return Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.system) {
      return _SystemBubble(text: message.text, isDark: isDark);
    }
    if (message.isUser) {
      return _UserBubble(text: message.text, isDark: isDark);
    }
    return _AssistantBubble(text: message.text, isDark: isDark);
  }
}

class _SystemBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SystemBubble({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isThinking = text.endsWith('...');
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isThinking) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  const _UserBubble({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: BorderRadius.circular(18)
              .copyWith(bottomRight: const Radius.circular(4)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  const _AssistantBubble({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18)
              .copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18)
              .copyWith(bottomLeft: const Radius.circular(4)),
        ),
        child: const ThinkingDots(),
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

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _buildSheetHeader(VoiceAssistantController c, bool isDark) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
              bottom: BorderSide(
                  color:
                      isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1)),
        ),
        child: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
              child: Icon(Icons.smart_toy_rounded,
                  color: AppConstants.primaryColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Study Assistant',
                    style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Obx(() {
                  final st = c.connectionState.value;
                  final processing = c.isProcessing.value;
                  final (color, label) = switch (processing) {
                    true => (AppConstants.warningColor, 'Processing...'),
                    false => switch (st) {
                      ws.ConnectionState.connecting =>
                        (AppConstants.warningColor, 'Connecting...'),
                      ws.ConnectionState.connected =>
                        (AppConstants.successColor, 'Listening'),
                      ws.ConnectionState.error =>
                        (AppConstants.errorColor, 'Offline'),
                      _ => (AppColors.textMutedDark, 'Offline'),
                    },
                  };
                  return Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color)),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ]);
                }),
              ])),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
            onPressed: () => c.reverseSheetAnim(),
          ),
        ]),
      );

  Widget _buildInputRow(VoiceAssistantController c, bool isDark) {
    return Obx(() {
      final st = c.connectionState.value;
      if (st == ws.ConnectionState.connecting) return const SizedBox.shrink();
      final muted = c.isMuted;
      final processing = c.isProcessing.value;
      final statusText = processing
          ? 'Processing...'
          : muted
              ? 'Muted — tap mic'
              : 'Listening...';
      final statusColor = processing
          ? AppConstants.warningColor
          : muted
              ? AppColors.textMutedDark
              : AppConstants.successColor;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(children: [
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
                            color:
                                AppConstants.successColor.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2)
                      ]
                    : [],
              ),
              child: Icon(
                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color:
                      isDark ? AppColors.borderDark : AppColors.borderLight),
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
                  fontSize: 15),
              decoration: InputDecoration(
                hintText: statusText,
                hintStyle: TextStyle(
                    color: !muted
                        ? statusColor.withOpacity(0.6)
                        : (isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => c.sendTextFromInput(),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: c.sendTextFromInput,
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppConstants.primaryColor),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20)),
          ),
        ]),
      );
    });
  }
}

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorBar(
      {required this.message, required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppConstants.errorColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppConstants.errorColor, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon:
                Icon(Icons.refresh, color: AppConstants.errorColor, size: 16),
            label: Text('Retry',
                style:
                    TextStyle(color: AppConstants.errorColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
