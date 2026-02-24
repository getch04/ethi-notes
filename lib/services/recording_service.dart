import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> startRecording() async {
    if (await _recorder.hasPermission()) {
      final directory = await getTemporaryDirectory();
      final String filePath = p.join(directory.path, 'recording.wav');

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _recorder.start(config, path: filePath);
      return filePath;
    }
    return null;
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  void dispose() {
    _recorder.dispose();
  }
}
