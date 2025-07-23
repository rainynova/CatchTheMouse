import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/game_provider.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: const GameView(),
    );
  }
}

class GameView extends StatefulWidget {
  const GameView({super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  @override
  void initState() {
    super.initState();
    final game = Provider.of<GameProvider>(context, listen: false);
    
    // 위젯이 빌드된 후 콜백을 추가합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider에 리스너를 추가하여 게임 상태 변경을 감지합니다.
      game.addListener(_onGameStateChange);
      // 정보 메시지 스트림을 구독합니다.
      game.infoMessages.listen((message) {
        _showInfoDialog(context, message);
      });
    });
  }

  @override
  void dispose() {
    // 위젯이 제거될 때 리스너를 정리합니다.
    final game = Provider.of<GameProvider>(context, listen: false);
    game.removeListener(_onGameStateChange);
    // Provider가 dispose될 때 스트림도 자동으로 닫힙니다.
    super.dispose();
  }

  // 게임 상태가 변경될 때 호출될 메소드입니다.
  void _onGameStateChange() {
    final game = Provider.of<GameProvider>(context, listen: false);
    if (game.gameState == GameState.ended) {
      // 게임이 종료 상태이면 결과 다이얼로그를 표시합니다.
      _showGameResultDialog(context, game.message);
    }
  }

  // 간단한 정보 다이얼로그를 표시하는 함수입니다.
  void _showInfoDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('알림'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 다이얼로그를 닫습니다.
              },
            ),
          ],
        );
      },
    );
  }

  // 게임 결과 다이얼로그를 표시하는 함수입니다.
  void _showGameResultDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥쪽을 탭해도 닫히지 않도록 설정합니다.
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('게임 종료'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 다이얼로그를 닫습니다.
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('쥐를 잡자! 쥐를 잡자! 찍찍찍!!!'),
        backgroundColor: Colors.brown[300],
      ),
      backgroundColor: Colors.brown[100],
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              GameInfoPanel(),
              const SizedBox(height: 20),
              GameBoard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class GameInfoPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final player = game.currentPlayer;
    final turn = game.currentTurn;
    final message = game.message;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current Player Icon
          Column(
            children: [
              const Text('현재 플레이어', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                width: 50,
                height: 50,
                child: _getPlayerIcon(game.gameState == GameState.transition ? null : player),
              ),
            ],
          ),
          
          // Game Status
          Expanded(
            child: Column(
              children: [
                Text('턴: $turn / ${GameProvider.maxTurns}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(fontSize: 14, color: Colors.redAccent), textAlign: TextAlign.center),
              ],
            ),
          ),

          // Action Button
          if (game.gameState == GameState.transition || game.gameState == GameState.ended)
            ElevatedButton(
              onPressed: () {
                if (game.gameState == GameState.ended) {
                  game.initGame();
                } else {
                  game.startTurnAction();
                }
              },
              child: Text(
                game.gameState == GameState.ended
                    ? '다시 시작'
                    : (game.mousePath.length == 1 ? '게임 시작' : '다음 턴'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getPlayerIcon(Player? player) {
    if (player == null) return Container();
    String assetName;
    switch (player) {
      case Player.mouse:
        assetName = 'assets/images/mouse.svg';
        break;
      case Player.keeper1:
        assetName = 'assets/images/keeper_1.svg';
        break;
      case Player.keeper2:
        assetName = 'assets/images/keeper_2.svg';
        break;
      case Player.keeper3:
        assetName = 'assets/images/keeper_3.svg';
        break;
    }
    return SvgPicture.asset(assetName);
  }
}

class GameBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final boardSize = GameProvider.boardSize;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown[600]!, width: 2),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: boardSize,
        ),
        itemCount: boardSize * boardSize,
        itemBuilder: (context, index) {
          final x = index % boardSize;
          final y = index ~/ boardSize;
          return TileWidget(x: x, y: y);
        },
      ),
    );
  }
}

class TileWidget extends StatelessWidget {
  final int x;
  final int y;

  const TileWidget({super.key, required this.x, required this.y});

  @override
  Widget build(BuildContext context) {
    final game = Provider.of<GameProvider>(context);
    final tileType = game.board[y][x];
    final position = Position(x, y);

    final bool isMouseHere = game.mousePosition == position;
    final keeperIndex = game.keeperPositions.indexWhere((p) => p == position);

    // 쥐는 게임 중에는 현재 턴일 때만, 게임 종료 시에는 항상 보이도록 설정합니다.
    final bool isMouseVisible = (game.gameState == GameState.playing && game.currentPlayer == Player.mouse) ||
                                (game.gameState == GameState.setup && game.playerOrder[game.placementTurn] == Player.mouse) ||
                                game.gameState == GameState.ended;

    // 발자국 표시 여부를 결정합니다.
    // 게임 중에는 발견된 발자국만 표시합니다.
    // 게임이 종료되면 쥐의 마지막 위치를 제외한 전체 경로를 표시합니다.
    final bool isFoundFootprint = game.foundFootprints.contains(position);
    final bool isRevealedPath = game.gameState == GameState.ended && game.mousePath.contains(position);
    final bool shouldShowFootprint = (isFoundFootprint || isRevealedPath) && !isMouseHere;


    return GestureDetector(
      onTap: () {
        if (game.gameState == GameState.setup) {
          game.handleSetupClick(x, y);
        } else if (game.gameState == GameState.playing) {
          game.handleGameClick(x, y);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 기본 타일 배경 (궁전 또는 길)
            _getTileBackground(tileType),
            
            // 2. 발자국 (표시해야 할 경우)
            if (shouldShowFootprint)
              _getFootprint(game, position),

            // 3. 창고지기
            if (keeperIndex != -1)
              _getPlayerIcon(Player.values[keeperIndex + 1]),

            // 4. 쥐
            if (isMouseVisible && isMouseHere)
              _getPlayerIcon(Player.mouse),
              
            // 5. 쥐를 잡았을 때의 효과
            if (game.gameState == GameState.ended && game.isKeeperWin && isMouseHere)
              Container(color: Colors.red.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  // 기본 타일(궁전, 길) 위젯을 반환합니다.
  Widget _getTileBackground(TileType type) {
    String assetName = type == TileType.storage 
      ? 'assets/images/palace.svg' 
      : 'assets/images/road.svg';
    return SvgPicture.asset(assetName, fit: BoxFit.cover);
  }

  // 발자국 위젯을 반환합니다.
  Widget _getFootprint(GameProvider game, Position pos) {
    final footprintIndex = game.mousePath.indexWhere((p) => p == pos);
    // 시작점은 노란색, 나머지는 회색으로 표시합니다.
    final color = (footprintIndex == 0) 
        ? Colors.yellow.withOpacity(0.8) 
        : Colors.black.withOpacity(0.6);

    return SvgPicture.asset(
      'assets/images/footprint.svg',
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      fit: BoxFit.contain,
    );
  }

  // 플레이어(쥐, 창고지기) 아이콘 위젯을 반환합니다.
  Widget _getPlayerIcon(Player player) {
    String assetName;
    switch (player) {
      case Player.mouse:
        assetName = 'assets/images/mouse.svg';
        break;
      case Player.keeper1:
        assetName = 'assets/images/keeper_1.svg';
        break;
      case Player.keeper2:
        assetName = 'assets/images/keeper_2.svg';
        break;
      case Player.keeper3:
        assetName = 'assets/images/keeper_3.svg';
        break;
    }
    return SvgPicture.asset(assetName, fit: BoxFit.contain);
  }
}
