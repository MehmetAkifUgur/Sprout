import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/constants/growth_constants.dart';
import '../../core/constants/plant_types.dart';
import '../../core/theme/app_theme.dart';

/// Puana göre büyüyen, ihmalde solan bitki.
///
/// Puan ve solma değerleri animasyonla geçiş yapar; evre değiştiğinde ayrıca
/// kısa bir "zıplama" animasyonu oynatılır.
class PlantWidget extends StatefulWidget {
  const PlantWidget({
    super.key,
    required this.score,
    required this.type,
    this.isWilted = false,
    this.size = 120,
  });

  final double score;
  final PlantType type;
  final bool isWilted;
  final double size;

  @override
  State<PlantWidget> createState() => _PlantWidgetState();
}

class _PlantWidgetState extends State<PlantWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  @override
  void didUpdateWidget(PlantWidget old) {
    super.didUpdateWidget(old);
    if (GrowthStage.fromScore(old.score) !=
        GrowthStage.fromScore(widget.score)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${widget.type.label}, ${GrowthStage.fromScore(widget.score).label}'
          '${widget.isWilted ? ', solmuş' : ''}',
      child: SizedBox.square(
        dimension: widget.size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.isWilted ? 1 : 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, wilt, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: widget.score),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, score, _) => AnimatedBuilder(
              animation: _pop,
              builder: (context, _) {
                final t = Curves.elasticOut.transform(_pop.value);
                return Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scaleY: lerpDouble(0.85, 1, t),
                  scaleX: lerpDouble(1.1, 1, t),
                  child: CustomPaint(
                    painter: PlantPainter(
                      score: score.clamp(0, 100),
                      wilt: wilt.clamp(0, 1),
                      type: widget.type,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class PlantPainter extends CustomPainter {
  PlantPainter({required this.score, required this.wilt, required this.type});

  final double score;
  final double wilt;
  final PlantType type;

  Color _tint(Color c) => Color.lerp(c, AppColors.wilted, wilt * 0.85)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final potH = h * 0.24;
    final groundY = h - potH;

    _paintPot(canvas, w, h, cx, groundY);
    _paintPlant(canvas, size, Offset(cx, groundY));
  }

  void _paintPot(Canvas canvas, double w, double h, double cx, double groundY) {
    final topW = w * 0.46;
    final bottomW = w * 0.34;
    final body = Path()
      ..moveTo(cx - topW / 2, groundY + h * 0.03)
      ..lineTo(cx + topW / 2, groundY + h * 0.03)
      ..lineTo(cx + bottomW / 2, h)
      ..lineTo(cx - bottomW / 2, h)
      ..close();
    canvas.drawPath(body, Paint()..color = AppColors.pot);
    final rim = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, groundY + h * 0.02),
        width: topW + w * 0.06,
        height: h * 0.07,
      ),
      Radius.circular(h * 0.02),
    );
    canvas.drawRRect(rim, Paint()..color = AppColors.potRim);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY - h * 0.005),
        width: topW,
        height: h * 0.035,
      ),
      Paint()..color = AppColors.soil,
    );
  }

  void _paintPlant(Canvas canvas, Size size, Offset base) {
    final w = size.width;
    final h = size.height;
    final s = score / 100;

    if (score <= GrowthStage.seed.maxScore) {
      _paintSeedling(canvas, w, h, base);
      return;
    }

    if (type == PlantType.cactus) {
      _paintCactus(canvas, w, h, base, s);
      return;
    }

    final stemH = lerpDouble(h * 0.14, h * 0.62, s)!;
    final droop = wilt * w * 0.22;
    final top = Offset(base.dx + droop, base.dy - stemH * (1 - wilt * 0.2));
    final control = Offset(base.dx - droop * 0.2, base.dy - stemH * 0.7);
    Offset along(double t) => _quad(base, control, top, t);

    final isTree = type == PlantType.tree;
    final stemPaint = Paint()
      ..color = _tint(isTree && score > 45 ? AppColors.bark : AppColors.stem)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = lerpDouble(w * 0.02, isTree ? w * 0.06 : w * 0.03, s)!;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(control.dx, control.dy, top.dx, top.dy),
      stemPaint,
    );

    // Yapraklar
    final leafCount = switch (GrowthStage.fromScore(score)) {
      GrowthStage.seed => 0,
      GrowthStage.sprout => 2,
      GrowthStage.sapling => 4,
      GrowthStage.blooming => 6,
      GrowthStage.grown => 8,
    };
    final leafLen = lerpDouble(w * 0.1, w * 0.17, s)!;
    for (var i = 0; i < leafCount; i++) {
      final t = leafCount == 2 ? 0.95 : 0.3 + 0.62 * (i / (leafCount - 1));
      final side = i.isEven ? -1.0 : 1.0;
      final angle = side * (math.pi / 4) + wilt * side * 0.9;
      _paintLeaf(canvas, along(t), angle, leafLen * (0.75 + 0.25 * t));
    }

    if (isTree) {
      if (score > GrowthStage.sprout.maxScore) {
        _paintCanopy(canvas, w, top, s);
      }
      return;
    }

    if (score > GrowthStage.sapling.maxScore) {
      final bloom = ((score - 70) / 30).clamp(0.0, 1.0);
      _paintFlower(canvas, w, top, bloom);
    }
  }

  void _paintSeedling(Canvas canvas, double w, double h, Offset base) {
    final p = (score / GrowthStage.seed.maxScore).clamp(0.0, 1.0);
    final seedPaint = Paint()..color = _tint(const Color(0xFF8D6E63));
    canvas.save();
    canvas.translate(base.dx - w * 0.03, base.dy - h * 0.01);
    canvas.rotate(-0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.09, height: w * 0.06),
      seedPaint,
    );
    canvas.restore();
    if (p <= 0) return;
    final shootH = h * 0.12 * p;
    final top = Offset(base.dx, base.dy - h * 0.02 - shootH);
    canvas.drawLine(
      Offset(base.dx, base.dy - h * 0.03),
      top,
      Paint()
        ..color = _tint(AppColors.stem)
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round,
    );
    final leafLen = w * 0.07 * p;
    _paintLeaf(canvas, top, -math.pi / 3 - wilt * 0.8, leafLen);
    _paintLeaf(canvas, top, math.pi / 3 + wilt * 0.8, leafLen);
  }

  void _paintLeaf(Canvas canvas, Offset at, double angle, double len) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.35, -len * 0.5, 0, -len)
      ..quadraticBezierTo(-len * 0.35, -len * 0.5, 0, 0);
    canvas.drawPath(leaf, Paint()..color = _tint(AppColors.leaf));
    canvas.drawLine(
      Offset.zero,
      Offset(0, -len * 0.8),
      Paint()
        ..color = _tint(AppColors.leafDark)
        ..strokeWidth = len * 0.05,
    );
    canvas.restore();
  }

  void _paintFlower(Canvas canvas, double w, Offset c, double bloom) {
    final sunflower = type == PlantType.sunflower;
    final petals = sunflower ? 14 : 6;
    final r = lerpDouble(w * 0.04, sunflower ? w * 0.16 : w * 0.12, bloom)!;
    final petalPaint = Paint()..color = _tint(type.accent);
    for (var i = 0; i < petals; i++) {
      final a = i * 2 * math.pi / petals;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a + wilt * 0.4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -r * 0.6),
          width: r * (sunflower ? 0.35 : 0.7),
          height: r * (0.9 - wilt * 0.3),
        ),
        petalPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      c,
      r * (sunflower ? 0.45 : 0.3),
      Paint()
        ..color = _tint(
          sunflower ? const Color(0xFF6D4C41) : const Color(0xFFFFD54F),
        ),
    );
  }

  void _paintCanopy(Canvas canvas, double w, Offset top, double s) {
    final r = lerpDouble(w * 0.08, w * 0.26, s)!;
    final canopy = Paint()..color = _tint(AppColors.leafDark);
    final light = Paint()..color = _tint(AppColors.leaf);
    final c = top.translate(0, -r * 0.35 + wilt * r * 0.3);
    canvas.drawCircle(c.translate(-r * 0.55, r * 0.2), r * 0.7, canopy);
    canvas.drawCircle(c.translate(r * 0.55, r * 0.2), r * 0.7, canopy);
    canvas.drawCircle(c.translate(0, -r * 0.25), r * 0.8, light);
    if (score > GrowthStage.sapling.maxScore && wilt < 0.5) {
      final fruitR = w * 0.022 * ((score - 70) / 30).clamp(0.4, 1.0);
      final fruit = Paint()..color = type.accent;
      for (final o in const [
        Offset(-0.5, 0.1),
        Offset(0.45, 0.25),
        Offset(0.05, -0.45),
        Offset(-0.15, 0.45),
        Offset(0.6, -0.2),
      ]) {
        canvas.drawCircle(c.translate(o.dx * r, o.dy * r), fruitR, fruit);
      }
    }
  }

  void _paintCactus(Canvas canvas, double w, double h, Offset base, double s) {
    final bodyH = lerpDouble(h * 0.14, h * 0.52, s)!;
    final bodyW = lerpDouble(w * 0.1, w * 0.18, s)!;
    final lean = wilt * 0.25;
    final paint = Paint()..color = _tint(AppColors.leaf);
    final dark = Paint()
      ..color = _tint(AppColors.leafDark)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(lean);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(-bodyW / 2, -bodyH, bodyW, bodyH),
      Radius.circular(bodyW / 2),
    );
    canvas.drawRRect(body, paint);
    canvas.drawLine(
      Offset(0, -bodyH + bodyW * 0.4),
      Offset(0, -bodyW * 0.2),
      dark,
    );

    if (score > GrowthStage.sprout.maxScore) {
      final armP = ((score - 45) / 25).clamp(0.0, 1.0);
      for (final side in const [-1.0, 1.0]) {
        final armH = bodyH * 0.35 * armP * (side < 0 ? 1 : 0.8);
        final armW = bodyW * 0.55;
        final x = side * (bodyW / 2 + armW * 0.6);
        final y = -bodyH * (side < 0 ? 0.45 : 0.6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - armW / 2, y - armH, armW, armH + armW * 0.5),
            Radius.circular(armW / 2),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              side < 0 ? x - armW / 2 : -bodyW / 2,
              y,
              bodyW / 2 + armW * 1.1,
              armW * 0.5,
            ),
            Radius.circular(armW / 4),
          ),
          paint,
        );
      }
    }

    if (score > GrowthStage.sapling.maxScore) {
      final bloom = ((score - 70) / 30).clamp(0.0, 1.0);
      canvas.rotate(-lean);
      _paintFlower(canvas, w * 0.6, Offset(0, -bodyH), bloom);
    }
    canvas.restore();
  }

  static Offset _quad(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + c * (t * t);
  }

  @override
  bool shouldRepaint(PlantPainter old) =>
      old.score != score || old.wilt != wilt || old.type != type;
}
