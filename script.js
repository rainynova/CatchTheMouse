// 게임 설정
const BOARD_SIZE = 9;
const MAX_TURNS = 10;

// DOM 요소
const boardElement = document.getElementById('game-board');
const turnCounterElement = document.getElementById('turn-counter');
const currentPlayerElement = document.getElementById('current-player');
const messageElement = document.getElementById('message');
const nextTurnBtn = document.getElementById('next-turn-btn');

// 오디오 컨텍스트 (사운드용)
let audioCtx;

// 게임 상태
let gameState = 'setup'; // 'setup', 'playing', 'transition', 'ended'
let board = [];
const playerOrder = ['쥐', '창고지기1', '창고지기2', '창고지기3'];
let placementTurn = 0;
let currentPlayer = '쥐';
let currentTurn = 1;
let mousePosition = null;
let keeperPositions = [null, null, null];
let mousePath = [];
let foundFootprints = [];

// --- 사운드 재생 함수 ---
function playSound(type) {
    if (!audioCtx) {
        try {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        } catch (e) {
            console.error("Web Audio API is not supported in this browser");
            return;
        }
    }
    const oscillator = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();
    oscillator.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    gainNode.gain.setValueAtTime(0.1, audioCtx.currentTime);

    oscillator.start(); // 먼저 start()를 호출합니다.

    switch (type) {
        case 'move': oscillator.frequency.setValueAtTime(200, audioCtx.currentTime); oscillator.stop(audioCtx.currentTime + 0.1); break;
        case 'check': oscillator.frequency.setValueAtTime(300, audioCtx.currentTime); oscillator.stop(audioCtx.currentTime + 0.08); break;
        case 'footprint': oscillator.frequency.setValueAtTime(440, audioCtx.currentTime); gainNode.gain.setValueAtTime(0.2, audioCtx.currentTime); oscillator.stop(audioCtx.currentTime + 0.15); break;
        case 'win': oscillator.frequency.setValueAtTime(523, audioCtx.currentTime); oscillator.stop(audioCtx.currentTime + 0.2); break;
        case 'lose': oscillator.frequency.setValueAtTime(130, audioCtx.currentTime); oscillator.stop(audioCtx.currentTime + 0.3); break;
        case 'click': oscillator.frequency.setValueAtTime(600, audioCtx.currentTime); gainNode.gain.setValueAtTime(0.05, audioCtx.currentTime); oscillator.stop(audioCtx.currentTime + 0.05); break;
    }
}


// --- 게임 흐름 관리 ---

// 1. 게임 초기화
function initGame() {
    gameState = 'setup';
    board = [];
    placementTurn = 0;
    currentPlayer = '쥐';
    currentTurn = 1;
    mousePosition = null;
    keeperPositions = [null, null, null];
    mousePath = [];
    foundFootprints = [];

    const oldRestartButton = document.querySelector('#game-info button:not(#next-turn-btn)');
    if(oldRestartButton) oldRestartButton.remove();
    
    nextTurnBtn.classList.add('hidden');
    boardElement.removeEventListener('click', handleGameClick);
    boardElement.addEventListener('click', handleSetupClick);
    nextTurnBtn.removeEventListener('click', startTurnAction);
    nextTurnBtn.addEventListener('click', startTurnAction);

    createBoard();
    updateGameInfo();
    renderBoard();
    updateMessageForSetup();
}

// 2. 설정(배치) 단계
function updateMessageForSetup() {
    const playerToPlace = playerOrder[placementTurn];
    let tileType = playerToPlace === '쥐' ? '창고' : '길 교차점';
    messageElement.textContent = `[위치선택] ${playerToPlace}, 배치할 ${tileType}을 클릭하세요.`;
}

function handleSetupClick(event) {
    playSound('click');
    const tile = event.target.closest('.tile');
    if (!tile) return;
    const x = parseInt(tile.dataset.x), y = parseInt(tile.dataset.y);
    const playerToPlace = playerOrder[placementTurn];

    if (playerToPlace === '쥐') {
        if (board[y][x] !== 'storage') { alert('쥐는 창고에만 배치할 수 있습니다.'); return; }
        mousePosition = {x, y};
        mousePath.push({x, y});
    } else {
        if (!isIntersection(x, y)) { alert('창고지기는 길의 교차점에만 배치할 수 있습니다.'); return; }
        if (keeperPositions.some(pos => pos && pos.x === x && pos.y === y)) { alert('다른 창고지기가 이미 있는 위치입니다.'); return; }
        keeperPositions[placementTurn - 1] = {x, y};
    }

    placementTurn++;
    
    if (placementTurn >= playerOrder.length) {
        endSetup();
    } else {
        currentPlayer = playerOrder[placementTurn];
        updateMessageForSetup();
        renderBoard();
    }
}

// 3. 설정 종료 및 첫 턴 준비
function endSetup() {
    boardElement.removeEventListener('click', handleSetupClick);
    gameState = 'transition';
    messageElement.textContent = '모든 배치가 완료되었습니다. 게임을 시작하세요.';
    nextTurnBtn.textContent = '게임 시작';
    nextTurnBtn.classList.remove('hidden');
    renderBoard();
}

// 4. 플레이어 행동 처리
function handleGameClick(event) {
    const tile = event.target.closest('.tile');
    if (!tile) return;
    const x = parseInt(tile.dataset.x), y = parseInt(tile.dataset.y);

    if (currentPlayer === '쥐') handleMouseTurn(x, y);
    else if (currentPlayer.startsWith('창고지기')) handleKeeperTurn(x, y);
}

function handleMouseTurn(x, y) {
    if (board[y][x] !== 'storage') { return; }
    const dx = Math.abs(mousePosition.x - x), dy = Math.abs(mousePosition.y - y);
    if (!((dx === 2 && dy === 0) || (dx === 0 && dy === 2))) { return; }
    if (mousePath.some(p => p.x === x && p.y === y)) { return; }
    
    playSound('move');
    mousePosition = {x, y};
    mousePath.push({x, y});
    advanceToNextPlayer();
}

function handleKeeperTurn(x, y) {
    const keeperIndex = parseInt(currentPlayer.replace('창고지기', '')) - 1;
    const keeperPos = keeperPositions[keeperIndex];

    if (board[y][x] === 'road') { // 이동
        if (!isIntersection(x, y)) { return; }
        const dx = Math.abs(keeperPos.x - x), dy = Math.abs(keeperPos.y - y);
        if (!((dx === 2 && dy === 0) || (dx === 0 && dy === 2))) { return; }
        if (keeperPositions.some(pos => pos && pos.x === x && pos.y === y)) { return; }
        
        playSound('move');
        keeperPositions[keeperIndex] = {x, y};
        advanceToNextPlayer();
    } else if (board[y][x] === 'storage') { // 확인
        const dx = Math.abs(keeperPos.x - x), dy = Math.abs(keeperPos.y - y);
        if (!(dx === 1 && dy === 1)) { return; }
        
        if (mousePosition.x === x && mousePosition.y === y) { endGame(true); return; }
        
        if (mousePath.some(p => p.x === x && p.y === y)) {
            playSound('footprint');
            alert('쥐의 흔적을 발견했습니다!');
            if (!foundFootprints.some(p => p.x === x && p.y === y)) foundFootprints.push({x, y});
        } else {
            playSound('check');
            alert('아무것도 없습니다.');
        }
        advanceToNextPlayer();
    }
}

// 5. 턴 관리
function advanceToNextPlayer() {
    const currentPlayerIndex = playerOrder.indexOf(currentPlayer);

    if (currentPlayer === '창고지기3') {
        gameState = 'transition';
        boardElement.removeEventListener('click', handleGameClick);
        messageElement.textContent = `턴 ${currentTurn} 종료. 다음 턴을 시작하려면 버튼을 누르세요.`;
        
        currentPlayer = '';
        lenderCurrentPlayer();
        
        nextTurnBtn.textContent = '다음 턴 시작';
        nextTurnBtn.classList.remove('hidden');
    } else {
        currentPlayer = playerOrder[currentPlayerIndex + 1];
        messageElement.textContent = `[${currentPlayer} 턴] 행동할 타일을 클릭하세요.`;
        lenderCurrentPlayer();
    }
    renderBoard();
}

function lenderCurrentPlayer() {
    currentPlayerElement.innerHTML = '';
    
    const svgImage = document.createElement('img');
	let svgImagePath = '';
	
    if (currentPlayer === '쥐') svgImagePath = 'icons/mouse.svg';
    else if (currentPlayer.startsWith('창고지기')) {
		const keeperIndex = parseInt(currentPlayer.replace('창고지기', '')) - 1;
		svgImagePath = `icons/keeper_${keeperIndex + 1}.svg`;
	}
	
	svgImage.src = svgImagePath;    	
	currentPlayerElement.appendChild(svgImage);
	//console.log(svgImagePath);			
}

function startTurnAction() {
    playSound('click');
    
    if (gameState === 'transition') {
        if (nextTurnBtn.textContent === '게임 시작') {
            // 첫 시작
            gameState = 'playing';
            currentPlayer = '쥐';
            boardElement.addEventListener('click', handleGameClick);          
        } else {
            // 다음 라운드 시작
            currentTurn++;
            if (currentTurn > MAX_TURNS) {
                endGame(false);
                return;
            }
            gameState = 'playing';
            currentPlayer = '쥐';
            boardElement.addEventListener('click', handleGameClick);
        }
        
		lenderCurrentPlayer();
    }
    
    messageElement.textContent = `[${currentPlayer} 턴] 행동할 타일을 클릭하세요.`;
    nextTurnBtn.classList.add('hidden');
    updateGameInfo();
    renderBoard();
}

// 6. 게임 종료
function endGame(isKeeperWin) {
    gameState = 'ended';
    boardElement.removeEventListener('click', handleGameClick);
    boardElement.removeEventListener('click', handleSetupClick);
    nextTurnBtn.classList.add('hidden');
    
    if (isKeeperWin) {
        playSound('win');
        messageElement.textContent = `${currentPlayer}이(가) 쥐를 찾았습니다! 창고지기 팀 승리!`;
    } else {
        playSound('lose');
        messageElement.textContent = '10턴 동안 쥐를 찾지 못했습니다! 쥐 승리!';
    }
    alert(messageElement.textContent);
    renderBoard();
    
    const restartButton = document.createElement('button');
    restartButton.textContent = '다시 시작';
    restartButton.onclick = () => { playSound('click'); initGame(); };
    document.getElementById('game-info').appendChild(restartButton);
}

// --- 유틸리티 함수 ---

function createBoard() {
    for (let row = 0; row < BOARD_SIZE; row++) {
        board[row] = [];
        for (let col = 0; col < BOARD_SIZE; col++) {
        	if (row % 2 == 0)
        	{
        		board[row][col] = (col % 2 === 1) ? 'road' : 'storage';
        	}
        	else {
        		board[row][col] = 'road';		
			}            
        }
    }
}

function isIntersection(x, y) {
    if (board[y][x] !== 'road') return false;
    const diagonals = [{dx: -1, dy: -1}, {dx: 1, dy: -1}, {dx: -1, dy: 1}, {dx: 1, dy: 1}];
    for (const d of diagonals) {
        const nx = x + d.dx, ny = y + d.dy;
        if (nx < 0 || nx >= BOARD_SIZE || ny < 0 || ny >= BOARD_SIZE || board[ny][nx] !== 'storage') return false;
    }
    return true;
}

function renderBoard() {
    boardElement.innerHTML = '';
    const isMouseVisible = (gameState === 'playing' && currentPlayer === '쥐') ||
                           (gameState === 'setup' && playerOrder[placementTurn] === '쥐') ||
                           gameState === 'ended';

    for (let r = 0; r < BOARD_SIZE; r++) {
        for (let c = 0; c < BOARD_SIZE; c++) {
			//console.log(`(${r}, ${c})`)
            const tile = document.createElement('div');
            tile.classList.add('tile');
            tile.dataset.x = c;
            tile.dataset.y = r;

            const isMouseHere = mousePosition && mousePosition.x === c && mousePosition.y === r;
            const keeper = keeperPositions.find(k => k && k.x === c && k.y === r);
            const isFoundFootprint = foundFootprints.some(p => p.x === c && p.y === r);

            // Layer 1: 기본 타일 또는 발자국
            if (isFoundFootprint && !isMouseHere) {
                const footprintIndexOnPath = mousePath.findIndex(p => p.x === c && p.y === r);
                if (footprintIndexOnPath === 0) tile.classList.add('footprint-yellow');
                else if (footprintIndexOnPath === 4) tile.classList.add('footprint-red');
                else tile.classList.add('footprint-grey');
            } else {
                tile.classList.add(board[r][c]);
            }

            // Layer 2: 창고지기 (항상 표시)
            if (keeper) {
                const keeperIndex = keeperPositions.indexOf(keeper);
                const keeperElement = document.createElement('div');
                keeperElement.classList.add(`keeper-${keeperIndex + 1}`);
                tile.appendChild(keeperElement);
            }

            // Layer 3: 쥐 (조건부 표시)
            if (isMouseVisible && isMouseHere) {
                tile.classList.add('mouse');
            }
            
            // Layer 4: 잡힌 쥐 효과
            if (gameState === 'ended' && isMouseHere) {
                tile.classList.add('mouse-caught');
            }

            boardElement.appendChild(tile);
        }
    }
}

function updateGameInfo() {
    turnCounterElement.textContent = `${currentTurn}`;
    //currentPlayerElement.textContent = currentPlayer;
}

// 초기 게임 시작
initGame();
