/*

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:whisper_ggml/whisper_ggml.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoLang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final model = WhisperModel.base;
  final AudioRecorder audioRecorder = AudioRecorder();
  final WhisperController whisperController = WhisperController();
  String transcribedText = 'Transcribed text will be displayed here';
  String englishText = '';
  
  bool isProcessing = false;
  bool isProcessingFile = false;
  bool isListening = false;

  @override
  void initState() {
    initModel();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Igbo Offline STT → EN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Speech",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    transcribedText,
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),
                  Text(
                    "English Translation:",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    transcribedText,
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                left: 0,
                child: Tooltip(
                  message: 'Transcribe igbo audio asset file',
                  child: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    maxRadius: 25,
                    child: isProcessingFile
                        ? const CircularProgressIndicator.adaptive()
                        : PopupMenuButton<int>(
                            itemBuilder: (context) => List.generate(5, (index) {
                              return optionItem(index + 1);
                            }),
                            offset: const Offset(10, -260),
                            // color: Colors.green,
                            elevation: 2,
                            // on selected we show the dialog box
                            onSelected: (value) {
                              transcribeLocalAudio("$value");
                            },
                            child: const Icon(Icons.folder),
                          ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: record,
        tooltip: 'Start listening',
        child: isProcessing
            ? const CircularProgressIndicator()
            : Icon(
                isListening ? Icons.mic_off : Icons.mic,
                color: isListening ? Colors.red : null,
              ),
      ),
    );
  }

  PopupMenuItem<int> optionItem(int value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          const Icon(Icons.audio_file),
          const SizedBox(
            width: 10,
          ),
          Text("Audio $value")
        ],
      ),
    );
  }

  Future<void> initModel() async {
    try {
      /// Try initializing the model from assets
      // final bytesBase = await rootBundle.load('assets/ggml-${model.modelName}.bin'); // You haven't downloaded this and added to assets yet, hence the error
      final bytesBase =
          await rootBundle.load('assets/models/whisper_igbo_ggml.bin');
      final modelPathBase = await whisperController.getPath(model);
      final fileBase = File(modelPathBase);
      await fileBase.writeAsBytes(bytesBase.buffer
          .asUint8List(bytesBase.offsetInBytes, bytesBase.lengthInBytes));
    } catch (e) {
      debugPrint(
          "George this is the error from loading model...${e.toString()}");

      /// On error try downloading the model
      await whisperController.downloadModel(model);
    }
  }

  Future<void> record() async {
    if (await audioRecorder.hasPermission()) {
      if (await audioRecorder.isRecording()) {
        final audioPath = await audioRecorder.stop();

        if (audioPath != null) {
          debugPrint('🔴🔴🎙️ Stopped listening.');

          setState(() {
            isListening = false;
            isProcessing = true;
          });

          final result = await whisperController.transcribe(
            model: model,
            audioPath: audioPath,
            lang: 'en', // English
            // lang: 'ig', // Igbo
          );

          if (mounted) {
            setState(() {
              isProcessing = false;
            });
          }

          if (result?.transcription.text != null) {
            setState(() {
              transcribedText = result!.transcription.text;
            });
          }
        } else {
          debugPrint('No recording exists.');
        }
      } else {
        debugPrint('🟢🟢🎙️ Started listening.');

        setState(() {
          isListening = true;
        });

        final Directory appDirectory = await getTemporaryDirectory();
        await audioRecorder.start(const RecordConfig(),
            path: '${appDirectory.path}/test.m4a');
      }
    }
  }

  Future<void> transcribeLocalAudio(String fileId) async {
    final Directory tempDir = await getTemporaryDirectory();
    final asset = await rootBundle.load('assets/igbo_audio/$fileId.mp3');
    final String localAudioPath = "${tempDir.path}/$fileId.mp3";
    final File convertedFile = await File(localAudioPath).writeAsBytes(
      asset.buffer.asUint8List(),
    );

    setState(() {
      isProcessingFile = true;
    });

    final result = await whisperController.transcribe(
      model: model,
      audioPath: convertedFile.path,
      // lang: 'auto',
      lang: 'en',
    );

    setState(() {
      isProcessingFile = false;
    });

    if (result?.transcription.text != null) {
      setState(() {
        transcribedText = result!.transcription.text;
      });
    }
  }

  
}


/*

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:onnxruntime/onnxruntime.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Igbo Offline STT + MT',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final recorder = Record();
  WhisperGgml? whisper;
  OrtSession? ortSession;
  String igboText = '';
  String englishText = '';
  bool isRecording = false;
  bool modelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _initModels();
  }

  Future<void> _initModels() async {
    // Load Whisper ggml model from assets
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);

    // Copy assets to documents (Flutter assets are read-only inside bundle)
    await _copyAssetIfAbsent('assets/models/whisper_igbo_ggml.bin',
        '${modelsDir.path}/whisper_igbo_ggml.bin');
    await _copyAssetIfAbsent('assets/models/opus_mt_ig_en.onnx',
        '${modelsDir.path}/opus_mt_ig_en.onnx');

    // Initialize whisper_ggml
    whisper = await WhisperGgml.create(modelPath: '${modelsDir.path}/whisper_igbo_ggml.bin');

    // Initialize ONNX runtime session for opus-mt-ig-en
    OrtEnv env = OrtEnv.instance;
    ortSession = await OrtSession.createFromPath('${modelsDir.path}/opus_mt_ig_en.onnx');

    setState(() {
      modelsLoaded = true;
    });
  }

  Future<void> _copyAssetIfAbsent(String assetPath, String destPath) async {
    final destFile = File(destPath);
    if (destFile.existsSync()) return;
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await destFile.writeAsBytes(bytes);
  }

  Future<void> _startOrStopRecording() async {
    if (!isRecording) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/recorded.wav';
      await recorder.start(path: path, encoder: AudioEncoder.wav, bitRate: 128000, samplingRate: 16000);
      setState(() => isRecording = true);
    } else {
      final path = await recorder.stop();
      setState(() => isRecording = false);
      if (path != null) {
        await _runTranscription(path);
      }
    }
  }

  Future<void> _runTranscription(String audioPath) async {
    setState(() {
      igboText = 'Transcribing...';
      englishText = '';
    });

    if (whisper == null) return;

    // whisper_ggml exposes a simple API to transcribe the wav file
    final result = await whisper!.transcribe(audioPath);
    setState(() {
      igboText = result.text ?? '';
    });

    // run translation on the result
    await _runTranslation(igboText);
  }

  Future<void> _runTranslation(String sourceIgbo) async {
    if (ortSession == null) return;

    setState(() {
      englishText = 'Translating...';
    });

    // NOTE:
    // Running Marian/Opus models via ONNX requires tokenization & detokenization.
    // For brevity this demo uses a naive approach: send raw text as input nodes
    // to a small exported ONNX model that expects 'input_ids' already tokenized.
    // In practice you MUST export a model that accepts raw string or implement
    // SentencePiece tokenization in Dart (or bundle the tokenizers via native).

    // For a working pipeline: preprocess text using sentencepiece (python) and
    // save vocabulary IDs, OR export a model with a preprocessing step baked-in.

    // For demo, we'll call a helper isolate that runs a small python microservice
    // — but the user asked for purely local Flutter; so in the README we provide
    // instructions to export an ONNX model that embeds sentencepiece so the app
    // can pass a raw string. If you exported such a model, the following shows
    // how to run it using onnxruntime.

    // Example (pseudo):
    final inputName = ortSession!.inputNames.first;
    final inputTensor = OrtValueTensor.createTensorWithDataString([sourceIgbo]);
    final inputs = {inputName: inputTensor};
    final outputs = await ortSession!.runAsync(OrtRunOptions(), inputs);

    // Get the model's text output (depends on how you exported the model)
    final out0 = outputs.first;
    final bytes = out0.toUtf8String();

    setState(() {
      englishText = bytes;
    });

    // release ort objects
    inputTensor.release();
    outputs.forEach((e) => e.release());
  }

  @override
  void dispose() {
    whisper?.dispose();
    ortSession?.release();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Igbo Offline STT → EN')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: modelsLoaded ? _startOrStopRecording : null,
              child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            SizedBox(height: 12),
            Text('Igbo transcription:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            SelectableText(igboText),
            SizedBox(height: 12),
            Text('English translation:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            SelectableText(englishText),
          ],
        ),
      ),
    );
  }
}

*/
*/
