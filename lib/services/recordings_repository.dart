import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 녹음 파일 저장 위치. 네이티브 AudioRecordingService.kt와 동일한 경로
/// (getExternalStorageDirectory ≈ Android의 getExternalFilesDir(null))를 쓴다.
Future<Directory> recordingsDirectory() async {
  final base = await getExternalStorageDirectory();
  final dir = Directory('${base!.path}/recordings');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

const _audioExtensions = ['.m4a', '.mp3', '.wav', '.aac', '.m4b', '.ogg', '.flac'];

bool isAudioFile(String path) {
  final lower = path.toLowerCase();
  return _audioExtensions.any((ext) => lower.endsWith(ext));
}

/// 녹음/업로드로 쌓인 오디오 파일 목록. 최신순으로 정렬된다.
/// 마이크로 녹음한 파일과 [pickAndCopyAudioFile]로 추가한 파일이 함께 담긴다.
Future<List<File>> listRecordingFiles() async {
  final dir = await recordingsDirectory();
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => isAudioFile(f.path))
      .toList()
    ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  return files;
}
