import 'package:flutter/material.dart';

import '../models/transcript.dart';

/// 변환 결과를 바텀시트로 보여준다. 지금 쓰는 모델은 타임스탬프를
/// 제공하지 않으므로 전체 텍스트 + 언어만 표시한다.
Future<void> showTranscriptResult(BuildContext context, Transcript transcript) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.notes, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('변환 결과', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (transcript.language.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.language, size: 16),
                    label: Text(transcript.language),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: SelectableText(
                  transcript.text.isEmpty ? '(인식된 텍스트가 없습니다)' : transcript.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
