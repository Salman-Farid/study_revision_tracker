import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../core/constants/subject_icons.dart';
import '../../../data/models/subject_model.dart';
import '../../../theme/app_theme.dart';
import '../../subject_detail/widgets/expandable_card.dart';
import '../subjects_controller.dart';

class SubjectsGrid extends StatelessWidget {
  final bool d;
  final SubjectsController controller;
  const SubjectsGrid({super.key, required this.d, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    final generatedChildren = List.generate(
      controller.subjects.length,
      (index) {
        final sub = controller.subjects[index];
        return _SubjectCardTile(
          key: Key(sub.id),
          sub: sub,
          d: d,
          controller: controller,
        );
      },
    );

    return ReorderableBuilderWrap(
      children: generatedChildren,
      scrollController: scrollController,
      controller: controller,
    );
  }
}

/// Subject cover card. Wallpaper expands IN-CARD (slowmo) — no dialog overlay.
class _SubjectCardTile extends StatefulWidget {
  const _SubjectCardTile({
    super.key,
    required this.sub,
    required this.d,
    required this.controller,
  });

  final SubjectModel sub;
  final bool d;
  final SubjectsController controller;

  @override
  State<_SubjectCardTile> createState() => _SubjectCardTileState();
}

class _SubjectCardTileState extends State<_SubjectCardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;
  bool? _wasOpen;
  /// Last wallpaper list for THIS card — used while collapsing.
  final List<String> _panelUrls = <String>[];

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      reverseDuration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
  }

  void _drive(bool open) {
    if (_wasOpen == open) return;
    _wasOpen = open;
    // Drive after frame so reverse isn't cancelled by rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (open) {
        _expand.forward();
      } else {
        _expand.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final controller = widget.controller;
    final sub = widget.sub;
    final hasImage = sub.imageUrl != null && sub.imageUrl!.isNotEmpty;

    return ListenableBuilder(
      listenable: _expand,
      builder: (context, _) {
        return Obx(() {
          final open = controller.isWallpaperOpenFor(sub.id);
          _drive(open);
          final liveUrls = controller.wallpaperUrls;
          final loading =
              open && controller.wallpaperLoading.value;
          if (open && liveUrls.isNotEmpty) {
            _panelUrls
              ..clear()
              ..addAll(liveUrls);
          }
          // Keep showing last images while reverse animation runs.
          final showPanel = open || _expand.value > 0;
          final panelUrls = open ? liveUrls : _panelUrls;

          return Container(
            key: Key(sub.id),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface(d),
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(color: AppColors.border(d)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cover / info — tap opens topics (wallpaper btn isolated) ──
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (controller.isWallpaperOpenFor(sub.id)) {
                      controller.closeWallpaperPicker();
                      return;
                    }
                    controller.openSubject(sub);
                  },
                  child: SizedBox(
                    height: 210,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage) ...[
                          Container(color: AppColors.surface(d)),
                          Image.network(
                            sub.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Shimmer.fromColors(
                                baseColor: d
                                    ? const Color(0xFF232730)
                                    : Colors.grey[300]!,
                                highlightColor: d
                                    ? const Color(0xFF2A2F3A)
                                    : Colors.grey[100]!,
                                child: Container(
                                    color: d
                                        ? const Color(0xFF232730)
                                        : Colors.grey[300]),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                Container(color: AppColors.surface(d)),
                          ),
                        ] else
                          Container(color: AppColors.surface(d)),
                        Padding(
                          padding: EdgeInsets.all(S.base),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(S.md),
                                    decoration: BoxDecoration(
                                      color: hasImage
                                          ? Colors.white24
                                          : sub.color.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(S.radiusMd),
                                    ),
                                    child: Icon(
                                      SubjectIcons.forCodePoint(
                                          sub.iconCodePoint),
                                      color: hasImage
                                          ? Colors.white
                                          : sub.color,
                                      size: S.iconLg,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Get.defaultDialog(
                                      title: 'deleteQ'.tr,
                                      middleText: 'deleteSubjectBody'
                                          .tr
                                          .replaceAll('{name}', sub.name),
                                      textConfirm: 'delete'.tr,
                                      textCancel: 'cancel'.tr,
                                      confirmTextColor: Colors.white,
                                      buttonColor: AppColors.error,
                                      onConfirm: () {
                                        controller.deleteSubject(sub.id);
                                        Get.back();
                                      },
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.all(S.sm),
                                      decoration: BoxDecoration(
                                        color: hasImage
                                            ? Colors.white30
                                            : AppColors.error
                                                .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(S.radiusSm),
                                      ),
                                      child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.error,
                                          size: 20),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sub.name,
                                      style: AppTextStyles.titleMedium
                                          .copyWith(
                                              color: hasImage
                                                  ? Colors.white
                                                  : AppColors.textPrimary(d)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  SizedBox(height: S.xs),
                                  Obx(() {
                                    final count =
                                        controller.topicCountFor(sub);
                                    return Text(
                                      count == 1
                                          ? 'topicSingular'.tr
                                          : 'topicsCount'
                                              .tr
                                              .replaceAll('{n}', '$count'),
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: hasImage
                                            ? Colors.white70
                                            : AppColors.textMuted(d),
                                      ),
                                    );
                                  }),
                                  SizedBox(height: S.sm),
                                  GestureDetector(
                                    key: ValueKey('wallpaper_btn_${sub.id}'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => controller
                                        .toggleWallpaperPicker(sub),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: S.sm, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: hasImage
                                            ? Colors.black26
                                            : (d ? Colors.white : Colors.black)
                                                .withValues(alpha: 0.06),
                                        borderRadius:
                                            BorderRadius.circular(S.radiusFull),
                                        border: Border.all(
                                          color: hasImage
                                              ? Colors.white24
                                              : AppColors.border(d),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.wallpaper_outlined,
                                              size: 14,
                                              color: hasImage
                                                  ? Colors.white
                                                  : AppColors.textMuted(d)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Change Wallpaper',
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                              color: hasImage
                                                  ? Colors.white
                                                  : AppColors.textMuted(d),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            open
                                                ? Icons
                                                    .keyboard_arrow_up_rounded
                                                : Icons
                                                    .keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: hasImage
                                                ? Colors.white
                                                : AppColors.textMuted(d),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: S.sm),
                                  Obx(() {
                                    final p = controller.progressFor(sub.id);
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: p,
                                          backgroundColor: hasImage
                                              ? Colors.white30
                                              : sub.color.withOpacity(0.12),
                                          valueColor: AlwaysStoppedAnimation(
                                              hasImage
                                                  ? Colors.white
                                                  : sub.color),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  S.radiusFull),
                                          minHeight: 4,
                                        ),
                                        SizedBox(height: S.xs),
                                        Text('${(p * 100).round()}%',
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                              color: hasImage
                                                  ? Colors.white
                                                  : sub.color,
                                              fontWeight: FontWeight.w700,
                                            )),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── In-card wallpaper list — slow expand AND collapse ──
                AnimatedExpanded(
                  controller: _expand,
                  child: !showPanel && _panelUrls.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          width: double.infinity,
                          color: AppColors.surface(d),
                          padding:
                              EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.md),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 240, minHeight: 100),
                            child: loading
                                ? Shimmer.fromColors(
                                    baseColor: d
                                        ? const Color(0xFF2D3140)
                                        : const Color(0xFFE8ECF4),
                                    highlightColor: d
                                        ? const Color(0xFF3D4250)
                                        : const Color(0xFFF5F7FB),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: 3,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(height: S.sm),
                                      itemBuilder: (_, __) => Container(
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  S.radiusMd),
                                        ),
                                      ),
                                    ),
                                  )
                                : panelUrls.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(S.md),
                                          child: Text(
                                            'No wallpapers found for this subject.',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color: AppColors
                                                        .textMuted(d)),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: panelUrls.length,
                                        separatorBuilder: (_, __) =>
                                            SizedBox(height: S.sm),
                                        itemBuilder: (_, i) {
                                          final url = panelUrls[i];
                                          return GestureDetector(
                                            onTap: open
                                                ? () => controller
                                                    .applySubjectWallpaper(
                                                        sub.id, url)
                                                : null,
                                            behavior:
                                                HitTestBehavior.opaque,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      S.radiusMd),
                                              child: SizedBox(
                                                height: 72,
                                                child: Image.network(
                                                  url,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (ctx, child, pr) {
                                                    if (pr == null) {
                                                      return child;
                                                    }
                                                    return Shimmer.fromColors(
                                                      baseColor: d
                                                          ? const Color(
                                                              0xFF2D3140)
                                                          : const Color(
                                                              0xFFE8ECF4),
                                                      highlightColor: d
                                                          ? const Color(
                                                              0xFF3D4250)
                                                          : const Color(
                                                              0xFFF5F7FB),
                                                      child: Container(
                                                        color: d
                                                            ? const Color(
                                                                0xFF2D3140)
                                                            : const Color(
                                                                0xFFE8ECF4),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          Container(
                                                    color:
                                                        AppColors.surface(d),
                                                    alignment:
                                                        Alignment.center,
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: AppColors
                                                          .textMuted(d),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

class ReorderableBuilderWrap extends StatelessWidget {
  final List<Widget> children;
  final ScrollController scrollController;
  final SubjectsController controller;
  const ReorderableBuilderWrap({
    super.key,
    required this.children,
    required this.scrollController,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableBuilder(
      children: children,
      scrollController: scrollController,
      onDragStarted: (_) => controller.isDragging.value = true,
      onDragEnd: (_) => controller.isDragging.value = false,
      onReorder: (ReorderedListFunction reorderedListFunction) {
        final reordered =
            reorderedListFunction(controller.subjects.toList())
                .cast<SubjectModel>();
        unawaited(controller.applyReorderedSubjects(reordered));
      },
      builder: (children) {
        return LayoutBuilder(builder: (context, constraints) {
          final outerW = constraints.maxWidth;
          final cols = outerW >= 720 ? 3 : 2;
          final pad = S.base;
          final gap = S.gridSpacing;
          final cardW =
              ((outerW - pad * 2 - gap * (cols - 1)) / cols).clamp(160.0, 420.0);
          // Independent columns — expanding one card only reflows ITS column.
          final columns = List.generate(cols, (_) => <Widget>[]);
          for (var i = 0; i < children.length; i++) {
            columns[i % cols].add(children[i]);
          }
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(pad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final card in columns[c]) ...[
                          SizedBox(width: cardW, child: card),
                          SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }
}

class SubjectsVoiceChatPanel extends StatelessWidget {
  final bool d;
  final SubjectsController controller;
  const SubjectsVoiceChatPanel(
      {super.key, required this.d, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppConstants.mediumDuration,
      curve: Curves.easeInOut,
      child: Container(
        height: 300,
        margin: EdgeInsets.all(S.md),
        decoration: BoxDecoration(
          color: AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusLg),
          border: Border.all(color: AppColors.border(d)),
        ),
        child: Column(children: [
          Expanded(
            child: Obx(() => ListView.builder(
                padding: EdgeInsets.all(S.md),
                itemCount: controller.chatMessages.length,
                itemBuilder: (_, i) {
                  final m = controller.chatMessages[i];
                  return Align(
                    alignment:
                        m['u'] ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(Get.context!).size.width * 0.7),
                      margin:
                          EdgeInsets.symmetric(vertical: S.xs),
                      padding: EdgeInsets.symmetric(
                          horizontal: S.base, vertical: S.sm),
                      decoration: BoxDecoration(
                        color: m['u']
                            ? AppColors.primary
                            : (d ? const Color(0xFF232730) : AppColors.bgLight),
                        borderRadius: BorderRadius.circular(S.radiusMd),
                      ),
                      child: Text(m['t'],
                          style: AppTextStyles.bodySmall.copyWith(
                              color: m['u']
                                  ? Colors.white
                                  : AppColors.textPrimary(d))),
                    ),
                  );
                })),
          ),
          Padding(
            padding: EdgeInsets.all(S.md),
            child: Obx(() => GestureDetector(
                  onTap: controller.isListening.value
                      ? controller.stopListening
                      : controller.startListening,
                  child: AnimatedContainer(
                    duration: AppConstants.shortDuration,
                    padding: EdgeInsets.all(S.base),
                    decoration: BoxDecoration(
                      color: controller.isListening.value
                          ? AppColors.error
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        controller.isListening.value
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: S.iconLg),
                  ),
                )),
          ),
        ]),
      ),
    );
  }
}
