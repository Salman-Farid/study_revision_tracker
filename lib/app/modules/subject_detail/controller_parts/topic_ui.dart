part of '../subject_detail_controller.dart';

/// Bottom-sheet UI and voice-assistant launch.
extension SubjectDetailUi on SubjectDetailController {
  void showAddSheet() {
    final nc = TextEditingController(), nsc = TextEditingController(), rfc = TextEditingController();
    final sd = DateTime.now().obs, st = TimeOfDay.now().obs;
    Get.bottomSheet(Container(padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.textMuted(Get.isDarkMode), borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: S.xl),
          Text(
            isSubtopicMode
                ? 'Add Subtopic'
                : 'Add Topic',
            style: AppTextStyles.headlineSmall,
          ),
          SizedBox(height: S.sm),
          Text(
            isSubtopicMode
                ? 'Topic: ${_parentTopic!.name} · ${subject.name}'
                : 'Subject: ${subject.name}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
          ),
          SizedBox(height: S.xl),
          TextField(
            controller: nc,
            decoration: InputDecoration(
              labelText: isSubtopicMode ? 'Subtopic Name *' : 'Topic Name *',
              prefixIcon: const Icon(Icons.topic_rounded),
            ),
            autofocus: true,
          ),
          SizedBox(height: S.base),
          Row(children: [
            Expanded(child: Obx(() => OutlinedButton.icon(onPressed: () async {
              final d = await showDatePicker(context: Get.context!, initialDate: sd.value,
                firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) sd.value = d;
            }, icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('${sd.value.day}/${sd.value.month}/${sd.value.year}', style: AppTextStyles.labelMedium)))),
            SizedBox(width: S.sm),
            Expanded(child: Obx(() => OutlinedButton.icon(onPressed: () async {
              final t = await showTimePicker(context: Get.context!, initialTime: st.value);
              if (t != null) st.value = t;
            }, icon: const Icon(Icons.access_time_rounded, size: 16),
              label: Text(st.value.format(Get.context!), style: AppTextStyles.labelMedium)))),
          ]),
          SizedBox(height: S.base),
          TextField(controller: nsc, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.note_rounded)), maxLines: 2),
          SizedBox(height: S.base),
          TextField(controller: rfc, decoration: const InputDecoration(labelText: 'Reference Answer (optional)', prefixIcon: Icon(Icons.article_rounded)), maxLines: 3),
          SizedBox(height: S.xl),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
            final n = nc.text.trim();
            if (n.isEmpty) { Get.snackbar('required'.tr, 'required'.tr); return; }
            final dt = DateTime(sd.value.year, sd.value.month, sd.value.day, st.value.hour, st.value.minute);
            createTopic(name: n, notes: nsc.text.trim().isEmpty ? null : nsc.text.trim(),
              refAnswer: rfc.text.trim().isEmpty ? null : rfc.text.trim(), firstRead: dt);
            Get.back();
          }, child: Text('createSubject'.tr))),
          SizedBox(height: S.base),
        ]))), isScrollControlled: true);
  }

  /// Navigate to Gemini Live voice assistant with subject context
  void openVoiceAssistant() {
    final vc = Get.find<VoiceAssistantController>();
    vc.currentSubjectName = subject.name;
    vc.toolMode = 'subjects'; // isolate: no class/daily routine tools
    Get.bottomSheet(
      const VoiceAssistantSheet(),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Get.theme.scaffoldBackgroundColor,
    );
  }
}
