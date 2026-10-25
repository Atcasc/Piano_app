import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi/flutter_midi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PianoApp());
}

class PianoApp extends StatelessWidget {
  const PianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Trainer - Fase 6 (Canciones)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SongPracticeScreen(),
    );
  }
}

class SongPracticeScreen extends StatefulWidget {
  const SongPracticeScreen({super.key});

  @override
  State<SongPracticeScreen> createState() => _SongPracticeScreenState();
}

class _SongPracticeScreenState extends State<SongPracticeScreen> {
  final MidiCommand _midiCommand = MidiCommand();
  final FlutterMidi _flutterMidi = FlutterMidi();

  StreamSubscription<MidiPacket>? _midiDataSubscription;
  StreamSubscription<String>? _midiSetupSubscription;

  MidiDevice? _connectedDevice;
  bool _isConnected = false;
  bool _isSoundLoaded = false;

  final Set<int> _activeNotes = {};

  // Definición de una canción de práctica (Secuencia de notas MIDI)
  // Ejemplo: "Estrellita, ¿dónde estás?" (C4, C4, G4, G4, A4, A4, G4...)
  // C4 = 60, D4 = 62, E4 = 64, F4 = 65, G4 = 67, A4 = 69
  final List<int> _songNotes = [60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60];
  final List<String> _songNoteNames = ['DO', 'DO', 'SOL', 'SOL', 'LA', 'LA', 'SOL', 'FA', 'FA', 'MI', 'MI', 'RE', 'RE', 'DO'];
  
  int _currentNoteIndex = 0;
  bool _songCompleted = false;
  String _feedbackMessage = 'Toca la primera nota de la canción';
  Color _feedbackColor = Colors.cyanAccent;

  @override
  void initState() {
    super.initState();
    _initAudioSynthesizer();
    _initMidi();
  }

  Future<void> _initAudioSynthesizer() async {
    try {
      await _flutterMidi.unmute();
      setState(() {
        _isSoundLoaded = true;
      });
    } catch (e) {
      debugPrint("Error sintetizador: $e");
    }
  }

  void _initMidi() {
    _midiSetupSubscription = _midiCommand.onMidiSetupChanged?.listen((data) {
      _checkConnectedDevices();
    });

    _midiDataSubscription = _midiCommand.onMidiDataReceived?.listen((MidiPacket packet) {
      _processMidiPacket(packet);
    });

    _checkConnectedDevices();
  }

  Future<void> _checkConnectedDevices() async {
    List<MidiDevice>? devices = await _midiCommand.devices;
    if (devices != null && devices.isNotEmpty) {
      MidiDevice device = devices.first;
      if (_connectedDevice == null || _connectedDevice!.id != device.id) {
        _midiCommand.connectToDevice(device);
        setState(() {
          _connectedDevice = device;
          _isConnected = true;
        });
      }
    } else {
      setState(() {
        _connectedDevice = null;
        _isConnected = false;
        _activeNotes.clear();
      });
    }
  }

  void _processMidiPacket(MidiPacket packet) {
    final List<int> data = packet.data;
    if (data.length < 3) return;

    int status = data[0] & 0xF0;
    int noteNumber = data[1];
    int velocity = data[2];

    setState(() {
      if (status == 0x90 && velocity > 0) {
        _activeNotes.add(noteNumber);
        _playLocalNote(noteNumber);
        _evaluateSongProgress(noteNumber);
      } else if (status == 0x80 || (status == 0x90 && velocity == 0)) {
        _activeNotes.remove(noteNumber);
      }
    });
  }

  void _playLocalNote(int noteNumber) {
    if (_isSoundLoaded) {
      _flutterMidi.playMidiNote(midi: noteNumber);
    }
  }

  /// Evalúa si el usuario tocó la nota exacta que correspondía en la canción
  void _evaluateSongProgress(int playedNote) {
    if (_songCompleted) return;

    int expectedNote = _songNotes[_currentNoteIndex];

    if (playedNote == expectedNote) {
      // ¡Nota correcta! Avanzamos en la canción
      setState(() {
        _currentNoteIndex++;
        if (_currentNoteIndex >= _songNotes.length) {
          _songCompleted = true;
          _feedbackMessage = '¡Felicidades! Has completado la canción 🏆';
          _feedbackColor = Colors.greenAccent;
        } else {
          _feedbackMessage = '¡Bien! Siguiente nota...';
          _feedbackColor = Colors.greenAccent;
        }
      });
    } else {
      // Nota incorrecta
      setState(() {
        _feedbackMessage = 'Ups, esperábamos ${_songNoteNames[_currentNoteIndex]}. ¡Inténtalo de nuevo!';
        _feedbackColor = Colors.orangeAccent;
      });
    }
  }

  void _resetSong() {
    setState(() {
      _currentNoteIndex = 0;
      _songCompleted = false;
      _feedbackMessage = 'Toca la primera nota de la canción';
      _feedbackColor = Colors.cyanAccent;
    });
  }

  /// Permite tocar desde la pantalla táctil para probar sin piano físico
  void _onVirtualKeyPressed(int noteNumber) {
    setState(() {
      _activeNotes.add(noteNumber);
    });
    _playLocalNote(noteNumber);
    _evaluateSongProgress(noteNumber);

    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _activeNotes.remove(noteNumber);
        });
      }
    });
  }

  @override
  void dispose() {
    _midiDataSubscription?.cancel();
    _midiSetupSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int? targetNote = _songCompleted ? null : _songNotes[_currentNoteIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Práctica de Canciones - Fase 6'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetSong,
            tooltip: 'Reiniciar Canción',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildConnectionStatusCard(),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'CANCIÓN: ESTRELLITA DÓNDE ESTÁS',
                    style: TextStyle(fontSize: 13, color: Colors.grey, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  // Progreso de la canción
                  Text(
                    _songCompleted ? '¡Completada!' : 'Nota ${_currentNoteIndex + 1} de ${_songNotes.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 24),
                  // Nota actual a tocar en grande
                  Text(
                    _songCompleted ? '🌟' : '${_songNoteNames[_currentNoteIndex]}',
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      _feedbackMessage,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _feedbackColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Teclado virtual interactivo que resalta la nota objetivo de la canción
          Container(
            height: 220,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.black54,
            child: InteractiveSongPianoKeyboard(
              activeNotes: _activeNotes,
              targetNote: targetNote,
              onKeyPressed: _onVirtualKeyPressed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      elevation: 2,
      color: _isConnected ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
      child: ListTile(
        leading: Icon(
          _isConnected ? Icons.usb_rounded : Icons.info_outline_rounded,
          color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
        ),
        title: Text(
          _isConnected ? 'Piano USB Conectado' : 'Modo Táctil / Sin cable USB',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _isConnected ? (_connectedDevice?.name ?? '') : 'Toca la pantalla o conecta tu piano por USB',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

/// Teclado virtual optimizado para la práctica de canciones
class InteractiveSongPianoKeyboard extends StatelessWidget {
  final Set<int> activeNotes;
  final int? targetNote;
  final ValueChanged<int> onKeyPressed;

  static const int startNote = 60; // C4
  static const int totalKeys = 25;  // 2 octavas

  const InteractiveSongPianoKeyboard({
    super.key,
    required this.activeNotes,
    required this.targetNote,
    required this.onKeyPressed,
  });

  @override
  Widget build(BuildContext context) {
    List<int> whiteKeys = [];
    for (int i = 0; i < totalKeys; i++) {
      int note = startNote + i;
      if (!_isBlackKey(note)) {
        whiteKeys.add(note);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double whiteKeyWidth = constraints.maxWidth / whiteKeys.length;
        double whiteKeyHeight = constraints.maxHeight;
        double blackKeyWidth = whiteKeyWidth * 0.65;
        double blackKeyHeight = whiteKeyHeight * 0.6;

        return Stack(
          children: [
            Row(
              children: whiteKeys.map((noteNumber) {
                bool isActive = activeNotes.contains(noteNumber);
                bool isTarget = targetNote == noteNumber;

                Color keyColor = Colors.white;
                if (isActive) {
                  keyColor = Colors.deepPurpleAccent;
                } else if (isTarget) {
                  keyColor = Colors.cyan.shade200; // Resalta la nota que debes tocar en la canción
                }

                return GestureDetector(
                  onTapDown: (_) => onKeyPressed(noteNumber),
                  child: Container(
                    width: whiteKeyWidth,
                    height: whiteKeyHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: keyColor,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                      border: Border.all(
                        color: isTarget ? Colors.cyan : Colors.grey.shade400,
                        width: isTarget ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _getNoteLabel(noteNumber),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isTarget ? Colors.black87 : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            ..._buildBlackKeys(startNote, totalKeys, whiteKeyWidth, blackKeyWidth, blackKeyHeight),
          ],
        );
      },
    );
  }

  bool _isBlackKey(int noteNumber) {
    int rem = noteNumber % 12;
    return rem == 1 || rem == 3 || rem == 6 || rem == 8 || rem == 10;
  }

  String _getNoteLabel(int noteNumber) {
    if (noteNumber % 12 == 0) {
      int octave = (noteNumber ~/ 12) - 1;
      return 'C$octave';
    }
    return '';
  }

  List<Widget> _buildBlackKeys(int start, int total, double whiteWidth, double blackWidth, double blackHeight) {
    List<Widget> blackKeyWidgets = [];
    int whiteIndex = 0;

    for (int i = 0; i < total; i++) {
      int note = start + i;
      if (_isBlackKey(note)) {
        double leftPosition = (whiteIndex * whiteWidth) - (blackWidth / 2) + (whiteWidth * 0.7);
        bool isActive = activeNotes.contains(note);
        bool isTarget = targetNote == note;

        Color blackColor = Colors.black;
        if (isActive) {
          blackColor = Colors.cyanAccent;
        } else if (isTarget) {
          blackColor = Colors.orange.shade350;
        }

        blackKeyWidgets.add(
          Positioned(
            left: leftPosition,
            top: 0,
            child: GestureDetector(
              onTapDown: (_) => onKeyPressed(note),
              child: Container(
                width: blackWidth,
                height: blackHeight,
                decoration: BoxDecoration(
                  color: blackColor,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        whiteIndex++;
      }
    }
    return blackKeyWidgets;
  }
}