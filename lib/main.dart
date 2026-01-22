import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:onnx_translation/onnx_translation.dart';

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:onnxruntime/onnxruntime.dart';
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
      home: const MyHomePage(title: 'Igbo → English Translator'),
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
  final assetFileName = 'assets/models/test.onnx';
  final whisperBinFile = 'assets/models/whisper_igbo_ggml.bin';
  final player = AudioPlayer();

  final model = WhisperModel.base;
  final onnxSessionOptions = OrtSessionOptions();
  final onnxModel = OnnxModel();
  OrtSession? ortSession;
  final AudioRecorder audioRecorder = AudioRecorder();
  final WhisperController whisperController = WhisperController();
  String transcribedText = 'Transcribed text will be displayed here';
  String englishText = '---';

  bool isProcessing = false;
  bool isProcessingFile = false;
  bool isListening = false;
  bool isTranslating = false;

  @override
  void initState() {
    initModel();
    // _loadOnnxSession();
    super.initState();
    _initOnnxModel();
  }

  _initOnnxModel() async {
    /*
    // final model = OnnxModel();
    await onnxModel.init(modelBasePath: 'assets/models/onnx_model_ig_en');
    // final output = await model.runModel("Hello world", initialLangToken: '>>ara<<');
    final output = await onnxModel.runModel(
      "Ndeewo, kedu ka ị mere?",
      // initialLangToken: "ig",
      initialLangToken: "en",
    );
    */
    await onnxModel.init(modelBasePath: 'assets/models/onnx_model_ig_en');
  }

  // 240143233: Ikwegbu George Chinedu

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
                  isTranslating
                      ? const SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(),
                        )
                      : Text(
                          // transcribedText,
                          englishText,
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
      final bytesBase = await rootBundle.load(whisperBinFile);
      final modelPathBase = await whisperController.getPath(model);
      final fileBase = File(modelPathBase);
      await fileBase.writeAsBytes(bytesBase.buffer
          .asUint8List(bytesBase.offsetInBytes, bytesBase.lengthInBytes));
    } catch (e) {
      debugPrint(
        "George this is the error from loading whisper model...${e.toString()}",
      );

      /// On error try downloading the model
      await whisperController.downloadModel(model);
    }
  }

  _loadOnnxSession() async {
    try {
      final rawAssetFile = await rootBundle.load(assetFileName);
      final bytes = rawAssetFile.buffer.asUint8List();
      final session = OrtSession.fromBuffer(bytes, onnxSessionOptions);
    } catch (e) {
      debugPrint(
        "George this is the error from loading onnx...${e.toString()}",
      );
    }
  }

  Future<void> record() async {
    if (await audioRecorder.hasPermission()) {
      if (await audioRecorder.isRecording()) {
        final audioPath = await audioRecorder.stop();

        if (audioPath != null) {
          debugPrint('🔴🔴🎙️ Stopped listening.');

          _updateTranscribedText(text: 'processing...');
          setState(() {
            isListening = false;
            isProcessing = true;
          });
          print("George this is the Audio path: $audioPath");
          // Trial
          final srcFile = File(audioPath);

          // Destination in shared storage
          final dstFile = File('/storage/emulated/0/Download/test.m4a');

          // Copy the file
          // await srcFile.copy(dstFile.path); // --- This was used to copy the file to a visible permission-less directory in the Emulator ---
          print('George the File was copied to ${dstFile.path}');

          await playAndTranslate(File(audioPath));
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
            _updateTranscribedText(text: result!.transcription.text);
            // _runIgEnTranslation(result.transcription.text);
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
            // path: '${appDirectory.path}/test.m4a');
            path: '${appDirectory.path}/test.m4a');
        _updateTranscribedText(text: 'listening...');
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

    _updateIsProcessing(true);
    _updateTranscribedText();
    await playAndTranslate(convertedFile);
    final result = await whisperController.transcribe(
      model: model,
      audioPath: convertedFile.path,
      // lang: 'auto',
      lang: 'en',
    );
    _updateIsProcessing(false);

    if (result?.transcription.text != null) {
      _updateTranscribedText(text: result!.transcription.text);
      // _runIgEnTranslation(result.transcription.text);
    }
  }

  _updateTranscribedText({String? text}) {
    setState(() {
      transcribedText = text ?? 'processing...';
    });
  }

  _updateIsProcessing(bool val) {
    setState(() {
      isProcessingFile = val;
    });
  }

  _updateIsTranslating(bool val) {
    setState(() {
      isTranslating = val;
    });
  }

  Future<void> playAndTranslate(File audioFile) async {
    // Play audio
    await player.setFilePath(audioFile.path);
    await player.play();
  }

  Future<void> _runIgEnTranslation(String sourceIgbo) async {
    print("Running Igbo to English translation...");
    _updateIsTranslating(true);
    print("Source Igbo: $sourceIgbo");
    await Future.delayed(const Duration(milliseconds: 500));
    final output = await onnxModel.runModel(sourceIgbo, initialLangToken: "en");
    setState(() {
      englishText = output;
    });
    _updateIsTranslating(false);
  }
}
