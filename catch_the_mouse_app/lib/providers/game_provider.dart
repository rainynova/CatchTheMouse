import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';

// --- Enums and Models ---
enum GameState { setup, playing, transition, ended }
enum Player { mouse, keeper1, keeper2, keeper3 }
enum TileType { storage, road }

class Position {
  final int x;
  final int y;
  Position(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class GameProvider with ChangeNotifier {
  // --- Game Settings ---
  static const int boardSize = 9;
  static const int maxTurns = 10;

  // --- Game State ---
  GameState _gameState = GameState.setup;
  List<List<TileType>> _board = [];
  final List<Player> _playerOrder = [Player.mouse, Player.keeper1, Player.keeper2, Player.keeper3];
  int _placementTurn = 0;
  Player _currentPlayer = Player.mouse;
  int _currentTurn = 1;
  Position? _mousePosition;
  List<Position?> _keeperPositions = List.filled(3, null);
  List<Position> _mousePath = [];
  List<Position> _foundFootprints = [];
  String _message = '';
  bool _isKeeperWin = false;

  // --- Controllers for UI events ---
  final _infoMessageController = StreamController<String>.broadcast();
  Stream<String> get infoMessages => _infoMessageController.stream;

  // --- Getters ---
  GameState get gameState => _gameState;
  List<List<TileType>> get board => _board;
  Player get currentPlayer => _currentPlayer;
  int get currentTurn => _currentTurn;
  Position? get mousePosition => _mousePosition;
  List<Position?> get keeperPositions => _keeperPositions;
  List<Position> get mousePath => _mousePath;
  List<Position> get foundFootprints => _foundFootprints;
  String get message => _message;
  bool get isKeeperWin => _isKeeperWin;
  int get placementTurn => _placementTurn;
  List<Player> get playerOrder => _playerOrder;


  GameProvider() {
    initGame();
  }

  @override
  void dispose() {
    _infoMessageController.close();
    super.dispose();
  }

  void _showInfo(String message) {
    _infoMessageController.add(message);
  }

  void initGame() {
    _gameState = GameState.setup;
    _board = [];
    _placementTurn = 0;
    _currentPlayer = Player.mouse;
    _currentTurn = 1;
    _mousePosition = null;
    _keeperPositions = List.filled(3, null);
    _mousePath = [];
    _foundFootprints = [];
    _isKeeperWin = false;
    
    _createBoard();
    _updateMessageForSetup();
    notifyListeners();
  }

  void _createBoard() {
    _board = List.generate(boardSize, (row) {
      return List.generate(boardSize, (col) {
        if (row % 2 == 0) {
          return (col % 2 == 1) ? TileType.road : TileType.storage;
        } else {
          return TileType.road;
        }
      });
    });
  }

  void _updateMessageForSetup() {
    final playerToPlace = _playerOrder[_placementTurn];
    String tileType = playerToPlace == Player.mouse ? '창고' : '길 교차점';
    _message = '[위치선택] ${playerToPlace.name}, 배치할 $tileType을 클릭하세요.';
    notifyListeners();
  }

  void handleSetupClick(int x, int y) {
    final playerToPlace = _playerOrder[_placementTurn];
    final position = Position(x, y);

    if (playerToPlace == Player.mouse) {
      if (_board[y][x] != TileType.storage) {
        _showInfo('쥐는 창고에만 배치할 수 있습니다.');
        return;
      }
      _mousePosition = position;
      _mousePath.add(position);
    } else {
      if (!isIntersection(x, y)) {
        _showInfo('창고지기는 길의 교차점에만 배치할 수 있습니다.');
        return;
      }
      if (_keeperPositions.any((p) => p == position)) {
        _showInfo('다른 창고지기가 이미 있는 위치입니다.');
        return;
      }
      _keeperPositions[_placementTurn - 1] = position;
    }

    _placementTurn++;

    if (_placementTurn >= _playerOrder.length) {
      _endSetup();
    } else {
      _currentPlayer = _playerOrder[_placementTurn];
      _updateMessageForSetup();
    }
    notifyListeners();
  }

  void _endSetup() {
    _gameState = GameState.transition;
    _message = '모든 배치가 완료되었습니다. 게임을 시작하세요.';
    notifyListeners();
  }
  
  void handleGameClick(int x, int y) {
    if (_gameState != GameState.playing) return;

    if (_currentPlayer == Player.mouse) {
      _handleMouseTurn(x, y);
    } else {
      _handleKeeperTurn(x, y);
    }
  }

  void _handleMouseTurn(int x, int y) {
    if (_board[y][x] != TileType.storage) {
      _showInfo('쥐는 창고로만 이동할 수 있습니다.');
      return;
    }
    final newPos = Position(x, y);
    final dx = (_mousePosition!.x - x).abs();
    final dy = (_mousePosition!.y - y).abs();

    if (!((dx == 2 && dy == 0) || (dx == 0 && dy == 2))) {
      _showInfo('유효하지 않은 이동입니다. 2칸씩만 이동할 수 있습니다.');
      return;
    }
    if (_mousePath.contains(newPos)) {
      _showInfo('이미 방문했던 창고입니다.');
      return;
    }

    _mousePosition = newPos;
    _mousePath.add(newPos);
    _advanceToNextPlayer();
  }

  void _handleKeeperTurn(int x, int y) {
    final keeperIndex = _currentPlayer.index - 1;
    final keeperPos = _keeperPositions[keeperIndex]!;
    final newPos = Position(x, y);

    // Move
    if (_board[y][x] == TileType.road) {
      if (!isIntersection(x, y)) {
        _showInfo('창고지기는 교차점으로만 이동할 수 있습니다.');
        return;
      }
      final dx = (keeperPos.x - x).abs();
      final dy = (keeperPos.y - y).abs();
      if (!((dx == 2 && dy == 0) || (dx == 0 && dy == 2))) {
        _showInfo('유효하지 않은 이동입니다. 2칸씩만 이동할 수 있습니다.');
        return;
      }
      if (_keeperPositions.any((p) => p == newPos)) {
        _showInfo('다른 창고지기가 있는 위치입니다.');
        return;
      }

      _keeperPositions[keeperIndex] = newPos;
      _advanceToNextPlayer();
    } 
    // Check
    else if (_board[y][x] == TileType.storage) {
      final dx = (keeperPos.x - x).abs();
      final dy = (keeperPos.y - y).abs();
      if (!(dx == 1 && dy == 1)) {
        _showInfo('인접한 창고만 확인할 수 있습니다.');
        return;
      }

      if (_mousePosition == newPos) {
        _endGame(true);
        return;
      }

      if (_mousePath.contains(newPos)) {
        _showInfo('쥐의 흔적을 발견했습니다!');
        if (!_foundFootprints.contains(newPos)) {
          _foundFootprints.add(newPos);
        }
      } else {
        _showInfo('아무것도 없습니다.');
      }
      _advanceToNextPlayer();
    }
  }

  void _advanceToNextPlayer() {
    if (_currentPlayer == Player.keeper3) {
      _gameState = GameState.transition;
      _message = '턴 $_currentTurn 종료. 다음 턴을 시작하려면 버튼을 누르세요.';
    } else {
      _currentPlayer = _playerOrder[_currentPlayer.index + 1];
      _message = '[${_currentPlayer.name} 턴] 행동할 타일을 클릭하세요.';
    }
    notifyListeners();
  }

  void startTurnAction() {
    if (_gameState == GameState.transition) {
      // 쥐의 경로 길이를 확인하여 첫 턴인지 아닌지를 구분합니다.
      // 경로 길이가 1이면, 쥐가 아직 움직이지 않은 첫 턴의 시작입니다.
      if (_mousePath.length == 1) { // First turn
        _gameState = GameState.playing;
        _currentPlayer = Player.mouse;
      } else { // Subsequent turns
        _currentTurn++;
        if (_currentTurn > maxTurns) {
          _endGame(false);
          return;
        }
        _gameState = GameState.playing;
        _currentPlayer = Player.mouse;
      }
    }
    _message = '[${_currentPlayer.name} 턴] 행동할 타일을 클릭하세요.';
    notifyListeners();
  }

  void _endGame(bool keeperWin) {
    _gameState = GameState.ended;
    _isKeeperWin = keeperWin;
    if (keeperWin) {
      _message = '${_currentPlayer.name}이(가) 쥐를 찾았습니다! 창고지기 팀 승리!';
    } else {
      _message = '10턴 동안 쥐를 찾지 못했습니다! 쥐 승리!';
    }
    notifyListeners();
  }

  bool isIntersection(int x, int y) {
    if (_board[y][x] != TileType.road) return false;
    final diagonals = [
      Position(-1, -1), Position(1, -1),
      Position(-1, 1), Position(1, 1)
    ];
    for (final d in diagonals) {
      final nx = x + d.x;
      final ny = y + d.y;
      if (nx < 0 || nx >= boardSize || ny < 0 || ny >= boardSize || _board[ny][nx] != TileType.storage) {
        return false;
      }
    }
    return true;
  }
}
