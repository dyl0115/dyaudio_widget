import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/transcript.dart';
import 'screens/settings_screen.dart';
import 'services/listnr_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dyaudio widget',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RecorderHomePage(),
    );
  }
}

class RecorderHomePage extends StatefulWidget {
  const RecorderHomePage({super.key});

  @override
  State<RecorderHomePage> createState() => _RecorderHomePageState();
}

class _RecorderHomePageState extends State<RecorderHomePage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.dyaudio_widget/recorder');

  bool _isRecording = false;
  bool _busy = false;
  bool _isTranscribing = false;
  String? _error;
  Transcript? _transcript;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recording may have been started/stopped from the home screen widget
    // while the app was backgrounded, so re-sync when we come back.
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    final recording = await _channel.invokeMethod<bool>('isRecording');
    if (mounted) {
      setState(() => _isRecording = recording ?? false);
    }
  }

  Future<void> _onToggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    if (value) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('녹음을 시작하려면 마이크 권한이 필요해요.')),
          );
        }
        return;
      }
      await _channel.invokeMethod('start');
      if (mounted) {
        setState(() {
          _isRecording = true;
          _busy = false;
          _transcript = null;
          _error = null;
        });
      }
    } else {
      await _channel.invokeMethod('stop');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _busy = false;
        });
      }
      await _transcribeLatestRecording();
    }
  }

  /// 녹음이 저장되는 디렉토리에서 가장 최근 파일을 찾아 서버로 보내고,
  /// 전송에 성공하면 기기에서 즉시 삭제한다. 실패하면 재시도할 수 있도록
  /// 파일을 남겨둔다.
  Future<void> _transcribeLatestRecording() async {
    setState(() {
      _isTranscribing = true;
      _error = null;
    });

    try {
      // MediaRecorder가 stop() 이후 파일을 마무리하는 데 약간의 시간이
      // 걸릴 수 있어 짧게 대기한다.
      await Future.delayed(const Duration(milliseconds: 300));

      final file = await _latestRecordingFile();
      if (file == null) {
        throw Exception('녹음 파일을 찾을 수 없습니다.');
      }

      final result = await ListnrClient.transcribe(file);
      await file.delete();

      // 홈 화면 위젯에도 최근 변환 결과를 반영한다.
      await HomeWidget.saveWidgetData<String>('transcript_text', result.text);
      await HomeWidget.updateWidget(androidName: 'AudioWidgetProvider');

      if (mounted) {
        setState(() => _transcript = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ListnrClientException ? e.message : e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  Future<File?> _latestRecordingFile() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오디오 녹음 위젯'),
        actions: [
          IconButton(
            tooltip: '서버 설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              _buildRecordControl(),
              const SizedBox(height: 20),
              Expanded(child: _buildResultArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordControl() {
    return Column(
      children: [
        Icon(
          _isRecording ? Icons.mic : Icons.mic_none,
          size: 72,
          color: _isRecording ? Colors.red : Colors.grey,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('녹음'),
          subtitle: Text(_isRecording ? '녹음 중입니다' : '대기 중'),
          value: _isRecording,
          onChanged: _busy || _isTranscribing ? null : _onToggle,
        ),
      ],
    );
  }

  Widget _buildResultArea() {
    if (_isTranscribing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('서버로 전송해서 변환하는 중...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 32),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_transcript == null) {
      return Center(
        child: Text(
          '녹음을 마치면 변환된 텍스트가 여기에 표시돼요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      );
    }

    return _TranscriptCard(transcript: _transcript!);
  }
}

class _TranscriptCard extends StatelessWidget {
  final Transcript transcript;

  const _TranscriptCard({required this.transcript});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('변환 결과', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  transcript.text.isEmpty ? '(인식된 텍스트가 없습니다)' : transcript.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.language, size: 16),
                      label: Text(transcript.language),
                    ),
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text('${transcript.duration.toStringAsFixed(1)}초'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (transcript.segments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('구간별로 보기'),
              children: transcript.segments
                  .map(
                    (s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        '${s.start.toStringAsFixed(1)}s',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      title: Text(s.text),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
