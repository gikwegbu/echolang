/*
import 'package:onnxruntime/onnxruntime.dart';
import 'sentencepiece_ffi.dart';

class IgboTranslationService {
  late final OrtSession _session;
  late final SentencePiece _tokenizer;

  IgboTranslationService._();

  static Future<IgboTranslationService> create({
    required String onnxModelPath,
    required String spModelPath,
    required String spLibraryPath,
  }) async {
    final service = IgboTranslationService._();

    // Load SentencePiece native library
    service._tokenizer = SentencePiece(spLibraryPath);
    service._tokenizer.loadModel(spModelPath);

    // Load ONNX model
    final env = OrtEnv.instance;
    service._session = OrtSession.fromFile(
      env,
      onnxModelPath,
    );

    return service;
  }

  /// Fully offline Igbo → English
  String translate(String igboText) {
    // 1️⃣ Tokenize
    final inputIds = _tokenizer.encode(igboText);
    final attentionMask =
        List<int>.filled(inputIds.length, 1);

    // 2️⃣ Create ONNX tensors
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputIds,
      [1, inputIds.length],
      OrtTensorType.int64,
    );

    final maskTensor = OrtValueTensor.createTensorWithDataList(
      attentionMask,
      [1, attentionMask.length],
      OrtTensorType.int64,
    );

    // 3️⃣ Run ONNX model
    final outputs = _session.run({
      'input_ids': inputTensor,
      'attention_mask': maskTensor,
    });

    final outputIds =
        List<int>.from((outputs.values.first as OrtValueTensor).data);

    // 4️⃣ Decode
    return _tokenizer.decode(outputIds);
  }

  void dispose() {
    _session.release();
  }
}
*/
