import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taerae/taerae.dart';

import '../taerae_graph_controller.dart';

/// Computes node positions for [TaeraeGraphView].
///
/// The returned map must use node ids as keys and canvas offsets as values.
typedef TaeraeGraphLayout =
    Map<String, Offset> Function(
      Size canvasSize,
      List<TaeraeNode> nodes,
      List<TaeraeEdge> edges,
      EdgeInsets padding,
      double nodeRadius,
    );

/// Callback for taps on a node rendered by [TaeraeGraphView].
typedef TaeraeGraphNodeTapCallback = void Function(TaeraeNode node);

/// Callback for taps on an edge rendered by [TaeraeGraphView].
typedef TaeraeGraphEdgeTapCallback = void Function(TaeraeEdge edge);

/// Interactive widget that renders a [TaeraeGraphController] as a graph canvas.
///
/// The view listens to [controller] changes and recomputes node placement
/// whenever the graph mutates.
class TaeraeGraphView extends StatelessWidget {
  /// Creates a graph visualization widget.
  const TaeraeGraphView({
    required this.controller,
    this.layout,
    this.onNodeTap,
    this.onEdgeTap,
    this.nodeRadius = 28,
    this.padding = const EdgeInsets.all(24),
    this.backgroundColor = const Color(0xFFF5FAFA),
    this.nodeColor = const Color(0xFF00796B),
    this.edgeColor = const Color(0xFF607D8B),
    this.nodeTextStyle,
    this.edgeTextStyle,
    this.minScale = 0.6,
    this.maxScale = 2.6,
    this.interactive = true,
    this.emptyPlaceholder = 'No nodes to display.',
    super.key,
  }) : assert(nodeRadius > 0),
       assert(minScale > 0),
       assert(maxScale >= minScale);

  /// Graph state source used for rendering and updates.
  final TaeraeGraphController controller;

  /// Node layout function.
  ///
  /// When omitted, the view uses a deterministic circular layout.
  final TaeraeGraphLayout? layout;

  /// Called when a node is tapped.
  final TaeraeGraphNodeTapCallback? onNodeTap;

  /// Called when an edge is tapped.
  final TaeraeGraphEdgeTapCallback? onEdgeTap;

  /// Radius of each rendered node.
  final double nodeRadius;

  /// Padding reserved between nodes and the canvas boundary.
  final EdgeInsets padding;

  /// Background color for the graph canvas.
  final Color backgroundColor;

  /// Fill color for rendered nodes.
  final Color nodeColor;

  /// Stroke color for rendered edges.
  final Color edgeColor;

  /// Text style for node labels.
  final TextStyle? nodeTextStyle;

  /// Text style for edge labels.
  final TextStyle? edgeTextStyle;

  /// Minimum zoom scale when [interactive] is `true`.
  final double minScale;

  /// Maximum zoom scale when [interactive] is `true`.
  final double maxScale;

  /// Whether pan/zoom interactions are enabled through [InteractiveViewer].
  final bool interactive;

  /// Message shown when the graph has no nodes.
  final String emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<TaeraeNode> nodes = controller.nodes;
        final List<TaeraeEdge> edges = controller.edges;
        final TextStyle resolvedNodeTextStyle =
            nodeTextStyle ??
            Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ) ??
            const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            );
        final TextStyle resolvedEdgeTextStyle =
            edgeTextStyle ??
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF37474F),
              fontWeight: FontWeight.w500,
            ) ??
            const TextStyle(
              color: Color(0xFF37474F),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            );

        if (nodes.isEmpty) {
          return ColoredBox(
            color: backgroundColor,
            child: Center(child: Text(emptyPlaceholder)),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size canvasSize = Size(
              _finiteExtent(constraints.maxWidth, fallback: 480),
              _finiteExtent(constraints.maxHeight, fallback: 320),
            );
            final Map<String, Offset> positions = _resolvePositions(
              layout: layout,
              canvasSize: canvasSize,
              nodes: nodes,
              edges: edges,
              padding: padding,
              nodeRadius: nodeRadius,
            );

            final Widget scene = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) {
                _handleTap(details.localPosition, nodes, edges, positions);
              },
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: _TaeraeGraphEdgePainter(
                      edges: edges,
                      positions: positions,
                      nodeRadius: nodeRadius,
                      edgeColor: edgeColor,
                      textStyle: resolvedEdgeTextStyle,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                  for (final TaeraeNode node in nodes)
                    _buildNode(
                      node,
                      positions[node.id]!,
                      resolvedNodeTextStyle,
                    ),
                ],
              ),
            );

            final Widget content = SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: scene,
            );
            return ClipRect(
              child: ColoredBox(
                color: backgroundColor,
                child: interactive
                    ? InteractiveViewer(
                        minScale: minScale,
                        maxScale: maxScale,
                        boundaryMargin: const EdgeInsets.all(120),
                        child: content,
                      )
                    : content,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNode(TaeraeNode node, Offset center, TextStyle textStyle) {
    return Positioned(
      left: center.dx - nodeRadius,
      top: center.dy - nodeRadius,
      width: nodeRadius * 2,
      height: nodeRadius * 2,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nodeColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Center(
              child: Text(
                node.id,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(
    Offset position,
    List<TaeraeNode> nodes,
    List<TaeraeEdge> edges,
    Map<String, Offset> positions,
  ) {
    final TaeraeNode? hitNode = _hitNode(
      position,
      nodes,
      positions,
      nodeRadius,
    );
    if (hitNode != null) {
      onNodeTap?.call(hitNode);
      return;
    }

    final TaeraeEdge? hitEdge = _hitEdge(
      position,
      edges,
      positions,
      nodeRadius,
    );
    if (hitEdge != null) {
      onEdgeTap?.call(hitEdge);
    }
  }
}

Map<String, Offset> _resolvePositions({
  required TaeraeGraphLayout? layout,
  required Size canvasSize,
  required List<TaeraeNode> nodes,
  required List<TaeraeEdge> edges,
  required EdgeInsets padding,
  required double nodeRadius,
}) {
  final TaeraeGraphLayout resolvedLayout = layout ?? _defaultCircularLayout;
  final Map<String, Offset> positioned = Map<String, Offset>.from(
    resolvedLayout(canvasSize, nodes, edges, padding, nodeRadius),
  );
  final Map<String, Offset> fallback = _defaultCircularLayout(
    canvasSize,
    nodes,
    edges,
    padding,
    nodeRadius,
  );

  for (final TaeraeNode node in nodes) {
    positioned.putIfAbsent(node.id, () => fallback[node.id]!);
  }
  return positioned;
}

Map<String, Offset> _defaultCircularLayout(
  Size canvasSize,
  List<TaeraeNode> nodes,
  List<TaeraeEdge> _,
  EdgeInsets padding,
  double nodeRadius,
) {
  if (nodes.isEmpty) {
    return const <String, Offset>{};
  }

  final double left = padding.left + nodeRadius;
  final double top = padding.top + nodeRadius;
  final double right = canvasSize.width - padding.right - nodeRadius;
  final double bottom = canvasSize.height - padding.bottom - nodeRadius;

  if (right <= left || bottom <= top) {
    final Offset center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    return <String, Offset>{
      for (final TaeraeNode node in nodes) node.id: center,
    };
  }

  final double width = right - left;
  final double height = bottom - top;
  final Offset center = Offset(left + width / 2, top + height / 2);

  if (nodes.length == 1) {
    return <String, Offset>{nodes.single.id: center};
  }

  final double radius = math.max(8, math.min(width, height) / 2);
  final Map<String, Offset> positions = <String, Offset>{};
  for (int index = 0; index < nodes.length; index++) {
    final double angle =
        (-math.pi / 2) + ((2 * math.pi * index) / nodes.length);
    positions[nodes[index].id] = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }
  return positions;
}

double _finiteExtent(double candidate, {required double fallback}) {
  if (!candidate.isFinite || candidate <= 0) {
    return fallback;
  }
  return candidate;
}

TaeraeNode? _hitNode(
  Offset position,
  List<TaeraeNode> nodes,
  Map<String, Offset> positions,
  double nodeRadius,
) {
  for (final TaeraeNode node in nodes.reversed) {
    final Offset? center = positions[node.id];
    if (center == null) {
      continue;
    }
    if ((position - center).distance <= nodeRadius) {
      return node;
    }
  }
  return null;
}

TaeraeEdge? _hitEdge(
  Offset position,
  List<TaeraeEdge> edges,
  Map<String, Offset> positions,
  double nodeRadius,
) {
  final double tolerance = math.max(8, nodeRadius * 0.45);
  for (final TaeraeEdge edge in edges.reversed) {
    final Offset? from = positions[edge.from];
    final Offset? to = positions[edge.to];
    if (from == null || to == null) {
      continue;
    }

    final _Segment segment = _edgeSegment(from, to, nodeRadius);
    final double distance = _distanceToSegment(
      position,
      segment.start,
      segment.end,
    );
    if (distance <= tolerance) {
      return edge;
    }
  }
  return null;
}

_Segment _edgeSegment(Offset from, Offset to, double nodeRadius) {
  final Offset delta = to - from;
  final double distance = delta.distance;
  if (distance <= nodeRadius * 2) {
    return _Segment(start: from, end: to);
  }
  final Offset direction = delta / distance;
  return _Segment(
    start: from + direction * nodeRadius,
    end: to - direction * nodeRadius,
  );
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final Offset segment = end - start;
  final double lengthSquared =
      segment.dx * segment.dx + segment.dy * segment.dy;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final Offset toPoint = point - start;
  final double t =
      ((toPoint.dx * segment.dx) + (toPoint.dy * segment.dy)) / lengthSquared;
  final double clamped = t.clamp(0.0, 1.0);
  final Offset projection = Offset(
    start.dx + segment.dx * clamped,
    start.dy + segment.dy * clamped,
  );
  return (point - projection).distance;
}

final class _Segment {
  const _Segment({required this.start, required this.end});

  final Offset start;
  final Offset end;
}

class _TaeraeGraphEdgePainter extends CustomPainter {
  const _TaeraeGraphEdgePainter({
    required this.edges,
    required this.positions,
    required this.nodeRadius,
    required this.edgeColor,
    required this.textStyle,
    required this.textDirection,
  });

  final List<TaeraeEdge> edges;
  final Map<String, Offset> positions;
  final double nodeRadius;
  final Color edgeColor;
  final TextStyle textStyle;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint arrowPaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.fill;
    final TextPainter textPainter = TextPainter(
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    );

    for (final TaeraeEdge edge in edges) {
      final Offset? from = positions[edge.from];
      final Offset? to = positions[edge.to];
      if (from == null || to == null) {
        continue;
      }

      final _Segment segment = _edgeSegment(from, to, nodeRadius);
      canvas.drawLine(segment.start, segment.end, edgePaint);
      _drawArrowHead(canvas, segment, arrowPaint);

      final String label = edge.type ?? edge.id;
      if (label.isNotEmpty) {
        _paintEdgeLabel(textPainter, canvas, segment, label);
      }
    }
  }

  void _drawArrowHead(Canvas canvas, _Segment segment, Paint paint) {
    final Offset delta = segment.end - segment.start;
    final double distance = delta.distance;
    if (distance <= 0) {
      return;
    }
    final Offset direction = delta / distance;
    final Offset orthogonal = Offset(-direction.dy, direction.dx);
    const double arrowLength = 12;
    const double arrowHalfWidth = 5;

    final Offset tip = segment.end;
    final Offset baseCenter = tip - direction * arrowLength;
    final Path path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        baseCenter.dx + orthogonal.dx * arrowHalfWidth,
        baseCenter.dy + orthogonal.dy * arrowHalfWidth,
      )
      ..lineTo(
        baseCenter.dx - orthogonal.dx * arrowHalfWidth,
        baseCenter.dy - orthogonal.dy * arrowHalfWidth,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintEdgeLabel(
    TextPainter textPainter,
    Canvas canvas,
    _Segment segment,
    String label,
  ) {
    textPainter.text = TextSpan(text: label, style: textStyle);
    textPainter.layout(maxWidth: 120);

    final Offset midpoint = Offset(
      (segment.start.dx + segment.end.dx) / 2,
      (segment.start.dy + segment.end.dy) / 2,
    );
    final Offset delta = segment.end - segment.start;
    final double distance = delta.distance;
    Offset normal = const Offset(0, -1);
    if (distance > 0) {
      normal = Offset(-delta.dy / distance, delta.dx / distance);
    }

    final Offset labelCenter = midpoint + normal * 12;
    final Offset topLeft = Offset(
      labelCenter.dx - textPainter.width / 2,
      labelCenter.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(covariant _TaeraeGraphEdgePainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.positions != positions ||
        oldDelegate.nodeRadius != nodeRadius ||
        oldDelegate.edgeColor != edgeColor ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.textDirection != textDirection;
  }
}
