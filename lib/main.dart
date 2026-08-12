import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'recordings_page.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    // Both permissions have to land before arming: the notification is how the
    // lock-screen trigger is surfaced, and arming needs the mic grant to stick.
    await Permission.microphone.request();
    await Permission.notification.request();
    await _channel.invokeMethod('arm');
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
    } else {
      await _channel.invokeMethod('stop');
    }

    if (mounted) {
      setState(() {
        _isRecording = value;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오디오 녹음 위젯'),
        actions: [
          IconButton(
            tooltip: '녹음 파일',
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecordingsListPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 96,
                color: _isRecording ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('녹음'),
                subtitle: Text(_isRecording ? '녹음 중입니다' : '대기 중'),
                value: _isRecording,
                onChanged: _busy ? null : _onToggle,
              ),
              const SizedBox(height: 32),
              Text(
                '홈 화면에 이 앱의 위젯을 추가하면, 앱을 열지 않고도 '
                '위젯의 토글을 탭해서 녹음을 시작/중지할 수 있어요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
