import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../services/listnr_client.dart';
import '../services/recordings_repository.dart';
import '../widgets/transcript_result_sheet.dart';

class RecordingsListScreen extends StatefulWidget {
  const RecordingsListScreen({super.key});

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  List<File> _files = [];
  bool _loading = true;
  bool _picking = false;
  final Set<String> _transcribingPaths = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await listRecordingFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: false,
      );
      final pickedPath = result?.files.single.path;
      if (pickedPath == null) return;

      final source = File(pickedPath);
      final dir = await recordingsDirectory();
      final fileName =
          'UPLOAD_${DateTime.now().millisecondsSinceEpoch}_${source.uri.pathSegments.last}';
      await source.copy('${dir.path}/$fileName');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일을 추가하지 못했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _transcribe(File file) async {
    setState(() => _transcribingPaths.add(file.path));
    try {
      final result = await ListnrClient.transcribe(file);
      await file.delete();

      // 홈 화면 위젯에도 최근 변환 결과를 반영한다.
      await HomeWidget.saveWidgetData<String>('transcript_text', result.text);
      await HomeWidget.updateWidget(androidName: 'AudioWidgetProvider');

      await _load();
      if (mounted) {
        await showTranscriptResult(context, result);
      }
    } catch (e) {
      if (mounted) {
        final message = e is ListnrClientException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('변환 실패: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _transcribingPaths.remove(file.path));
      }
    }
  }

  Future<void> _delete(File file) async {
    await file.delete();
    await _load();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  bool _isUpload(File file) => file.uri.pathSegments.last.startsWith('UPLOAD_');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('녹음 파일'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _picking ? null : _pickAudioFile,
        icon: _picking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: const Text('파일 추가'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '쌓인 파일이 없어요.\n녹음하거나 오디오 파일을 추가해보세요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final stat = file.statSync();
                      final isBusy = _transcribingPaths.contains(file.path);
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            _isUpload(file) ? Icons.audio_file : Icons.mic,
                          ),
                        ),
                        title: Text(_formatDate(stat.modified)),
                        subtitle: Text(
                          '${_isUpload(file) ? '추가한 파일' : '녹음'} · ${_formatSize(stat.size)}',
                        ),
                        trailing: isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: '텍스트로 변환',
                                    icon: const Icon(Icons.text_snippet_outlined),
                                    onPressed: () => _transcribe(file),
                                  ),
                                  IconButton(
                                    tooltip: '삭제',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(file),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                ),
    );
  }
}
