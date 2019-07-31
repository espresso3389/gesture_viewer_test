import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'matrix_gesture_detector.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
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
        ),
        body: ScrollContentViewer()
      )
    );
  }
}

class ScrollContentViewer extends StatefulWidget {
  ScrollContentViewer({Key key}) : super(key: key);

  @override
  _ScrollContentViewerState createState() => _ScrollContentViewerState();
}

class _ScrollContentViewerState extends State<ScrollContentViewer> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  var _contentSize = Size(3000, 4000);
  Matrix4 transform = Matrix4.identity();
  double _ratio;

  @override
  void didUpdateWidget(ScrollContentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ratio = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_ratio == null) {
      final screenSize = MediaQuery.of(context).size;
      _ratio = math.min(screenSize.width / _contentSize.width, screenSize.height / _contentSize.height);
    }

    return MatrixGestureTransform(
      shouldRotate: true,
      transform: Matrix4.identity().scaled(_ratio),
      size: _contentSize,
      builder: (context, transform) => CustomPaint(
        painter: CustomPagePainter(contentSize: _contentSize, transform: transform),
        size: _contentSize,
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
