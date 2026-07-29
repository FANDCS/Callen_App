import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_strings.dart';

const _ringtoneChannel = MethodChannel('gr.fandcs.callen/ringtone');

/// Πόσο ρίχνει η κλήση αν δεν απαντηθεί, πριν σταματήσει μόνη της
/// (σαν χαμένη κλήση) — πραγματικές κλήσεις δεν χτυπάνε επ' άπειρον.
const _ringTimeout = Duration(seconds: 30);

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  final String callerNumber;
  final AppStrings strings;

  const FakeCallScreen({
    super.key,
    required this.callerName,
    required this.callerNumber,
    required this.strings,
  });

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with TickerProviderStateMixin {
  bool _answered = false;
  bool _ended = false;
  bool _muted = false;
  bool _onHold = false;
  bool _speaker = false;
  bool _showKeypad = false;
  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  Duration _callDuration = Duration.zero;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  // Ένας δεύτερος, πιο αργός controller για το animated background με
  // σχήματα — τρέχει σε όλη τη διάρκεια (και ringing και in-call), όχι
  // μόνο στο ringing, ώστε η οθόνη να μη μοιάζει στατική/ψεύτικη μετά
  // την αποδοχή.
  late final AnimationController _bgController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  bool _contentVisible = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
    _ringTimeoutTimer = Timer(_ringTimeout, _missedCall);
    // Απαλό fade-in του περιεχομένου κατά το άνοιγμα της οθόνης —
    // αποφεύγει το "σκέτο pop-in" που έδειχνε στατικό/ψεύτικο.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _contentVisible = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bgController.dispose();
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _ringtoneChannel.invokeMethod('release');
    super.dispose();
  }

  void _startRinging() {
    // "play": ήχος + exclusive audio focus -> κάνει pause τα υπόλοιπα
    // ηχητικά της συσκευής, όπως ακριβώς μια πραγματική κλήση.
    _ringtoneChannel.invokeMethod('play');
    _vibrateLoop();
  }

  Future<void> _vibrateLoop() async {
    while (mounted && !_answered && !_ended) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  /// Αν δεν απαντηθεί μέσα στο χρονικό όριο, η κλήση σταματάει μόνη
  /// της — σαν χαμένη κλήση σε πραγματικό τηλέφωνο.
  void _missedCall() {
    if (_answered || _ended || !mounted) return;
    _decline();
  }

  void _decline() {
    _ringTimeoutTimer?.cancel();
    _ended = true;
    // "release": σταματά τον ήχο ΚΑΙ αφήνει το audio focus — τα άλλα
    // ηχητικά της συσκευής μπορούν να συνεχίσουν κανονικά.
    _ringtoneChannel.invokeMethod('release');
    if (mounted) Navigator.of(context).pop();
  }

  void _answer() {
    _ringTimeoutTimer?.cancel();
    // "muteRingtone": σταματά μόνο τον ήχο κλήσης, ΚΡΑΤΑΕΙ όμως το
    // audio focus — τα άλλα ηχητικά παραμένουν σε παύση όσο διαρκεί η
    // (ψεύτικη) κλήση, ίδια συμπεριφορά με πραγματική κλήση.
    _ringtoneChannel.invokeMethod('muteRingtone');
    _pulseController.stop();
    setState(() {
      _answered = true;
      _callDuration = Duration.zero;
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  String get _formattedDuration {
    final m = _callDuration.inMinutes.toString().padLeft(2, '0');
    final sec = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101513),
        body: Stack(
          children: [
            // Animated background με απαλά, κινούμενα σχήματα — στυλ
            // παρόμοιο με τα Material/Pixel animated wallpapers, δίνει
            // ζωντάνια στην οθόνη αντί για επίπεδο μαύρο φόντο.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) =>
                    CustomPaint(painter: _ShapesPainter(_bgController.value)),
              ),
            ),
            SafeArea(
              child: AnimatedOpacity(
                opacity: _contentVisible ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      _answered ? _formattedDuration : s.incomingCall,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 40),
                    _AvatarWithPulse(
                      animation: _pulseController,
                      ringing: !_answered,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.callerNumber,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                    const Spacer(),
                    if (_answered) ...[
                      _InCallOptionsGrid(
                        muted: _muted,
                        onHold: _onHold,
                        speaker: _speaker,
                        showKeypad: _showKeypad,
                        onToggleMute: () => setState(() => _muted = !_muted),
                        onToggleHold: () =>
                            setState(() => _onHold = !_onHold),
                        onToggleSpeaker: () =>
                            setState(() => _speaker = !_speaker),
                        onToggleKeypad: () =>
                            setState(() => _showKeypad = !_showKeypad),
                      ),
                      if (_showKeypad) const _FakeKeypad(),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallActionButton(
                          icon: Icons.call_end,
                          color: _FakeCallColors.decline,
                          label: _answered ? s.endCall : s.decline,
                          onTap: _decline,
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _answered
                              ? const SizedBox(
                                  width: 72, key: ValueKey('empty'))
                              : _CallActionButton(
                                  key: const ValueKey('answer'),
                                  icon: Icons.call,
                                  color: _FakeCallColors.answer,
                                  label: s.answer,
                                  onTap: _answer,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ζωγραφίζει 4 απαλά, ημιδιάφανα σχήματα (κύκλοι/blobs) που κινούνται
/// αργά σε ελλειπτικές τροχιές — καθαρά διακοσμητικό animated
/// background, στυλ παρόμοιο με τα Material "shape" animations.
class _ShapesPainter extends CustomPainter {
  final double t; // 0..1, επαναλαμβανόμενο
  _ShapesPainter(this.t);

  static const _colors = [
    Color(0xFF0B6E4F),
    Color(0xFF1565C0),
    Color(0xFF5C4D9B),
    Color(0xFFD64550),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _colors.length; i++) {
      final phase = t * 2 * math.pi + (i * 1.5);
      final cx = size.width * 0.5 +
          size.width * 0.55 * math.cos(phase + i) * (i.isEven ? 1 : -1);
      final cy = size.height * 0.4 + size.height * 0.45 * math.sin(phase * 0.8 + i);
      final radius = size.shortestSide * (0.42 + 0.12 * math.sin(phase));

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _colors[i].withValues(alpha: 0.55),
            _colors[i].withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapesPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _AvatarWithPulse extends StatelessWidget {
  final Animation<double> animation;
  final bool ringing;
  const _AvatarWithPulse({required this.animation, required this.ringing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (ringing) ..._buildRings(animation.value),
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 64, color: Colors.white70),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildRings(double t) {
    return [0.0, 0.5].map((offset) {
      final phase = (t + offset) % 1.0;
      final scale = 1.0 + phase * 0.7;
      final opacity = (1.0 - phase).clamp(0.0, 1.0);
      return Opacity(
        opacity: opacity * 0.5,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _InCallOptionsGrid extends StatelessWidget {
  final bool muted;
  final bool onHold;
  final bool speaker;
  final bool showKeypad;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleHold;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleKeypad;

  const _InCallOptionsGrid({
    required this.muted,
    required this.onHold,
    required this.speaker,
    required this.showKeypad,
    required this.onToggleMute,
    required this.onToggleHold,
    required this.onToggleSpeaker,
    required this.onToggleKeypad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _OptionButton(
            icon: Icons.dialpad,
            label: 'Πληκτρολόγηση',
            active: showKeypad,
            onTap: onToggleKeypad,
          ),
          _OptionButton(
            icon: muted ? Icons.mic_off : Icons.mic,
            label: 'Σίγαση',
            active: muted,
            onTap: onToggleMute,
          ),
          _OptionButton(
            icon: speaker ? Icons.volume_up : Icons.volume_down,
            label: 'Ηχείο',
            active: speaker,
            onTap: onToggleSpeaker,
          ),
          _OptionButton(
            icon: Icons.pause_circle_outline,
            label: 'Αναμονή',
            active: onHold,
            onTap: onToggleHold,
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E7D32) : Colors.white12,
            shape: BoxShape.circle,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _FakeKeypad extends StatelessWidget {
  const _FakeKeypad();

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: keys
            .map((k) => Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      k,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _FakeCallColors {
  _FakeCallColors._();
  static const answer = Color(0xFF2E7D32);
  static const decline = Color(0xFFD64550);
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
