import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_strings.dart';

const _ringtoneChannel = MethodChannel('gr.fandcs.callen/ringtone');



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
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final AnimationController _bgController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 240),
  )..repeat();

  bool _contentVisible = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
    _ringTimeoutTimer = Timer(_ringTimeout, _missedCall);
    
    
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
    
    
    _ringtoneChannel.invokeMethod('play');
    _vibrateLoop();
  }

  Future<void> _vibrateLoop() async {
    while (mounted && !_answered && !_ended) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  
  
  void _missedCall() {
    if (_answered || _ended || !mounted) return;
    _decline();
  }

  void _decline() {
    _ringTimeoutTimer?.cancel();
    _ended = true;
    
    
    _ringtoneChannel.invokeMethod('release');
    if (mounted) Navigator.of(context).pop();
  }

  void _answer() {
    _ringTimeoutTimer?.cancel();
    
    
    
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
            
            
            
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) =>
                    CustomPaint(painter: _ShapesPainter(_bgController.value)),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF101513).withValues(alpha: 0.55),
                    ],
                  ),
                ),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                      ),
                    ),
                    if (!_showKeypad) ...[
                      const SizedBox(height: 36),
                      _AvatarWithPulse(
                        animation: _pulseController,
                        ringing: !_answered,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.callerNumber,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_answered) ...[
                      if (_showKeypad) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.keyboard_hide,
                                color: Colors.white70),
                            tooltip: s.hideKeypad,
                            onPressed: () =>
                                setState(() => _showKeypad = false),
                          ),
                        ),
                        const _FakeKeypad(),
                      ] else
                        _InCallOptionsGrid(
                          strings: s,
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
                              setState(() => _showKeypad = true),
                        ),
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




class _ShapesPainter extends CustomPainter {
  final double t; 
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
      final phase = t * 2 * math.pi * 40 + (i * 1.5);
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
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final glowScale = ringing ? 1.0 + animation.value * 0.18 : 1.0;
          final glowOpacity = ringing ? 0.25 + animation.value * 0.25 : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: glowOpacity),
                  ),
                ),
              ),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF5C4D9B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: const CircleAvatar(
                  radius: 62,
                  backgroundColor: Color(0xFF1B221E),
                  child: Icon(Icons.person, size: 68, color: Colors.white70),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InCallOptionsGrid extends StatelessWidget {
  final AppStrings strings;
  final bool muted;
  final bool onHold;
  final bool speaker;
  final bool showKeypad;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleHold;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleKeypad;

  const _InCallOptionsGrid({
    required this.strings,
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
            label: strings.keypadLabel,
            active: showKeypad,
            onTap: onToggleKeypad,
          ),
          _OptionButton(
            icon: muted ? Icons.mic_off : Icons.mic,
            label: strings.muteLabel,
            active: muted,
            onTap: onToggleMute,
          ),
          _OptionButton(
            icon: speaker ? Icons.volume_up : Icons.volume_down,
            label: strings.speakerLabel,
            active: speaker,
            onTap: onToggleSpeaker,
          ),
          _OptionButton(
            icon: Icons.pause_circle_outline,
            label: strings.holdLabel,
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

class _FakeKeypad extends StatefulWidget {
  const _FakeKeypad();

  @override
  State<_FakeKeypad> createState() => _FakeKeypadState();
}

class _FakeKeypadState extends State<_FakeKeypad> {
  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['*', '0', '#'],
  ];

  final _digits = StringBuffer();

  void _tap(String k) {
    HapticFeedback.selectionClick();
    setState(() => _digits.write(k));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              _digits.toString(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((k) => Material(
                          color: Colors.white12,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _tap(k),
                            child: SizedBox(
                              width: 52,
                              height: 52,
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
                            ),
                          ),
                        ))
                    .toList(),
              ),
            )),
      ],
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
