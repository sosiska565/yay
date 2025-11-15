import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech + Gemini Demo',
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _speechEnabled = false;
  String _lastWords = '';
  String _serverResponse = '';

  // 🔧 Настрой свой IP сервера (локальный или удалённый)
  final String serverUrl = "http://64.188.69.51:8080"; // ← замени на свой IP

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// Инициализация SpeechToText
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Начать слушать микрофон
  Future<void> _startListening() async {
    if (!_speechEnabled) return;
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Остановить прослушивание
  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {});
    if (_lastWords.isNotEmpty) {
      await _sendMessageToServer(_lastWords);
    }
  }

  /// Обработка распознанного текста
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  /// Отправляем текст на сервер (sendMessage)
  Future<void> _sendMessageToServer(String message) async {
    try {
      final url = Uri.parse('$serverUrl/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'text/plain; charset=UTF-8'},
        body: message,
      );

      if (response.statusCode == 200) {
        _serverResponse = response.body;
        print('Server text response: $_serverResponse');
        await _getTTSFromServer(_serverResponse);
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Получаем TTS аудио с сервера и проигрываем
  Future<void> _getTTSFromServer(String text) async {
    try {
      final url = Uri.parse('$serverUrl/getTTSMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'text/plain; charset=UTF-8'},
        body: text,
      );

      if (response.statusCode == 200) {
        Uint8List audioBytes = response.bodyBytes;
        print('Received ${audioBytes.length} bytes of audio');
        await _audioPlayer.play(BytesSource(audioBytes));
      } else {
        print('TTS request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching TTS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Voice Assistant')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _speechToText.isListening
                    ? 'Listening...'
                    : 'Press the mic and speak!',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 16),
              Text(
                'You said: $_lastWords',
                style: const TextStyle(fontSize: 18, color: Colors.blueAccent),
              ),
              const SizedBox(height: 20),
              Text(
                'Server response: $_serverResponse',
                style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _speechToText.isNotListening ? _startListening : _stopListening,
        tooltip: 'Listen',
        child: Icon(
          _speechToText.isNotListening ? Icons.mic_off : Icons.mic,
        ),
      ),
    );
  }
}
