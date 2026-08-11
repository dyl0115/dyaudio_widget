import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transcript.dart';
import 'listnr_client.dart';

/// 네이티브 녹음 서비스가 저장하는 디렉토리(getExternalFilesDir/recordings)에서
/// 가장 최근에 수정된 .m4a 파일을 찾는다.
Future<File?> latestRecordingFile() async {
  final base = await getExternalStorageDirectory();
  if (base == null) return null;
  final dir = Directory('${base.path}/recordings');
  if (!await dir.exists()) return null;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.m4a'))
      .toList()
    ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

  return files.isEmpty ? null : files.first;
}

/// 최신 녹음 파일을 listnr-server로 업로드하고, 성공하면 기기에서 삭제한 뒤
/// 홈 화면 위젯 데이터까지 갱신한다.
///
/// 앱이 열려있을 때(포그라운드 토글)와 위젯을 직접 탭해서 백그라운드
/// Dart 콜백으로 실행될 때 양쪽에서 공용으로 쓰인다 — 그래서 State나
/// BuildContext에 의존하지 않는다.
///
/// 녹음 파일이 없으면 null을 반환한다. 업로드 실패 시 예외를 그대로 던지고,
/// 이 경우 파일은 재시도할 수 있도록 삭제하지 않는다.
Future<Transcript?> uploadLatestRecording() async {
  final file = await latestRecordingFile();
  if (file == null) return null;

  final result = await ListnrClient.transcribe(file);
  await file.delete();

  await HomeWidget.saveWidgetData<String>('transcript_text', result.text);
  await HomeWidget.updateWidget(androidName: 'AudioWidgetProvider');

  return result;
}
