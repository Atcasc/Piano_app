import 'dart:async';
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
      title: 'Piano Trainer USB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PianoScreen(),
    );
  }
}

class PianoScreen extends StatefulWidget {
  const PianoScreen({super.key});

  @override
  State<PianoScreen> createState() => _PianoScreenState();
}

class _PianoScreenState extends State<PianoScreen> {
  final MidiCommand _midiCommand = MidiCommand();
  StreamSubscription<MidiPacket>? _midiDataSubscription;
  StreamSubscription<String>? _midiSetupSubscription;

  MidiDevice? _connectedDevice;
  bool _isConnected = false;

  // Usamos un Set para almacenar las notas MIDI que están presionadas actualmente (Soporte Multi-Nota / Acordes)
  final Set<int> _activeNotes = {};
  int _lastVelocity = 0;

  // Nombres musicales
  static const List<String> _noteNamesEnglish = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  static const List<String> _noteNamesSolfege = [
    'DO', 'DO#', 'RE', 'RE#', 'MI', 'FA', 'FA#', 'SOL', 'SOL#', 'LA', 'LA#', 'SI'
  ];

  @override
  void initState() {
    super.initState();
    _initMidi();
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
      // Note On
      if (status == 0x90 && velocity > 0) {
        _activeNotes.add(noteNumber);
        _lastVelocity = velocity;
      } 
      // Note Off (o Note On con velocity 0)
      else if (status == 0x80 || (status == 0x90 && velocity == 0)) {
        _activeNotes.remove(noteNumber);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano Virtual - Fase 2'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Estado de conexión superior
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildConnectionStatusCard(),
          ),

          // 2. Panel de información de la última nota tocada
          Expanded(
            flex: 2,
            child: Center(
              child: _buildActiveNotesDisplay(),
            ),
          ),

          // 3. Teclado Virtual Interactivo (Piano Roll en pantalla)
          Container(
            height: 220,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.black54,
            child: InteractivePianoKeyboard(activeNotes: _activeNotes),
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
          _isConnected ? 'Piano Conectado: ${_connectedDevice?.name ?? ""}' : 'Desconectado (Conecta por USB)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActiveNotesDisplay() {
    if (_activeNotes.isEmpty) {
      return const Text(
        'Toca una tecla en tu piano físico...',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      );
    }

    // Convertir las notas activas a texto legible
    String notesText = _activeNotes.map((noteNumber) {
      int index = noteNumber % 12;
      int octave = (noteNumber ~/ 12) - 1;
      return '${_noteNamesEnglish[index]}$octave (${_noteNamesSolfege[index]})';
    }).join(', ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Notas Activas:', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Text(
          notesText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 12),
        Text('Velocity: $_lastVelocity', style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

/// Widget personalizado que dibuja un teclado de piano interactivo (Rango de 2 octavas: C4 a C6 por defecto)
class InteractivePianoKeyboard extends StatelessWidget {
  final Set<int> activeNotes;

  // Definimos el rango visual: desde C4 (MIDI 60) hasta C6 (MIDI 84) -> 25 notas
  static const int startNote = 60; // C4 / DO Central
  static const int totalKeys = 25;  // 2 octavas completas + 1 nota final

  const InteractivePianoKeyboard({super.key, required this.asyncActiveNotes, required this.activeNotes});

  @override
  Widget build(BuildContext context) {
    // Calculamos las teclas blancas dentro del rango para distribuirlas en fila
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
            // 1. Capa de Teclas Blancas
            Row(
              children: whiteKeys.map((noteNumber) {
                bool isActive = activeNotes.contains(noteNumber);
                return Container(
                  width: whiteKeyWidth,
                  height: whiteKeyHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.deepPurpleAccent : Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _getNoteLabel(noteNumber),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),

            // 2. Capa de Teclas Negras (Superpuestas con posicionamiento absoluto)
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
      return 'C$octave'; // Etiqueta los Do (C4, C5...)
    }
    return '';
  }

  List<Widget> _buildBlackKeys(int start, int total, double whiteWidth, double blackWidth, double blackHeight) {
    List<Widget> blackKeyWidgets = [];
    int whiteIndex = 0;

    for (int i = 0; i < total; i++) {
      int note = start + i;
      if (_isBlackKey(note)) {
        // Posicionar la tecla negra exactamente entre las teclas blancas correspondientes
        double leftPosition = (whiteIndex * whiteWidth) - (blackWidth / 2) + (whiteWidth * 0.7);
        bool isActive = activeNotes.contains(note);

        blackKeyWidgets.append(
          Positioned(
            left: leftPosition,
            top: 0,
            child: Container(
              width: blackWidth,
              height: blackHeight,
              decoration: BoxDecoration(
                color: isActive ? Colors.cyanAccent : Colors.black,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
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