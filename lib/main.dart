import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:just_audio/just_audio.dart';

import 'package:rxdart/rxdart.dart';
import 'package:window_manager/window_manager.dart';

import 'common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  if (Platform.isWindows) {
    WindowManager.instance.setMinimumSize(const Size(360, 640));
    WindowManager.instance.setMaximumSize(const Size(360, 640));
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  var audiopath = "";
  var audio_metadata = Metadata();
  var current_index = -1;

  @override
  void initState() {
    final file = DirectoryPicker()
      ..filterSpecification = {
        'Media (*.mp3)': '*.mp3',
      }
      ..defaultFilterIndex = 0
      ..defaultExtension = 'mp3'
      ..title = 'Select a Music';

    final result = file.getDirectory();
    if (result != null) {
      audiopath = result.path;
    }

    MetadataRetriever.fromFile(File(Directory(audiopath).listSync()[0].path))
        .then((value) => setState(() => audio_metadata = value));
    super.initState();
    ambiguate(WidgetsBinding.instance)!.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    try {
      await _player.setAudioSource(ConcatenatingAudioSource(
          useLazyPreparation: true,
          shuffleOrder: DefaultShuffleOrder(),
          children: Directory(audiopath)
              .listSync()
              .map((item) => AudioSource.file(item.path) as AudioSource)
              .toList()));
    } on PlayerException catch (e) {
      print("Error loading audio source: $e");
    }
  }

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.stop();
    }
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () {}, icon: Icon(Icons.arrow_back_ios)),
                      IconButton(onPressed: () {}, icon: Icon(Icons.menu))
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  child: StreamBuilder<PositionData>(
                    stream: _positionDataStream,
                    builder: (context, snapshot) {
                      if(_player.currentIndex != null && _player.currentIndex != current_index ){
                        MetadataRetriever.fromFile(File(Directory(audiopath).listSync()[_player.currentIndex!].path))
                            .then((value) => setState(() => audio_metadata = value));
                        setState(() {
                          current_index = _player.currentIndex!;
                        });
                      }
                      final positionData = snapshot.data;
                      return Transform.rotate(
                          angle: pi,
                          child: SeekBar(
                            duration: positionData?.duration ?? Duration.zero,
                            position: positionData?.position ?? Duration.zero,
                            bufferedPosition:
                                positionData?.bufferedPosition ?? Duration.zero,
                            onChangeEnd: _player.seek,
                          ));
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 16.0, left: 4, right: 4),
                  child: ControlButtons(_player),
                )
              ],
            ),
          ),
          Column(
            children: [
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Container(
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(100),
                            bottomLeft: Radius.circular(100)),
                        boxShadow: [
                          BoxShadow(
                              spreadRadius: 4,
                              color: Colors.black12,
                              blurRadius: 50,
                              blurStyle: BlurStyle.normal)
                        ]),
                    child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(130),
                            bottomLeft: Radius.circular(130)),
                        child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: Image(
                              image: MemoryImage(audio_metadata.albumArt!),
                              fit: BoxFit.cover,
                            ))),
                  ),
                ),
              ),
              Expanded(flex: 3, child: SizedBox(width: double.infinity))
            ],
          ),
        ]),
      ),
    );
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(size: 24.0, Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 18.0,
                onPressed: player.seekToNext,
              ),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final processingState = playerState?.processingState;
                  final playing = playerState?.playing;
                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return Container(
                      margin: const EdgeInsets.all(8.0),
                      width: 30.0,
                      height: 30.0,
                      child: const CircularProgressIndicator(),
                    );
                  } else if (playing != true) {
                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(100)),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        iconSize: 30.0,
                        onPressed: player.play,
                      ),
                    );
                  } else if (processingState != ProcessingState.completed) {
                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(100)),
                      child: IconButton(
                        icon: const Icon(Icons.pause, color: Colors.white),
                        iconSize: 30.0,
                        onPressed: player.pause,
                      ),
                    );
                  } else {
                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(100)),
                      child: IconButton(
                        icon: const Icon(
                          Icons.replay,
                          color: Colors.white,
                        ),
                        iconSize: 28.0,
                        onPressed: () => player.seek(Duration.zero),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 18.0,
                onPressed: player.seekToPrevious,
              ),
            ]),

        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}
