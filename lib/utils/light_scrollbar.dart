import 'dart:async';

import 'package:flutter/material.dart';

/// Lightweight replacement for [Scrollbar] / [RawScrollbar].
///
/// - No setState / no widget rebuild while scrolling: the thumb is drawn by a
///   [CustomPainter] that repaints itself from the [ScrollController].
/// - The list is isolated in its own [RepaintBoundary], so moving the thumb
///   never repaints the list rows (and vice-versa).
/// - Works the same on every device / refresh rate.
/// - Draggable thumb (touch strip on the right edge).
///
/// Usage:
/// ```dart
/// final _controller = ScrollController();
///
/// LightScrollbar(
///   controller: _controller,
///   child: ListView.builder(
///     controller: _controller,
///     itemExtent: 72, // if rows have a fixed height -> much cheaper layout
///     itemCount: items.length,
///     itemBuilder: (_, i) => ...,
///   ),
/// )
/// ```
class LightScrollbar extends StatefulWidget {
  const LightScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.color,
    this.thickness = 4,
    this.minThumbExtent = 40,
    this.touchWidth = 24,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.hideDelay = const Duration(milliseconds: 900),
  });

  final ScrollController controller;
  final Widget child;
  final Color? color;
  final double thickness;
  final double minThumbExtent;
  final double touchWidth;
  final EdgeInsets padding;
  final Duration hideDelay;

  @override
  State<LightScrollbar> createState() => _LightScrollbarState();
}

class _LightScrollbarState extends State<LightScrollbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _hideTimer;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(LightScrollbar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_fade.value != 1.0) _fade.value = 1.0;
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_dragging) return;
    _hideTimer = Timer(widget.hideDelay, () {
      if (mounted && !_dragging) _fade.reverse();
    });
  }

  void _dragTo(double localDy, double trackHeight) {
    final c = widget.controller;
    if (!c.hasClients) return;
    final pos = c.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) return;
    final thumb = _thumbExtent(pos, trackHeight, widget.minThumbExtent);
    final usable = trackHeight - thumb;
    if (usable <= 0) return;
    final fraction = ((localDy - widget.padding.top - thumb / 2) / usable)
        .clamp(0.0, 1.0);
    c.jumpTo(fraction * pos.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Stack(
      children: [
        RepaintBoundary(child: widget.child),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: widget.touchWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final track = constraints.maxHeight - widget.padding.vertical;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (d) {
                  _dragging = true;
                  _hideTimer?.cancel();
                  _fade.value = 1.0;
                  _dragTo(d.localPosition.dy, track);
                },
                onVerticalDragUpdate: (d) =>
                    _dragTo(d.localPosition.dy, track),
                onVerticalDragEnd: (_) {
                  _dragging = false;
                  _scheduleHide();
                },
                onVerticalDragCancel: () {
                  _dragging = false;
                  _scheduleHide();
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ThumbPainter(
                      controller: widget.controller,
                      fade: _fade,
                      color: color,
                      thickness: widget.thickness,
                      minThumbExtent: widget.minThumbExtent,
                      padding: widget.padding,
                    ),
                    size: Size.infinite,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

double _thumbExtent(ScrollPosition pos, double track, double minThumb) {
  final total = pos.viewportDimension + pos.maxScrollExtent;
  if (total <= 0) return track;
  return (pos.viewportDimension / total * track).clamp(minThumb, track);
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter({
    required this.controller,
    required this.fade,
    required this.color,
    required this.thickness,
    required this.minThumbExtent,
    required this.padding,
  }) : super(repaint: Listenable.merge([controller, fade]));

  final ScrollController controller;
  final Animation<double> fade;
  final Color color;
  final double thickness;
  final double minThumbExtent;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade.value <= 0 || !controller.hasClients) return;
    if (controller.positions.length != 1) return;
    final pos = controller.position;
    if (!pos.hasContentDimensions) return;
    final max = pos.maxScrollExtent;
    if (max <= 0) return;

    final track = size.height - padding.vertical;
    if (track <= 0) return;
    final thumb = _thumbExtent(pos, track, minThumbExtent);
    final top = padding.top +
        (pos.pixels / max).clamp(0.0, 1.0) * (track - thumb);

    final paint = Paint()
      ..color = color.withValues(alpha: color.a * fade.value);
    final rect = Rect.fromLTWH(
      size.width - thickness - 4,
      top,
      thickness,
      thumb,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(thickness / 2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.color != color ||
      old.thickness != thickness ||
      old.minThumbExtent != minThumbExtent ||
      old.padding != padding ||
      old.controller != controller;
}
