import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'matrix_gesture_detector.dart';

void main() => runApp(ScrollContentViewer());

class ScrollContentViewer extends StatefulWidget {
  ScrollContentViewer({Key key}) : super(key: key);

  @override
  _ScrollContentViewerState createState() => _ScrollContentViewerState();
}

class _ScrollContentViewerState extends State<ScrollContentViewer> with SingleTickerProviderStateMixin {

  final controller = MatrixGestureTransformController();
  var _contentSize = Size(3000, 4000);
  Matrix4 transform = Matrix4.identity();

  @override
  void didUpdateWidget(ScrollContentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Hello, world!'),
          actions: <Widget>[
            IconButton(icon: Icon(Icons.home), onPressed: () => controller.moveTo(Offset.zero))
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.min(constraints.maxWidth / _contentSize.width, constraints.maxHeight / _contentSize.height);
            return MatrixGestureTransform(
              controller: controller,
              shouldRotate: true,
              transform: Matrix4.identity().scaled(scale),
              size: _contentSize,
              builder: (context, transform) => CustomPaint(
                painter: CustomPagePainter(contentSize: _contentSize, transform: transform),
                size: _contentSize,
              )
            );
          }
        )
      )
    );
  }
}

class CustomPagePainter extends CustomPainter {
  final Size contentSize;
  final Matrix4 transform;
  CustomPagePainter({@required this.contentSize, @required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint();
    bg.color = Colors.blueAccent;
    canvas.drawRect(Rect.fromLTWH(0, 0, contentSize.width, contentSize.height), bg);

    final p00 = Offset.zero;
    final p10 = Offset(contentSize.width, 0);
    final p01 = Offset(0, contentSize.height);
    final p11 = Offset(contentSize.width, contentSize.height);

    final col = Paint();
    col.color = Colors.greenAccent;

    canvas.drawLine(p00, p11, col);
    canvas.drawLine(p10, p01, col);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

}
