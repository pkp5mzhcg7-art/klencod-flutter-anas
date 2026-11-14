import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final RoyalRunnerGame game;

  @override
  void initState() {
    super.initState();
    game = RoyalRunnerGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: game.handleTap,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v > 0) {
            game.moveRight();
          } else if (v < 0) {
            game.moveLeft();
          }
        },
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < 0) game.jump();
        },
        child: GameWidget(game: game),
      ),
    );
  }
}

class RoyalRunnerGame extends FlameGame {
  late Player player;
  late TextComponent scoreText;

  final List<Obstacle> obstacles = [];
  final List<Coin> coins = [];

  double speed = 260;
  double spawnTimer = 0;
  double coinTimer = 0;
  int score = 0;
  bool isGameOver = false;

  TextComponent? gameOverText;
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    player = Player(this);
    add(player);

    scoreText = TextComponent(
      text: 'النقاط: 0',
      position: Vector2(16, 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);
  }

  double laneX(int lane) => size.x * (lane + 1) / 4;

  @override
  void update(double dt) {
    super.update(dt);

    if (isGameOver) return;

    speed += dt * 5;
    spawnTimer += dt;
    coinTimer += dt;

    if (spawnTimer >= 0.9) {
      spawnTimer = 0;
      spawnObstacle();
    }

    if (coinTimer >= 1.3) {
      coinTimer = 0;
      spawnCoin();
    }

    obstacles.removeWhere((o) => o.parent == null);
    coins.removeWhere((c) => c.parent == null);

    final playerRect = _rect(player);

    for (final o in obstacles) {
      if (_rect(o).overlaps(playerRect)) {
        _gameOver();
        break;
      }
    }

    if (isGameOver) return;

    for (final c in coins.toList()) {
      if (_rect(c).overlaps(playerRect)) {
        c.removeFromParent();
        coins.remove(c);
        score++;
        scoreText.text = 'النقاط: $score';
      }
    }
  }

  ui.Rect _rect(PositionComponent c) {
    return ui.Rect.fromLTWH(
      c.position.x,
      c.position.y,
      c.size.x,
      c.size.y,
    );
  }

  void spawnObstacle() {
    final lane = _random.nextInt(3);
    final o = Obstacle(this, lane);
    obstacles.add(o);
    add(o);
  }

  void spawnCoin() {
    final lane = _random.nextInt(3);
    final c = Coin(this, lane);
    coins.add(c);
    add(c);
  }

  void _gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    gameOverText = TextComponent(
      text: 'انتهت اللعبة\nاضغط لإعادة',
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    add(gameOverText!);
  }

  void restart() {
    isGameOver = false;
    score = 0;
    speed = 260;
    spawnTimer = 0;
    coinTimer = 0;

    for (final o in obstacles.toList()) {
      o.removeFromParent();
    }
    obstacles.clear();

    for (final c in coins.toList()) {
      c.removeFromParent();
    }
    coins.clear();

    gameOverText?.removeFromParent();
    gameOverText = null;

    player.reset();
    scoreText.text = 'النقاط: 0';
  }

  void moveLeft() {
    if (!isGameOver) player.moveLeft();
  }

  void moveRight() {
    if (!isGameOver) player.moveRight();
  }

  void jump() {
    if (!isGameOver) player.jump();
  }

  void handleTap() {
    if (isGameOver) {
      restart();
    } else {
      player.jump();
    }
  }
}

class Player extends PositionComponent {
  final RoyalRunnerGame game;

  int lane = 1;
  bool jumping = false;
  double jumpVelocity = 0;

  Player(this.game) : super(size: Vector2(40, 70));

  double get baseY => game.size.y - size.y - 30;

  @override
  void update(double dt) {
    super.update(dt);

    final targetX = game.laneX(lane) - size.x / 2;
    position.x += (targetX - position.x) * min(1, dt * 12);

    if (jumping) {
      jumpVelocity += 1800 * dt;
      position.y += jumpVelocity * dt;

      if (position.y >= baseY) {
        position.y = baseY;
        jumping = false;
        jumpVelocity = 0;
      }
    } else {
      position.y = baseY;
    }
  }

  void moveLeft() {
    if (lane > 0) lane--;
  }

  void moveRight() {
    if (lane < 2) lane++;
  }

  void jump() {
    if (!jumping) {
      jumping = true;
      jumpVelocity = -700;
    }
  }

  void reset() {
    lane = 1;
    jumping = false;
    jumpVelocity = 0;
    position.x = game.laneX(1) - size.x / 2;
    position.y = baseY;
  }

  @override
  void render(ui.Canvas canvas) {
    final body = ui.Paint()..color = const Color(0xFF1B5E20);
    final gold = ui.Paint()..color = const Color(0xFFFFD700);
    final border = ui.Paint()
      ..color = const Color(0xFFFFD700)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;

    final r = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      const ui.Radius.circular(10),
    );

    canvas.drawRRect(r, body);
    canvas.drawRRect(r, border);

    canvas.drawCircle(ui.Offset(size.x / 2, 12), 10, gold);

    final crown = ui.Path()
      ..moveTo(size.x / 2 - 14, 4)
      ..lineTo(size.x / 2 - 6, -12)
      ..lineTo(size.x / 2, 0)
      ..lineTo(size.x / 2 + 6, -12)
      ..lineTo(size.x / 2 + 14, 4)
      ..close();

    canvas.drawPath(crown, gold);
  }
}

class Obstacle extends PositionComponent {
  final RoyalRunnerGame game;

  Obstacle(this.game, int lane) : super(size: Vector2(50, 50)) {
    position = Vector2(game.laneX(lane) - 25, -60);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += game.speed * dt;

    if (position.y > game.size.y + 100) {
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final fill = ui.Paint()..color = const Color(0xFFB71C1C);
    final border = ui.Paint()
      ..color = const Color(0xFFFF5252)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4;

    final r = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      const ui.Radius.circular(8),
    );

    canvas.drawRRect(r, fill);
    canvas.drawRRect(r, border);
  }
}

class Coin extends PositionComponent {
  final RoyalRunnerGame game;

  Coin(this.game, int lane) : super(size: Vector2(28, 28)) {
    position = Vector2(game.laneX(lane) - 14, -40);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += game.speed * dt;

    if (position.y > game.size.y + 100) {
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final gold = ui.Paint()..color = const Color(0xFFFFD700);
    final border = ui.Paint()
      ..color = const Color(0xFFFFA000)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(
      ui.Offset(size.x / 2, size.y / 2),
      size.x / 2,
      gold,
    );

    canvas.drawCircle(
      ui.Offset(size.x / 2, size.y / 2),
      size.x / 2,
      border,
    );
  }
}