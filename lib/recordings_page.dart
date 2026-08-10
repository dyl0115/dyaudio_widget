import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class RecordingsListPage extends StatefulWidget {
  const RecordingsListPage({super.key});

  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  final AudioPlayer _player = AudioPlayer();
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  List<File> _files = [];
  bool _loading = true;
  String? _playingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _playingPath = null;
          _isPlaying = false;
        }
      });
    });
    _loadRecordings();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<Directory> _recordingsDir() async {
    final base = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    return Directory('${base!.path}/recordings');
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    final dir = await _recordingsDir();
    List<File> files = [];
    if (await dir.exists()) {
      files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.m4a'))
          .toList()
        ..sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );
    }
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  Future<void> _togglePlay(File file) async {
    if (_playingPath == file.path && _isPlaying) {
      await _player.pause();
      return;
    }
    if (_playingPath == file.path && !_isPlaying) {
      await _player.resume();
      return;
    }
    await _player.play(DeviceFileSource(file.path));
    setState(() => _playingPath = file.path);
  }

  Future<void> _delete(File file) async {
    if (_playingPath == file.path) {
      await _player.stop();
      _playingPath = null;
    }
    await file.delete();
    await _loadRecordings();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('녹음 파일'),
        actions: [
          IconButton(
            onPressed: _loadRecordings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '아직 녹음한 파일이 없어요.\n위젯이나 홈 화면의 토글로 녹음을 시작해보세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecordings,
              child: ListView.separated(
                itemCount: _files.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final stat = file.statSync();
                  final isCurrent = _playingPath == file.path;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        isCurrent && _isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    title: Text(_dateFormat.format(stat.modified)),
                    subtitle: Text(_formatSize(stat.size)),
                    onTap: () => _togglePlay(file),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(file),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
