import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../subjects_controller.dart';

/// Wallpaper chooser overlay — no dark backdrop (background stays unshaded).
/// Smooth fade+slide expand/collapse like topic revision cards.
/// After apply/close, overlay is fully gone (no stuck full-screen hit target).
class SubjectWallpaperPicker extends StatefulWidget {
  const SubjectWallpaperPicker(
      {super.key, required this.d, required this.controller});

  final bool d;
  final SubjectsController controller;

  @override
  State<SubjectWallpaperPicker> createState() => _SubjectWallpaperPickerState();
}

class _SubjectWallpaperPickerState extends State<SubjectWallpaperPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _mountedOpen = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      reverseDuration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _drive(bool open) {
    if (open) {
      if (!_mountedOpen) {
        _mountedOpen = true;
        _anim.forward(from: 0);
      }
    } else {
      if (_mountedOpen) {
        _mountedOpen = false;
        _anim.reverse();
      } else if (_anim.value != 0) {
        _anim.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final controller = widget.controller;
    return Obx(() {
      final subjectId = controller.wallpaperSubjectId.value;
      final open = subjectId != null;
      _drive(open);
      // Fully gone when closed — no Positioned.fill, no overlay, no hang.
      if (!open && _anim.value == 0) {
        return const SizedBox.shrink();
      }
      if (!open) {
        // Collapse in progress — fade only, no black shade.
        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: _anim.value,
                child: Align(
                  alignment: Alignment.center,
                  child: _panel(d, controller, ''),
                ),
              ),
            ),
          ),
        );
      }

      final name = controller.wallpaperSubjectName.value;
      final loading = controller.wallpaperLoading.value;
      final urls = controller.wallpaperUrls;
      final fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
      final slide = Tween<Offset>(
        begin: const Offset(0, -0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));

      return Positioned.fill(
        // Transparent hit layer only for outside-tap close — NO dark scrim.
        child: GestureDetector(
          onTap: controller.closeWallpaperPicker,
          behavior: HitTestBehavior.translucent,
          child: Align(
            alignment: Alignment.center,
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.center,
                    heightFactor: _anim.value.clamp(0.05, 1.0),
                    child: _panel(d, controller, name, urls: urls, loading: loading),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _panel(
    bool d,
    SubjectsController controller,
    String name, {
    List<String>? urls,
    bool loading = false,
  }) {
    final list = urls ?? controller.wallpaperUrls;
    final load = loading || controller.wallpaperLoading.value;
    return Container(
      width: 420,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      margin: EdgeInsets.all(S.xl),
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Change wallpaper',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary(d),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: controller.closeWallpaperPicker,
                icon: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textMuted(d),
                ),
                tooltip: 'Collapse',
              ),
            ],
          ),
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                name,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d)),
              ),
            ),
          if (load)
            SizedBox(
              height: 120,
              child: Shimmer.fromColors(
                baseColor: d ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4),
                highlightColor:
                    d ? const Color(0xFF3D4250) : const Color(0xFFF5F7FB),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => SizedBox(width: S.sm),
                  itemBuilder: (_, __) => Container(
                    width: 160,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(S.radiusMd),
                    ),
                  ),
                ),
              ),
            )
          else if (list.isEmpty)
            Padding(
              padding: EdgeInsets.all(S.xl),
              child: Text(
                'No wallpapers found for this subject.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted(d)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => SizedBox(height: S.sm),
                itemBuilder: (_, i) {
                  final url = list[i];
                  return GestureDetector(
                    onTap: () {
                      final id = controller.wallpaperSubjectId.value;
                      if (id != null) {
                        controller.applySubjectWallpaper(id, url);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(S.radiusMd),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Shimmer.fromColors(
                              baseColor: d
                                  ? const Color(0xFF2D3140)
                                  : const Color(0xFFE8ECF4),
                              highlightColor: d
                                  ? const Color(0xFF3D4250)
                                  : const Color(0xFFF5F7FB),
                              child: Container(
                                color: d
                                    ? const Color(0xFF2D3140)
                                    : const Color(0xFFE8ECF4),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surface(d),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textMuted(d),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
