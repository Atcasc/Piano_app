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
      home: const MidiMonitorScreen(),
    );
  }
}

class MidiMonitorScreen extends StatefulWidget {
  const MidiMonitorScreen({super.key});

  @override
  State<MidiMonitorScreen> createState() => _MidiMonitorScreenState();
}

class _MidiMonitorScreenState extends State<MidiMonitorScreen> {
  // Instancia principal del plugin flutter_midi_command
  final MidiCommand _midiCommand = MidiCommand();

  // Suscripciones a los streams del plugin
  StreamSubscription<MidiPacket>? _midiDataSubscription;
  StreamSubscription<String>? _midiSetupSubscription;

  // Variables de estado de la app
  MidiDevice? _connectedDevice;
  bool _isConnected = false;
  String _lastNoteName = "--";
  String _lastNoteSolfege = "--";
  int _lastOctave = 0;
  int _lastVelocity = 0;
  bool _isNoteActive = false;

  // Nombres de las notas musicales en notación Cifra (Anglosajona) y Solfeo
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

  /// Inicialización y escucha de eventos MIDI
  void _initMidi() {
    // 1. Escuchar cambios de estado en las conexiones Plug & Play (conectar/desconectar cable USB)
    _midiSetupSubscription = _midiCommand.onMidiSetupChanged?.listen((data) {
      debugPrint("Cambio en dispositivos MIDI detectado: $data");
      _checkConnectedDevices();
    });

    // 2. Escuchar la transmisión de datos MIDI en tiempo real
    _midiDataSubscription = _midiCommand.onMidiDataReceived?.listen((MidiPacket packet) {
      _processMidiPacket(packet);
    });

    // 3. Revisar si el piano ya está conectado al arrancar la app
    _checkConnectedDevices();
  }

  /// Revisa la lista de dispositivos MIDI USB disponibles y se conecta al primero disponible
  Future<void> _checkConnectedDevices() async {
    List<MidiDevice>? devices = await _midiCommand.devices;

    if (devices != null && devices.isNotEmpty) {
      MidiDevice device = devices.first;
      
      // Conectar automáticamente al piano detectado
      if (_connectedDevice == null || _connectedDevice!.id != device.id) {
        _midiCommand.connectToDevice(device);
        setState(() {
          _connectedDevice = device;
          _isConnected = true;
        });
      }
    } else {
      // No hay dispositivos conectados
      setState(() {
        _connectedDevice = null;
        _isConnected = false;
      });
    }
  }

  /// Procesa los paquetes binarios MIDI recibidos del teclado
  /// Estructura estándar MIDI:
  /// Byte 0: Status Byte (Ej: 0x90 = Note On, 0x80 = Note Off)
  /// Byte 1: Note Number (0 - 127) -> 60 es C4 / DO Central
  /// Byte 2: Velocity (0 - 127) -> Fuerza con la que se presiona la tecla
  void _processMidiPacket(MidiPacket packet) {
    final List<int> data = packet.data;

    // Validación básica de protocolo MIDI
    if (data.length < 3) return;

    int status = data[0] & 0xF0; // Máscara para obtener el tipo de comando ignorando el canal
    int noteNumber = data[1];
    int velocity = data[2];

    // Status 0x90 = Note On (Nota Presionada)
    // Nota: Algunos pianos envían Note On con Velocity = 0 en lugar de Note Off
    if (status == 0x90 && velocity > 0) {
      _updateNoteUI(noteNumber, velocity, isPressed: true);
    } 
    // Status 0x80 = Note Off (Nota Soltada)
    else if (status == 0x80 || (status == 0x90 && velocity == 0)) {
      _updateNoteUI(noteNumber, 0, isPressed: false);
    }
  }

  /// Convierte el número MIDI (0-127) a nota, octava y nombre visual
  void _updateNoteUI(int noteNumber, int velocity, {required bool isPressed}) {
    // El índice de la nota dentro de la octava (0 = C/DO, 1 = C#/DO#, ..., 11 = B/SI)
    int noteIndex = noteNumber % 12;
    // Cálculo de la octava (MIDI 60 = C4)
    int octave = (noteNumber ~/ 12) - 1;

    setState(() {
      _isNoteActive = isPressed;
      if (isPressed) {
        _lastNoteName = _noteNamesEnglish[noteIndex];
        _lastNoteSolfege = _noteNamesSolfege[noteIndex];
        _lastOctave = octave;
        _lastVelocity = velocity;
      }
    });
  }

  @override
  void dispose() {
    // Cancelar suscripciones para evitar fugas de memoria (Memory Leaks)
    _midiDataSubscription?.cancel();
    _midiSetupSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano MIDI Connector'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicador de Estado de Conexión USB
            _buildConnectionStatusCard(),

            const Spacer(),

            // Visualización de la Nota en Tiempo Real
            _buildNoteDisplay(),

            const Spacer(),

            // Indicador visual de la Intensidad/Fuerza (Velocity)
            _buildVelocityBar(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Widget para mostrar el estado de la conexión USB y nombre del piano
  Widget _buildConnectionStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _isConnected ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
      child: ListTile(
        leading: Icon(
          _isConnected ? Icons.usb_rounded : Icons.usb_off_rounded,
          color: _isConnected ? Colors.greenAccent : Colors.redAccent,
          size: 32,
        ),
        title: Text(
          _isConnected ? 'Piano Conectado' : 'Sin conexión USB',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _isConnected 
              ? (_connectedDevice?.name ?? 'Dispositivo MIDI USB') 
              : 'Conecta tu piano digital con un cable USB',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  /// Widget central que muestra la nota actual en pantalla
  Widget _buildNoteDisplay() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _isNoteActive ? Colors.deepPurple.shade700 : Colors.grey.shade900,
        shape: BoxShape.circle,
        boxShadow: _isNoteActive
            ? [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nota en Cifra + Octava (Ejemplo: C4 / G#3)
          Text(
            _isNoteActive ? '$_lastNoteName$_lastOctave' : '--',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: _isNoteActive ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          // Nota en Solfeo (Ejemplo: DO4 / SOL#3)
          Text(
            _isNoteActive ? '$_lastNoteSolfege$_lastOctave' : 'Toca una tecla',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: _isNoteActive ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de progreso para indicar la intensidad de la pulsación (Velocity 0 a 127)
  Widget _buildVelocityBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Intensidad (Velocity):", style: TextStyle(color: Colors.grey)),
            Text(
              "$_lastVelocity / 127",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _lastVelocity / 127.0,
            minHeight: 12,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(
              _lastVelocity > 100 ? Colors.redAccent : Colors.deepPurpleAccent,
            ),
          ),
        ),
      ],
    );
  }
}