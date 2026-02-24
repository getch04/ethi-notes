import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/eleven_labs_api.dart';
import 'services/recording_service.dart';

// Warm dark theme: paper-like dark with amber accent (EthioNote / notes vibe)
const Color _kBackground = Color(0xFF0F0E0E);
const Color _kSurface = Color(0xFF1A1918);
const Color _kSurfaceBorder = Color(0xFF2A2826);
const Color _kAccent = Color(0xFFD4A574); // warm amber
const Color _kAccentMuted = Color(0xFF8B7355);
const Color _kRecording = Color(0xFFC45C3E); // warm coral
const Color _kTextPrimary = Color(0xFFF5F0EB);
const Color _kTextSecondary = Color(0xFF9C958C);
const Color _kTextMuted = Color(0xFF5C5650);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e, stackTrace) {
    debugPrint(
      "Warning: .env file not found. Ensure API key is provided via --dart-define.",
    );
    debugPrint("Exception: $e");
    debugPrint("Stack trace: $stackTrace");
  }
  runApp(const EthioNoteApp());
}

class EthioNoteApp extends StatelessWidget {
  const EthioNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EthioNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBackground,
        colorScheme: ColorScheme.dark(
          surface: _kSurface,
          primary: _kAccent,
          onSurface: _kTextPrimary,
          onSurfaceVariant: _kTextSecondary,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: _kTextPrimary,
          displayColor: _kTextPrimary,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kSurface,
          contentTextStyle: GoogleFonts.outfit(color: _kTextPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

/// Returns a short, user-friendly message for SnackBars. Keeps technical details for logs only.
String _friendlyErrorMessage(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('api key') || s.contains('missing') && s.contains('key')) {
    return 'API key is missing or invalid. Check your .env or app settings.';
  }
  if (s.contains('connection') || s.contains('network') || s.contains('socket') ||
      s.contains('connection refused') || s.contains('failed host lookup')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'Request timed out. Please try again.';
  }
  if (s.contains('401') || s.contains('unauthorized') || s.contains('invalid api')) {
    return 'Invalid API key. Please check your settings.';
  }
  if (s.contains('403') || s.contains('forbidden')) {
    return 'Access denied. Check your API key or plan.';
  }
  if (s.contains('429') || s.contains('rate limit') || s.contains('too many')) {
    return 'Too many requests. Please wait a moment and try again.';
  }
  if (s.contains('500') || s.contains('502') || s.contains('503') || s.contains('server')) {
    return 'Service temporarily unavailable. Please try again later.';
  }
  if (s.contains('transcribe') || s.contains('speech')) {
    return 'Transcription failed. Please try recording again.';
  }
  return 'Something went wrong. Please try again.';
}

enum AppState { ready, listening, transcribing }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final RecordingService _recordingService = RecordingService();
  final ElevenLabsApiService _apiService = ElevenLabsApiService();

  AppState _currentState = AppState.ready;
  String _transcript = "";
  String _selectedLanguage = "eng"; // Default to English

  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_currentState == AppState.ready) {
      // Start Recording
      final bool hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        debugPrint("Microphone permission denied");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission denied")),
          );
        }
        return;
      }

      final path = await _recordingService.startRecording();
      if (path != null) {
        setState(() {
          _currentState = AppState.listening;
          // _lastFilePath = path;
        });
      }
    } else if (_currentState == AppState.listening) {
      // Stop Recording
      setState(() => _currentState = AppState.transcribing);

      final path = await _recordingService.stopRecording();
      if (path != null) {
        try {
          final result = await _apiService.transcribe(
            filePath: path,
            languageCode: _selectedLanguage,
          );

          setState(() {
            if (result != null && result.isNotEmpty) {
              _transcript += (_transcript.isEmpty ? "" : " ") + result;
            }
            _currentState = AppState.ready;
          });
        } catch (e, stackTrace) {
          setState(() => _currentState = AppState.ready);
          debugPrint("Transcribe error: $e");
          debugPrint("Stack trace: $stackTrace");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyErrorMessage(e))),
            );
          }
        }
      } else {
        setState(() => _currentState = AppState.ready);
      }
    }
  }

  void _copyToClipboard() {
    if (_transcript.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _transcript));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
    }
  }

  void _clearTranscript() {
    setState(() => _transcript = "");
  }

  int get _wordCount =>
      _transcript.isEmpty ? 0 : _transcript.trim().split(RegExp(r'\s+')).length;

  @override
  Widget build(BuildContext context) {
    final isRecording = _currentState == AppState.listening;
    final isTranscribing = _currentState == AppState.transcribing;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              _kBackground,
              Color(0xFF141210),
              _kBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.mic_none, color: _kAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "EthioNote",
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: _kTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _LanguageChip(
                          label: "English",
                          isSelected: _selectedLanguage == "eng",
                          onTap: () => setState(() => _selectedLanguage = "eng"),
                        ),
                        const SizedBox(width: 8),
                        _LanguageChip(
                          label: "አማርኛ",
                          isSelected: _selectedLanguage == "amh",
                          onTap: () => setState(() => _selectedLanguage = "amh"),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // Central mic button
                Center(
                  child: _RecordingButton(
                    isRecording: isRecording,
                    isTranscribing: isTranscribing,
                    onTap: _toggleRecording,
                  ),
                ),

                const SizedBox(height: 20),

                // Status
                Center(
                  child: Text(
                    isTranscribing
                        ? "Transcribing..."
                        : isRecording
                            ? "Listening..."
                            : "Tap to start",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const Spacer(),

                // Transcript card
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kSurfaceBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        // Top accent line
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_kAccent, _kAccent.withOpacity(0.5)],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Text(
                                      _transcript.isEmpty
                                          ? "Your transcript will appear here..."
                                          : _transcript,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        height: 1.6,
                                        color: _transcript.isEmpty
                                            ? _kTextMuted
                                            : _kTextPrimary,
                                        fontStyle: _transcript.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$_wordCount words",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: _kTextMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _ActionButton(
                                          icon: Icons.copy_rounded,
                                          label: "Copy",
                                          onPressed: _transcript.isEmpty
                                              ? null
                                              : _copyToClipboard,
                                          accent: _kAccent,
                                        ),
                                        const SizedBox(width: 8),
                                        _ActionButton(
                                          icon: Icons.delete_outline_rounded,
                                          label: "Clear",
                                          onPressed: _transcript.isEmpty
                                              ? null
                                              : _clearTranscript,
                                          accent: _kRecording,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingButton extends StatefulWidget {
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback? onTap;

  const _RecordingButton({
    required this.isRecording,
    required this.isTranscribing,
    required this.onTap,
  });

  @override
  State<_RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<_RecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isTranscribing;

    return GestureDetector(
      onTap: disabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glow = widget.isRecording
              ? 0.25 + 0.15 * _pulseController.value
              : 0.0;
          return Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (widget.isRecording)
                  BoxShadow(
                    color: _kRecording.withOpacity(glow),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isRecording
                ? _kRecording
                : _kAccent.withOpacity(0.12),
            border: Border.all(
              color: widget.isRecording ? _kRecording : _kAccent,
              width: widget.isRecording ? 4 : 3,
            ),
          ),
          child: Icon(
            widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            size: 48,
            color: widget.isRecording ? _kTextPrimary : _kAccent,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color accent;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: onPressed != null ? accent : _kTextMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onPressed != null ? accent : _kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kAccent : _kSurfaceBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? _kAccent : _kTextSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
