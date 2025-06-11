import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const TetrisApp());
}

class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: TetrisGame(),
        ),
      ),
    );
  }
}

class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> {
  static const int rowCount = 20;
  static const int columnCount = 10;
  static const Duration tickDuration = Duration(milliseconds: 500);
  late List<List<Color?>> board;
  Piece? currentPiece;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
    _spawnPiece();
    timer = Timer.periodic(tickDuration, (_) => _update());
  }

  void _initializeBoard() {
    board = List.generate(rowCount,
        (_) => List.generate(columnCount, (_) => null, growable: false),
        growable: false);
  }

  void _spawnPiece() {
    final shapes = Piece.shapes;
    currentPiece = Piece(shapes[Random().nextInt(shapes.length)]);
  }

  void _update() {
    setState(() {
      if (!_movePiece(0, 1)) {
        _lockPiece();
        _clearLines();
        _spawnPiece();
        if (!_pieceFits(currentPiece!)) {
          timer?.cancel();
        }
      }
    });
  }

  bool _movePiece(int dx, int dy, [bool rotate = false]) {
    if (currentPiece == null) return false;
    final moved = currentPiece!.move(dx, dy, rotate);
    if (_pieceFits(moved)) {
      currentPiece = moved;
      return true;
    }
    return false;
  }

  bool _pieceFits(Piece piece) {
    for (final block in piece.blocks) {
      final x = block.dx;
      final y = block.dy;
      if (x < 0 || x >= columnCount || y >= rowCount) return false;
      if (y >= 0 && board[y][x] != null) return false;
    }
    return true;
  }

  void _lockPiece() {
    if (currentPiece == null) return;
    for (final block in currentPiece!.blocks) {
      if (block.dy >= 0 && block.dy < rowCount) {
        board[block.dy][block.dx] = currentPiece!.color;
      }
    }
  }

  void _clearLines() {
    board.removeWhere((row) => row.every((cell) => cell != null));
    while (board.length < rowCount) {
      board.insert(0, List.generate(columnCount, (_) => null, growable: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
          setState(() => _movePiece(-1, 0));
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
          setState(() => _movePiece(1, 0));
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          setState(() => _movePiece(0, 1));
        } else if (event.isKeyPressed(LogicalKeyboardKey.space)) {
          setState(() => _movePiece(0, 0, true));
        }
      },
      child: AspectRatio(
        aspectRatio: columnCount / rowCount,
        child: CustomPaint(
          painter: _BoardPainter(board, currentPiece),
        ),
      ),
    );
  }
}

class Piece {
  final List<Offset> shape;
  final Color color;
  Offset position;
  int rotationIndex = 0;

  Piece(this.shape)
      : color = Colors.primaries[Random().nextInt(Colors.primaries.length)],
        position = const Offset(3, -1);

  static final List<List<Offset>> shapes = [
    // I
    [Offset(-1, 0), Offset(0, 0), Offset(1, 0), Offset(2, 0)],
    // O
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)],
    // T
    [Offset(-1, 0), Offset(0, 0), Offset(1, 0), Offset(0, 1)],
    // L
    [Offset(-1, 0), Offset(0, 0), Offset(1,0), Offset(-1,1)],
    // J
    [Offset(-1, 0), Offset(0, 0), Offset(1,0), Offset(1,1)],
    // S
    [Offset(0,0), Offset(1,0), Offset(-1,1), Offset(0,1)],
    // Z
    [Offset(-1,0), Offset(0,0), Offset(0,1), Offset(1,1)],
  ];

  Piece move(int dx, int dy, [bool rotate = false]) {
    final newPiece = Piece(shape)
      ..position = position.translate(dx.toDouble(), dy.toDouble())
      ..rotationIndex = rotationIndex;
    if (rotate) newPiece.rotationIndex = (rotationIndex + 1) % 4;
    return newPiece;
  }

  Iterable<Offset> get blocks sync* {
    for (final offset in shape) {
      final rotated = _rotate(offset, rotationIndex);
      yield Offset(rotated.dx + position.dx, rotated.dy + position.dy);
    }
  }

  Offset _rotate(Offset offset, int times) {
    Offset result = offset;
    for (int i = 0; i < times; i++) {
      result = Offset(-result.dy, result.dx);
    }
    return result;
  }
}

class _BoardPainter extends CustomPainter {
  final List<List<Color?>> board;
  final Piece? currentPiece;
  static const double borderWidth = 1;

  _BoardPainter(this.board, this.currentPiece);

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / _TetrisGameState.columnCount;
    final cellHeight = size.height / _TetrisGameState.rowCount;
    final paint = Paint();

    // Draw existing blocks
    for (int y = 0; y < board.length; y++) {
      for (int x = 0; x < board[y].length; x++) {
        final color = board[y][x];
        if (color != null) {
          paint.color = color;
          final rect = Rect.fromLTWH(
              x * cellWidth, y * cellHeight, cellWidth, cellHeight);
          canvas.drawRect(rect, paint);
        }
      }
    }

    // Draw current piece
    if (currentPiece != null) {
      paint.color = currentPiece!.color;
      for (final block in currentPiece!.blocks) {
        if (block.dy < 0) continue;
        final rect = Rect.fromLTWH(
            block.dx * cellWidth, block.dy * cellHeight, cellWidth, cellHeight);
        canvas.drawRect(rect, paint);
      }
    }

    // Grid lines
    paint.color = Colors.grey;
    for (int i = 0; i <= _TetrisGameState.columnCount; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), paint..strokeWidth = borderWidth);
    }
    for (int i = 0; i <= _TetrisGameState.rowCount; i++) {
      final y = i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}
