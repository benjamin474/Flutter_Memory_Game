import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '記憶小遊戲',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int gridSize = 3;
  bool showGamePage = false;

  void startGame(int size) {
    setState(() {
      gridSize = size;
      showGamePage = true;
    });
  }

  void exitGame() {
    setState(() {
      showGamePage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景圖片
          Positioned.fill(
            child: Image.asset(
              'assets/images/wallpaper.jpg', // 使用你的背景圖片
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: AnimatedOpacity(
              opacity: showGamePage ? 0 : 1,
              duration: Duration(milliseconds: 300),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '記憶小遊戲',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // 使文字顏色與背景圖片對比明顯
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '請選擇遊戲格子數',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // 使文字顏色與背景圖片對比明顯
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGridButton('3 x 3', 3),
                      SizedBox(width: 10),
                      _buildGridButton('4 x 4', 4),
                      SizedBox(width: 10),
                      _buildGridButton('5 x 5', 5),
                      SizedBox(width: 10),
                      _buildGridButton('6 x 6', 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (showGamePage)
            AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ),
                  child: child,
                );
              },
              child: GamePage(key: ValueKey(gridSize), gridSize: gridSize, onExit: exitGame),
            ),
        ],
      ),
    );
  }

  Widget _buildGridButton(String text, int size) {
    return ElevatedButton(
      onPressed: () => startGame(size),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textStyle: TextStyle(fontSize: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
      ),
      child: Text(text),
    );
  }
}

enum CellState { normal, highlighted, selected, correct, wrong, missed }

class GamePage extends StatefulWidget {
  final int gridSize;
  final VoidCallback onExit;

  const GamePage({super.key, required this.gridSize, required this.onExit});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late List<List<CellState>> boardStates;
  late Set<Point<int>> activeCells;
  late Set<Point<int>> userSelected;
  bool answered = false;
  String resultMessage = '';
  bool canTap = false;
  int countdown = 3;
  Timer? countdownTimer;
  late List<List<AnimationController>> _controllers;

  @override
  void initState() {
    super.initState();
    initBoard();
    startHighlight();
    startCountdown();
    _controllers = List.generate(widget.gridSize, (i) =>
      List.generate(widget.gridSize, (j) =>
        AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        )
      )
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    for (var row in _controllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void initBoard() {
    int n = widget.gridSize;
    boardStates =
        List.generate(n, (_) => List.generate(n, (_) => CellState.normal));
    userSelected = {};
    activeCells = {};

    int count = Random().nextInt(n) + n;
    while (activeCells.length < count) {
      int i = Random().nextInt(n);
      int j = Random().nextInt(n);
      activeCells.add(Point(i, j));
    }
  }

  void startHighlight() {
    setState(() {
      for (var point in activeCells) {
        boardStates[point.x][point.y] = CellState.highlighted;
      }
    });
    Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          for (var point in activeCells) {
            boardStates[point.x][point.y] = CellState.normal;
          }
        });
      }
    });
  }

  void startCountdown() {
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          countdown--;
          if (countdown <= 0) {
            canTap = true;
            countdownTimer?.cancel();
          }
        });
      }
    });
  }

  void onCellTap(int i, int j) {
    if (!canTap || answered) return;

    setState(() {
      Point<int> p = Point(i, j);
      if (userSelected.contains(p)) {
        userSelected.remove(p);
        boardStates[i][j] = CellState.normal;
      } else {
        userSelected.add(p);
        boardStates[i][j] = CellState.selected;
      }
      _controllers[i][j].forward().then((_) => _controllers[i][j].reverse());
    });
  }

  void checkAnswers() {
    setState(() {
      answered = true;
      int correctCount = 0;
      int n = widget.gridSize;

      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          Point<int> p = Point(i, j);
          bool shouldBeSelected = activeCells.contains(p);
          bool isSelected = userSelected.contains(p);

          if (shouldBeSelected && isSelected) {
            boardStates[i][j] = CellState.correct;
            correctCount++;
          } else if (shouldBeSelected && !isSelected) {
            boardStates[i][j] = CellState.missed;
          } else if (!shouldBeSelected && isSelected) {
            boardStates[i][j] = CellState.wrong;
          }
        }
      }

      double ratio = correctCount / activeCells.length;
      if (ratio == 1.0 && userSelected.length == activeCells.length) {
        resultMessage = '全對了 恭喜您~';
      } else if (ratio >= 0.7) {
        resultMessage = '再接再厲 快成功了~';
      } else {
        resultMessage = '再來一次吧 這次一定能成功的~';
      }
    });
  }

  Color getColor(CellState state) {
    switch (state) {
      case CellState.normal:
        return Colors.grey[800]!;
      case CellState.highlighted:
        return Colors.blue;
      case CellState.selected:
        return Colors.orange;
      case CellState.correct:
        return Colors.green;
      case CellState.wrong:
        return Colors.red;
      case CellState.missed:
        return Colors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    int n = widget.gridSize;
    return Scaffold(
      appBar: AppBar(
        title: Text('遊戲進行中!'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: widget.onExit,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              margin: EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: n,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: n * n,
                itemBuilder: (context, index) {
                  int i = index ~/ n;
                  int j = index % n;
                  return GestureDetector(
                    onTap: () => onCellTap(i, j),
                    child: ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.2).animate(
                        CurvedAnimation(
                          parent: _controllers[i][j],
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: getColor(boardStates[i][j]),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (countdown > 0 && !answered)
              Text(
                '剩餘 $countdown 秒後開始',
                style: TextStyle(fontSize: 20),
              )
            else if (!answered)
              ElevatedButton(
                onPressed: checkAnswers,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text('送出'),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  resultMessage,
                  style: TextStyle(fontSize: 24),
                ),
              ),
              ElevatedButton(
                onPressed: widget.onExit,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text('返回'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}