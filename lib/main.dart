import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PianoApp());
}

class PianoApp extends StatelessWidget {
  const PianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Trainer - Fase 4',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChordTrainerScreen(),
    );
  }
}

class ChordDefinition {
  final String name; // Ej: "C", "Cm", "C7"
  final String displayName; // Ej: "Do Mayor", "Do Menor", "Do Séptima"
  final List<int> intervals; // Intervalos relativos desde la tónica (ej: [0, 4, 7] para Mayor)

  const ChordDefinition({
    required this.name,
    required this.displayName,
    required this.intervals,
  });
}

class ChordTrainerScreen extends StatefulWidget {
  const ChordTrainerScreen({super.key});

  @override
  State<ChordTrainerScreen> createState() => _ChordTrainerScreenState();
}

class _ChordTrainerScreenState extends State<ChordTrainerScreen> {
  final MidiCommand _midiCommand = MidiCommand();
  StreamSubscription<MidiPacket>? _midiDataSubscription;
  StreamSubscription<String>? _midiSetupSubscription;

  MidiDevice? _connectedDevice;
  bool _isConnected = false;

  final Set<int> _activeNotes = {};

  // Reto de Acordes
  String? _targetChordName;
  List<int> _targetChordNotes = [];
  int _score = 0;
  String _feedbackMessage = 'Toca el acorde indicado en el piano';
  Color _feedbackColor = Colors.grey;

  // Banco de acordes básicos de práctica (Construidos sobre la octava 4)
  static const List<Map<String, dynamic>> _chordDatabase = [
    {'root': 60, 'name': 'C', 'display': 'DO Mayor', 'intervals': [0, 4, 7]},
    {'root': 60, 'name': 'Cm', 'display': 'DO Menor', 'intervals': [0, 3, 7]},
    {'root': 60, 'name': 'C7', 'display': 'DO Séptima', 'intervals': [0, 4, 7, 10]},
    {'root': 62, 'name': 'D', 'display': 'RE Mayor', 'intervals': [0, 4, 7]},
    {'root': 62, 'name': 'Dm', 'display': 'RE Menor', 'intervals': [0, 3, 7]},
    {'root': 65, 'name': 'F', 'display': 'FA Mayor', 'intervals': [0, 4, 7]},
    {'root': 67, 'name': 'G', 'display': 'SOL Mayor', 'intervals': [0, 4, 7]},
    {'root': 69, 'name': 'Am', 'display': 'LA Menor', 'intervals': [0, 3, 7]},
  ];

  @override
  void initState() {
    super.initState();
    _initMidi();
    _generateNewTargetChord();
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

  void _generateNewTargetChord() {
    final random = Random();
    final chordInfo = _chordDatabase[random.nextInt(_chordDatabase.length)];
    
    int rootNote = chordInfo['root'];
    List<int> intervals = chordInfo['intervals'];

    setState(() {
      _targetChordName = chordInfo['display'];
      _targetChordNotes = intervals.map((interval) => rootNote + interval).toList();
      _feedbackMessage = '¡Toca el acorde de $_targetChordName!';
      _feedbackColor = Colors.cyanAccent;
    });
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
        _evaluateChord();
      } else if (status == 0x80 || (status == 0x90 && velocity == 0)) {
        _activeNotes.remove(noteNumber);
      }
    });
  }

  /// Compara si el conjunto de notas presionadas coincide exactamente con el acorde objetivo
  void _evaluateChord() {
    if (_targetChordNotes.isEmpty) return;

    // Verificamos si todas las notas del acorde objetivo están contenidas en las notas activas
    bool matches = _targetChordNotes.every((note) => _activeNotes.contains(note)) &&
                   _activeNotes.length == _targetChordNotes.length;

    if (matches) {
      setState(() {
        _score += 20;
        _feedbackMessage = '¡Acorde Correcto! 🎉';
        _feedbackColor = Colors.greenAccent;
      });

      Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _generateNewTargetChord();
        }
      });
    }
  }

  @override
  void dispose() {
    _midiDataSubscription?.cancel();
    _midiSetupSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenador de Acordes - Fase 4'),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Puntuación: $_score',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
            ),
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
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ACORDE OBJETIVO:',
                    style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _targetChordName ?? '--',
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _feedbackMessage,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _feedbackColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 200,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.black54,
            child: InteractivePianoKeyboard(
              activeNotes: _activeNotes,
              targetNotes: _targetChordNotes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Card(
      elevation: 2,
      color: _isConnected ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
      child: ListTile(
        leading: Icon(
          _isConnected ? Icons.usb_rounded : Icons.usb_off_rounded,
          color: _isConnected ? Colors.greenAccent : Colors.redAccent,
        ),
        title: Text(
          _isConnected ? 'Piano Conectado: ${_connectedDevice?.name ?? ""}' : 'Modo simulación / Sin piano USB',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class InteractivePianoKeyboard extends StatelessWidget {
  final Set<int> activeNotes;
  final List<int> targetNotes;

  static const int startNote = 60;
  static const int totalKeys = 25;

  const InteractivePianoKeyboard({
    super.key,
    required this.activeNotes,
    required this.targetNotes,
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
                bool isTarget = targetNotes.contains(noteNumber);

                Color keyColor = Colors.white;
                if (isActive) {
                  keyColor = Colors.deepPurpleAccent;
                } else if (isTarget) {
                  keyColor = Colors.cyan.shade100;
                }

                return Container(
                  width: whiteKeyWidth,
                  height: whiteKeyHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: keyColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                    border: Border.all(color: isTarget ? Colors.cyan : Colors.grey.shade400, width: 1),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _getNoteLabel(noteNumber),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
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
        bool isTarget = targetNotes.contains(note);

        Color blackColor = Colors.black;
        if (isActive) {
          blackColor = Colors.cyanAccent;
        } else if (isTarget) {
          blackColor = Colors.orange.shade300;
        }

        blackKeyWidgets.add(
          Positioned(
            left: leftPosition,
            top: 0,
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
        );
      } else {
        whiteIndex++;
      }
    }
    return blackKeyWidgets;
  }
}