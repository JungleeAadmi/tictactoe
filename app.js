// Tic Tac Toe Game
let board = ['', '', '', '', '', '', '', '', ''];
let currentPlayer = 'X';
let gameActive = true;

const winningConditions = [
    [0, 1, 2],
    [3, 4, 5], 
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
];

// DOM Elements
let cells;
let currentPlayerDisplay;
let modal;
let winMessage;
let winSubtext;
let playAgainBtn;

// Initialize game when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('Initializing game...');
    
    // Get DOM elements
    cells = document.querySelectorAll('.cell');
    currentPlayerDisplay = document.getElementById('currentPlayer');
    modal = document.getElementById('winModal');
    winMessage = document.getElementById('winMessage');
    winSubtext = document.getElementById('winSubtext');
    playAgainBtn = document.getElementById('playAgainBtn');
    
    console.log('Found', cells.length, 'cells');
    
    // Add click listeners to cells
    cells.forEach((cell, index) => {
        cell.addEventListener('click', () => handleCellClick(index));
        console.log('Added listener to cell', index);
    });
    
    // Add restart button listener
    if (playAgainBtn) {
        playAgainBtn.addEventListener('click', restartGame);
    }
    
    // Initialize display
    updateDisplay();
    console.log('Game initialized successfully');
});

function handleCellClick(index) {
    console.log('Cell clicked:', index, 'Current player:', currentPlayer);
    
    // Check if cell is already occupied or game is not active
    if (board[index] !== '' || !gameActive) {
        console.log('Invalid move - cell occupied or game not active');
        return;
    }
    
    // Make the move
    makeMove(index);
    
    // Check for win
    if (checkWin()) {
        console.log(currentPlayer + ' wins!');
        endGame(false);
    } else if (checkDraw()) {
        console.log('Game is a draw!');
        endGame(true);
    } else {
        // Switch players
        currentPlayer = currentPlayer === 'X' ? 'O' : 'X';
        updateDisplay();
    }
}

function makeMove(index) {
    // Update board state
    board[index] = currentPlayer;
    
    // Update cell display
    const cell = cells[index];
    cell.textContent = currentPlayer;
    cell.classList.add(currentPlayer.toLowerCase());
    cell.classList.add('occupied');
    
    // Add animation
    cell.style.transform = 'scale(1.1)';
    setTimeout(() => {
        cell.style.transform = 'scale(1)';
    }, 150);
    
    console.log('Move made:', currentPlayer, 'at position', index);
    console.log('Board state:', board);
}

function updateDisplay() {
    if (currentPlayerDisplay) {
        currentPlayerDisplay.textContent = currentPlayer;
        currentPlayerDisplay.style.color = currentPlayer === 'X' ? 'var(--color-primary)' : 'var(--color-warning)';
    }
}

function checkWin() {
    for (let condition of winningConditions) {
        const [a, b, c] = condition;
        if (board[a] && board[a] === board[b] && board[a] === board[c]) {
            highlightWinningCells(condition);
            return true;
        }
    }
    return false;
}

function checkDraw() {
    return board.every(cell => cell !== '');
}

function highlightWinningCells(winningCondition) {
    winningCondition.forEach(index => {
        cells[index].classList.add('winning');
    });
}

function endGame(isDraw) {
    gameActive = false;
    
    setTimeout(() => {
        if (isDraw) {
            winMessage.textContent = "It's a Draw!";
            winSubtext.textContent = "Great game! Try again?";
        } else {
            winMessage.textContent = currentPlayer + " Wins!";
            winSubtext.textContent = "Congratulations!";
        }
        
        showModal();
    }, 500);
}

function showModal() {
    if (modal) {
        modal.classList.remove('hidden');
        console.log('Modal shown');
    }
}

function hideModal() {
    if (modal) {
        modal.classList.add('hidden');
        console.log('Modal hidden');
    }
}

function restartGame() {
    console.log('Restarting game...');
    
    // Hide modal
    hideModal();
    
    // Reset game state
    board = ['', '', '', '', '', '', '', '', ''];
    currentPlayer = 'X';
    gameActive = true;
    
    // Clear all cells
    cells.forEach(cell => {
        cell.textContent = '';
        cell.className = 'cell';
    });
    
    // Update display
    updateDisplay();
    
    console.log('Game restarted');
}

// Add keyboard support
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && modal && !modal.classList.contains('hidden')) {
        restartGame();
    }
    
    // Number keys 1-9 for cell selection
    if (gameActive && event.key >= '1' && event.key <= '9') {
        const cellIndex = parseInt(event.key) - 1;
        if (board[cellIndex] === '') {
            handleCellClick(cellIndex);
        }
    }
});