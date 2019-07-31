library matrix_gesture_detector;

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

typedef MatrixGestureDetectorCallback = void Function(Matrix4 matrix);

/// [MatrixGestureDetector] detects translation, scale and rotation gestures
/// and combines them into [Matrix4] object that can be used by [Transform] widget
/// or by low level [CustomPainter] code. You can customize types of reported
/// gestures by passing [shouldTranslate], [shouldScale] and [shouldRotate]
/// parameters.
///
class MatrixGestureDetector extends StatefulWidget {
  /// [Matrix4] change notification callback
  ///
  final MatrixGestureDetectorCallback onMatrixUpdate;

  /// The [child] contained by this detector.
  ///
  /// {@macro flutter.widgets.child}
  ///
  final Widget child;

  /// Whether to detect translation gestures during the event processing.
  ///
  /// Defaults to true.
  ///
  final bool shouldTranslate;

  /// Whether to detect scale gestures during the event processing.
  ///
  /// Defaults to true.
  ///
  final bool shouldScale;

  /// Whether to detect rotation gestures during the event processing.
  ///
  /// Defaults to true.
  ///
  final bool shouldRotate;

  /// Whether [ClipRect] widget should clip [child] widget.
  ///
  /// Defaults to true.
  ///
  final bool clipChild;

  /// When set, it will be used for computing a "fixed" focal point
  /// aligned relative to the size of this widget.
  final Alignment focalPointAlignment;

  final Size size;

  final bool alwaysShownInView;

  const MatrixGestureDetector({
    Key key,
    @required this.onMatrixUpdate,
    @required this.child,
    @required this.size,
    this.shouldTranslate = true,
    this.shouldScale = true,
    this.shouldRotate = true,
    this.clipChild = true,
    this.alwaysShownInView = true,
    this.focalPointAlignment,
  })  : assert(onMatrixUpdate != null),
        assert(child != null),
        super(key: key);

  @override
  _MatrixGestureDetectorState createState() => _MatrixGestureDetectorState();
}

class _MatrixGestureDetectorState extends State<MatrixGestureDetector> with SingleTickerProviderStateMixin {
  Matrix4 matrix = Matrix4.identity();
  AnimationController controller;
  Animation<Offset> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child =
        widget.clipChild ? ClipRect(child: widget.child) : widget.child;
    return GestureDetector(
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      onScaleEnd: onScaleEnd,
      child: child,
    );
  }

  _ValueUpdater<Offset> translationUpdater = _ValueUpdater(
    onUpdate: (oldVal, newVal) => newVal - oldVal,
  );
  _ValueUpdater<double> rotationUpdater = _ValueUpdater(
    onUpdate: (oldVal, newVal) => newVal - oldVal,
  );
  _ValueUpdater<double> scaleUpdater = _ValueUpdater(
    onUpdate: (oldVal, newVal) => newVal / oldVal,
  );

  void onScaleStart(ScaleStartDetails details) {
    stopAnimation();
    translationUpdater.value = details.focalPoint;
    rotationUpdater.value = double.nan;
    scaleUpdater.value = 1.0;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    // handle matrix translating
    if (widget.shouldTranslate) {
      final translationDelta = translationUpdater.update(details.focalPoint);
      matrix = _translate(translationDelta) * matrix;
    }

    Offset focalPoint;
    if (widget.focalPointAlignment != null) {
      focalPoint = widget.focalPointAlignment.alongSize(context.size);
    } else {
      RenderBox renderBox = context.findRenderObject();
      focalPoint = renderBox.globalToLocal(details.focalPoint);
    }

    // handle matrix scaling
    if (widget.shouldScale && details.scale != 1.0) {
      final scaleDelta = scaleUpdater.update(details.scale);
      matrix = _scale(scaleDelta, focalPoint) * matrix;
    }

    // handle matrix rotating
    if (widget.shouldRotate && details.rotation != 0.0) {
      if (rotationUpdater.value.isNaN) {
        rotationUpdater.value = details.rotation;
      } else {
        final rotationDelta = rotationUpdater.update(details.rotation);
        matrix = _rotate(rotationDelta, focalPoint) * matrix;
      }
    }

    widget.onMatrixUpdate(matrix);
  }

  void onScaleEnd(ScaleEndDetails details) {

    Vector3 transv = Vector3.zero(), scale = Vector3.zero();
    Quaternion rotation = Quaternion.identity();
    matrix.decompose(transv, rotation, scale);

    //print('trans=(${transv.x},${transv.y}), rotation=${rotation.radians}, scale=${scale.x},${scale.y}');

    final currentPosition = Offset(transv.x, transv.y);
    animation = Tween<Offset>(begin: currentPosition, end: destRestricted(currentPosition + calcDestination(velocity: details.velocity.pixelsPerSecond / 10, deceleration: 5)))
      .animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    animation.addListener(onAnimate);
    controller.reset();
    controller.animateTo(1.0);
  }

  static Offset calcDestination({Offset velocity, double deceleration}) {
    if (velocity == Offset.zero)
      return Offset.zero;
    // t: when the object stop
    final t = velocity.distance / deceleration;
    // deceleration vector
    final a = -velocity / velocity.distance * deceleration;
    // destination position
    return (velocity + a * t / 2) * t;
  }

  // FIXME: pyshics is not real here but it's enough for our purpose.
  Offset destRestricted(Offset dest) {
    if (!widget.alwaysShownInView)
      return dest;
    
    final Vector4 p00 = matrix * Vector4(0, 0, 0, 1);
    final Vector4 p10 = matrix * Vector4(widget.size.width, 0, 0, 1);
    final Vector4 p01 = matrix * Vector4(0, widget.size.height, 0, 1);
    final Vector4 p11 = matrix * Vector4(widget.size.width, widget.size.height, 0, 1);
    
    final xx = minmax([p00.x, p10.x, p01.x, p11.x]);
    final yy = minmax([p00.y, p10.y, p01.y, p11.y]);
    final min = Vector4(xx[0], yy[0], 0, 1);
    final max = Vector4(xx[1], yy[1], 0, 1);
    final w = max.x - min.x;
    final h = max.y - min.y;

    var x = dest.dx - p00.x + min.x;
    var y = dest.dy - p00.y + min.y;

    final all = context.size;
    if (w <= all.width) {
      if (x < 0) x = 0; else if (x > all.width - w) x = all.width - w;
    } else {
      if (x > 0) x = 0; else if (x < all.width - w) x = all.width - w;
    }
    if (h <= all.height) {
      if (y < 0) y = 0; else if (y > all.height - h) y = all.height - h;
    } else {
      if (y > 0) y = 0; else if (y < all.height - h) y = all.height - h;
    }
    return Offset(x + p00.x - min.x, y + p00.y - min.y);
  }

  static List<double> minmax(List<double> values) {
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (var v in values) {
      if (v < min) min = v; else if (v > max) max = v;
    }
    return [min, max];
  }

  void onAnimate() {
    setState(() {
      final cur = matrix.getTranslation();
      final trans = Matrix4.identity()..translate(animation.value.dx - cur.x, animation.value.dy - cur.y);
      matrix = trans * matrix;
      widget.onMatrixUpdate(matrix);
    });
  }

  void stopAnimation() {
     if (controller.isAnimating) {
      controller.stop();
      animation?.removeListener(onAnimate);
      //controller.reset();
      animation = null;
    }
  }

  Matrix4 _translate(Offset translation) {
    var dx = translation.dx;
    var dy = translation.dy;

    //  ..[0]  = 1       # x scale
    //  ..[5]  = 1       # y scale
    //  ..[10] = 1       # diagonal "one"
    //  ..[12] = dx      # x translation
    //  ..[13] = dy      # y translation
    //  ..[15] = 1       # diagonal "one"
    return Matrix4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
  }

  Matrix4 _scale(double scale, Offset focalPoint) {
    var dx = (1 - scale) * focalPoint.dx;
    var dy = (1 - scale) * focalPoint.dy;

    //  ..[0]  = scale   # x scale
    //  ..[5]  = scale   # y scale
    //  ..[10] = 1       # diagonal "one"
    //  ..[12] = dx      # x translation
    //  ..[13] = dy      # y translation
    //  ..[15] = 1       # diagonal "one"
    return Matrix4(scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
  }

  Matrix4 _rotate(double angle, Offset focalPoint) {
    var c = cos(angle);
    var s = sin(angle);
    var dx = (1 - c) * focalPoint.dx + s * focalPoint.dy;
    var dy = (1 - c) * focalPoint.dy - s * focalPoint.dx;

    //  ..[0]  = c       # x scale
    //  ..[1]  = s       # y skew
    //  ..[4]  = -s      # x skew
    //  ..[5]  = c       # y scale
    //  ..[10] = 1       # diagonal "one"
    //  ..[12] = dx      # x translation
    //  ..[13] = dy      # y translation
    //  ..[15] = 1       # diagonal "one"
    return Matrix4(c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
  }
}

typedef _OnUpdate<T> = T Function(T oldValue, T newValue);

class _ValueUpdater<T> {
  final _OnUpdate<T> onUpdate;
  T value;

  _ValueUpdater({this.onUpdate});

  T update(T newValue) {
    T updated = onUpdate(value, newValue);
    value = newValue;
    return updated;
  }
}
