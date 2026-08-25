import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/core/constants/app_constants.dart';
import '../../../app/theme/app_theme.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../shared/widgets/thinking_dots.dart';
import 'voice_assistant_controller.dart';

class StudyAssistantDialogue extends StatelessWidget {
  const StudyAssistantDialogue({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceAssistantController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final dialogueW = screenW - 24;
    final dialogueHNormal = screenH * 0.35;
    final dialogueHExpanded = screenH * 0.70;

    if (c.connectionState.value == ws.ConnectionState.disconnected) {
      try { c.startSession(); } catch (_) {}
    }
    c.initExpandAnim();

    if (!c.dialogueOffsetInitialized) {
      c.dialogueOffset.value = Offset(12, (screenH - dialogueHNormal) / 2);
      c.dialogueOffsetInitialized = true;
    }

    return AnimatedBuilder(
      animation: c.expandAnim!,
      builder: (context, _) {
        return Stack(
          children: [
            Obx(() {
              final currentH = dialogueHNormal +
                  (dialogueHExpanded - dialogueHNormal) * c.expandAnim!.value;
              return Positioned(
                left: c.dialogueOffset.value.dx,
                top: c.dialogueOffset.value.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    c.updateDialogueOffset(
                        details.delta, screenW, screenH, dialogueW, currentH);
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      width: dialogueW,
                      height: currentH,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDark : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildHeader(c, isDark),
                        Expanded(child: _buildMessages(c, isDark)),
                        Obx(() {
                          final st = c.connectionState.value;
                          if (st == ws.ConnectionState.error) {
                            final err = c.errorMessage.value;
                            return _ErrorBar(
                              message:
                                  err.isNotEmpty ? err : 'Connection lost',
                              onRetry: () => c.startSession(),
                              isDark: isDark,
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        GestureDetector(
                          onTap: () => c.toggleExpanded(),
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 3.5,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black26,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Obx(() => AnimatedRotation(
                                      turns: c.isExpanded.value ? 0.5 : 0,
                                      duration: const Duration(
                                          milliseconds: 450),
                                      curve: Curves.easeInOutCubic,
                                      child: Icon(
                                        Icons.keyboard_arrow_up,
                                        size: 16,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ),
                        _buildInputRow(c, isDark),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildHeader(VoiceAssistantController c, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black26,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    AppConstants.primaryColor.withOpacity(0.15),
                child: Icon(Icons.smart_toy_rounded,
                    color: AppConstants.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 15,
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
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: color),
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
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    size: 20),
                onPressed: () {
                  try { c.stopSession(); } catch (_) {}
                  Get.back();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessages(VoiceAssistantController c, bool isDark) {
    return Obx(() {
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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: msgs.length + (processing ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == msgs.length && processing) {
            return const _ThinkingBubble();
          }
          return _ChatBubble(message: msgs[i], isDark: isDark);
        },
      );
    });
  }

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
        child: Row(
          children: [
            GestureDetector(
              onTap: () => c.toggleListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
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
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                    muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
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
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontSize: 14,
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
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => c.sendTextFromInput(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: c.sendTextFromInput,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.primaryColor,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );
    });
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
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 12,
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
        margin: const EdgeInsets.only(bottom: 6, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: BorderRadius.circular(16)
              .copyWith(bottomRight: const Radius.circular(4)),
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, height: 1.4),
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
        margin: const EdgeInsets.only(bottom: 6, right: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16)
              .copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: 14,
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
        margin: const EdgeInsets.only(bottom: 6, right: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)
              .copyWith(bottomLeft: const Radius.circular(4)),
        ),
        child: const ThinkingDots(),
      ),
    );
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppConstants.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: AppConstants.errorColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: AppConstants.errorColor, fontSize: 11),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh,
                color: AppConstants.errorColor, size: 14),
            label: Text('Retry',
                style: TextStyle(
                    color: AppConstants.errorColor, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
