import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/transcript.dart';
import 'listnr_prefs.dart';

class ListnrClientException implements Exception {
  final String message;
  ListnrClientException(this.message);

  @override
  String toString() => message;
}

class ListnrClient {
  /// 저장된 서버 설정으로 오디오 파일을 업로드하고 트랜스크립트를 받아온다.
  /// 서버로 파일을 전송할 뿐, 이 클래스는 로컬 파일을 지우지 않는다 —
  /// 삭제 여부는 호출부(성공/실패 판단)에서 결정한다.
  static Future<Transcript> transcribe(File audioFile) async {
    final creds = await ListnrPrefs.load();
    if (creds == null) {
      throw ListnrClientException('설정에서 서버 정보를 먼저 입력해주세요.');
    }

    final uri = Uri.parse('${creds.baseUrl}/transcripts');
    final request = http.MultipartRequest('POST', uri)
      ..headers['authorization'] =
          'Basic ${base64Encode(utf8.encode('${creds.username}:${creds.password}'))}'
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send();
    } catch (e) {
      throw ListnrClientException('서버에 연결할 수 없습니다: $e');
    }
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401) {
      throw ListnrClientException('인증에 실패했습니다. 설정에서 아이디/비밀번호를 확인해주세요.');
    }
    if (response.statusCode != 200) {
      throw ListnrClientException('변환 실패 (${response.statusCode}): ${response.body}');
    }

    return Transcript.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
