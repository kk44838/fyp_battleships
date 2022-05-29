// import _times from "lodash/times";

const GRID_SIZE_DEV = 3;
const GRID_SIZE_STANDARD = 10;

const SHIP_CARRIER = 5;
const SHIP_BATTLESHIP = 4;
const SHIP_CRUISER = 3;
const SHIP_SUBMARINE = 3;
const SHIP_DESTROYER = 2;

const SHIPS_SIZES = [SHIP_CARRIER, SHIP_BATTLESHIP, SHIP_CRUISER, SHIP_SUBMARINE, SHIP_DESTROYER];

const GAME_NOT_STARTED = 0;
const GAME_READY = 1;
const GAME_STARTED = 2;
const GAME_FINISHED = 3;
const GAME_DONE = 4;

const HIT = 1;
const MISS = 2;

//HTML page environement variables
var ship = document.querySelector('#ships');
var shipBoxes;
var targets = document.querySelector('#targets');
var targetsBoxes;

var timerDisplay = document.getElementById('timer');
var turnDisplay = document.getElementById('whos-turn');
var statusDisplay = document.getElementById('game-status');
var gameMessages = document.getElementById('game-messages');
var newGame = document.getElementById('new-game');
var joinGame = document.getElementById('join-game');

// var startGame;
var player;
var gameFinished = false;
var accounts;
var betAmount;

var timerStarted = false;
var revealStarted = false;
var startTime;

var shipsGrid;
var shipsHits;

var targetsGrid;
var targetsHits;

var secret;
var salt;

var GRID_SIZE = GRID_SIZE_STANDARD;


if (typeof web3 !== 'undefined') {
    web3 = new Web3(web3.currentProvider);
} else {
    //this Dapp requires the use of metamask
    alert('please install metamask')
}
const eth = new Eth(web3.currentProvider);

var BattleshipsContract;
var Battleships;

//Play functions
var init = async function() {
    let response = await fetch('/artifacts/contracts/Battleships.sol/Battleships.json');
    const data = await response.json()
    const abi = data.abi
    const byteCode = data.bytecode

    accounts = await ethereum.request({ method: 'eth_requestAccounts' });
    console.log("The account is " + accounts[0])
    BattleshipsContract = eth.contract(abi, byteCode, { from: accounts[0], gas: '3000000' });

    ethereum.on('accountsChanged', async function (accounts) {
        accounts = await ethereum.request({ method: 'eth_requestAccounts' });
        BattleshipsContract = eth.contract(abi, byteCode, { from: accounts[0], gas: '3000000' });
    });
    
    
    //the user can first create or join a game
    newGame.addEventListener('click',newGameHandler,false);
    joinGame.addEventListener('click',joinGameHandler, false);
    

    shipsHits = createGrid(true);
    targetsGrid = createGrid(true);
    targetsHits = createGrid(true);

    renderInterval = setInterval(render, 1000);
    render();
}

function displayGrid(){
    ship.innerHTML = "";
    targets.innerHTML = "";
    for(var i = 0; i < GRID_SIZE ** 2; i++) {
        ship.innerHTML += "<li data-pos-x=\"" + i +"\"></li>";
        targets.innerHTML += "<li data-pos-x=\"" + i +"\"></li>";
    }

    shipBoxes = ship.querySelectorAll('li');
    targetsBoxes = targets.querySelectorAll('li');

    //events listeners for user to click on the board
    for(var i = 0; i < GRID_SIZE ** 2; i++) {
        if (GRID_SIZE == GRID_SIZE_DEV) {
            shipBoxes[i].className = "dev";
            targetsBoxes[i].className = "dev";
        }
        
        targetsBoxes[i].addEventListener('click', clickTargetHandler, false);
    }
}

function createGrid(empty = false){
    const grid = createEmptyGrid();

    if (empty) {
        return grid;
    }

    const ships = getShips();

    for (var i = 0; i < ships.length; i++) {
        const ship = ships[i];

        placeShipAt(grid, i, ship[0], ship[1], ship[2]);
        

        if (ship[0] > GRID_SIZE || ship[1] > GRID_SIZE) {
            throw new Error("Out of bounds");
        }
        
  }

  return grid;
}


function getShips() {
    const ships = [];
    var numShips = 5;
    if (GRID_SIZE === GRID_SIZE_DEV) {
        numShips = 1;
    }

    for (var i = 0; i < numShips; i++){
        const shipRow = parseInt(document.getElementById('ship-'+ i +'-row').value);
        const shipCol = parseInt(document.getElementById('ship-'+ i +'-col').value);
        const shipDir = parseInt(document.getElementById('ship-'+ i +'-dir').value);
        ships.push([shipRow, shipCol, shipDir]);
    }
    return ships;
}

function placeShipAt(grid, shipI, x, y, isVertical) {
    const sizeOfShips = GRID_SIZE === GRID_SIZE_DEV ? [SHIP_DESTROYER] : SHIPS_SIZES;


    const indexes = Array.from({length: sizeOfShips[shipI]}, (_,x) => x)
      .map(i => [isVertical ? x : x + i, isVertical ? y + i : y])
      .map(point => pointToIndex(point));
  
    // IF: all positions are available
    if (indexes.every(i => grid[i] === 0)) {
      // Place ship on grid
      indexes.forEach(i => {
        grid[i] = shipI + 1;
      });
  
      return true;
    }
  
    return false;
  }

function pointToIndex (point) {
    const [x, y] = point;
    return x * GRID_SIZE + y;
  }

function createEmptyGrid(){
  const grid = [];

  for (let i = 0; i < GRID_SIZE ** 2; i++) {
    grid.push(0);
  }

  return grid;
}

function obfuscate(ships) {
    const salt = web3.utils.sha3(shuffle(ships).join(""));
    const secret = web3.utils.sha3(ships.join("") + salt);
  
    return [secret, salt];
}


function shuffle(array) {
    return array
            .map(value => ({ value, sort: Math.random() }))
            .sort((a, b) => a.sort - b.sort)
            .map(({ value }) => value);
}

function displayShips(){
    for (let i = 0; i < GRID_SIZE ** 2; i++) {
        if (shipsGrid[i] > 0){
            shipBoxes[i].innerHTML = shipsGrid[i];
            shipBoxes[i].className += " ship";
        }
    }
}

var checkWin = function(){

    //checks the contract on the blockchain to verify if there is a winner or not
    if (typeof Battleships != 'undefined'){
        var win;
        Battleships.status().then(function(res){
            win = res[0].words[0];
            // 0 - Not started
            // 1 - Game Ready
            // 2 - Ongoing
            // 3 - finished
            // 4 - done

            if (win == GAME_NOT_STARTED) {
                document.querySelector('#game-messages').innerHTML = "Waiting for players...";
            } else if (win == GAME_READY) {
                document.querySelector('#game-messages').innerHTML = "Waiting for first attack!";
            } else if (win == GAME_STARTED) {
                document.querySelector('#game-messages').innerHTML = "Game in progress..."
                if (!timerStarted) {
                    startTime = Date.now();
                    timerStarted = true;
                }
            } else if (win == GAME_FINISHED) {
                if (!revealStarted) {
                    startTime = Date.now();
                    revealStarted = true;
                }
                gameFinished = true;
                document.querySelector('#game-messages').innerHTML = "Game finished, reveal your ships: " 
                                        +"<button class=\"buttons\" id=\"reveal\" onclick=\"revealShipsHandler()\">Reveal Your Ships</button>"
            } else if (win == GAME_DONE) {
                gameFinished = true;
                Battleships.winner().then(function(res){
                    Battleships.walletToPlayer(res[0]).then(function(res){
                        document.querySelector('#game-messages').innerHTML = "Player " + res[0] + " wins ! Game is over";

                    });
                });
                
                for(var i = 0; i < GRID_SIZE ** 2; i++) {
                    targetsBoxes[i].removeEventListener('click', clickTargetHandler);
                }
                return true;
            }
        });
    }

    return false;
}


var render = function(){

    //renders the board byt fetching the state of the board from the blockchain
    if (typeof Battleships != 'undefined'){

        Battleships.showTargets(accounts[0]).then(function(res){
            for (var i = 0; i < GRID_SIZE ** 2; i++){
                targetsHits[i] = res[0][i].words[0];
                var className = GRID_SIZE === GRID_SIZE_DEV ? "dev " : "";

                if (targetsHits[i] == 1) {
                    targetsBoxes[i].className = className + 'shipHit';
                } else if (targetsHits[i] == 2) {
                    targetsBoxes[i].className = className + 'shipMiss';
                }

                if (shipsHits[i] == 1){
                    shipBoxes[i].className = className + 'shipHit';
                } else if (shipsHits[i] == 2) {
                    shipBoxes[i].className = className + 'shipMiss';
                }
            }
        });

        const gameIsDone = checkWin();

        if (!gameIsDone){
            turnMessageHandler();
            
            if (timerStarted) {
                timerHandler();
            }

        } else {
            endGameHandler();
        }
    }
}

var timerHandler = function(){
    timerDisplay.innerHTML = Math.floor((Date.now() - startTime)/ 1000);
}

var timeoutHandler = function(){
    if (typeof Battleships != 'undefined'){
        if (checkWin()){
            return;
        }

        Battleships.unlockFundsAfterTimeout().then(function(res){
            document.querySelector('#timeout-messages').innerHTML = "Opponent exceeded timeout."
        }).catch(function(err) {
            document.querySelector('#timeout-messages').innerHTML = "Opponent has not exceeded timeout."
        });
    }
}

var turnMessageHandler = function(){
    if (typeof Battleships != 'undefined'){
        if (!gameFinished) {
            Battleships.turn().then(function(res){
                if (res[0] == accounts[0]){
                    turnDisplay.innerHTML = "Your turn Player " + player + "!";
                    document.querySelector('#timeout').innerHTML = "<button class=\"buttons\" id=\"timeout\" onclick=\"timeoutHandler()\" disabled>Claim Opponent Timeout</button>";
                } else {
                    turnDisplay.innerHTML = "Not your turn!";
                    //  It's Player " + res[0].words[0] + "'s turn!";
                    document.querySelector('#timeout').innerHTML = "<button class=\"buttons\" id=\"timeout\" onclick=\"timeoutHandler()\">Claim Opponent Timeout</button>";
                }
            });
        } else {
            turnDisplay.innerHTML = "";
            if (checkWin()){
                document.querySelector('#timeout').innerHTML = "";
            } else {
                document.querySelector('#timeout').innerHTML = "<button class=\"buttons\" id=\"timeout\" onclick=\"timeoutHandler()\">Claim Opponent Timeout</button>";
            }      
        }
    }
}

var newGameHandler = function(){

    //creates a new contract based on the user input of their opponent's address
    if (typeof Battleships != 'undefined'){
        console.log("There seems to be an existing game going on already");
    } else{
        var opponentAddress = document.getElementById('opponent-address').value
        betAmount = document.getElementById('bet-amount').value;

        var devMode = document.getElementById('dev').checked;
        
        if (devMode) {
            GRID_SIZE = GRID_SIZE_DEV;
        }

        shipsGrid = createGrid();
        [secret, salt] = obfuscate(shipsGrid);

        
        BattleshipsContract.new(opponentAddress, secret, GRID_SIZE, { from: accounts[0], gas: '3000000',  value: web3.utils.toWei(betAmount.toString(), "ether")})
        .then(function(txHash) {
            var waitForTransaction = setInterval(function(){
                eth.getTransactionReceipt(txHash, function(err, receipt){
                    if (receipt) {
                        clearInterval(waitForTransaction);
                        Battleships = BattleshipsContract.at(receipt.contractAddress);
                        //display the contract address to share with the opponent
                        
                        document.querySelector('#new-game-address').innerHTML = "BET AMOUNT OF " + betAmount + " PLACED <br><br>" 
                        + "Share the contract address with your opponnent: " + String(Battleships.address) + "<br><br>";
                        player = 1;
                        document.querySelector('#player').innerHTML = "Player 1";
                        displayGrid();
                        displayShips();

                    }
                })
            }, 300);
        
        })
        
    }
}

var revealShipsHandler = function() {
    if (typeof Battleships != 'undefined'){
        Battleships.reveal(shipsGrid.join(''),salt).then(function(res){
            document.querySelector('#game-messages').innerHTML = "Your ships have been revealed, waiting on other player to reveal..."
        });
    }
}

var joinGameHandler = function(){
    //idem for joining a game
    var contractAddress = document.getElementById('contract-ID-tojoin').value.trim();
    Battleships = BattleshipsContract.at(contractAddress);

    Battleships.betAmount().then(function(res) {
        console.log(res)
        betAmount = web3.utils.fromWei(res[0].toString(), 'ether');
        if (betAmount == 0) {
            document.querySelector('#bet-amount-field-join').innerHTML = "Try Again..."
        } else {
            document.querySelector('#bet-amount-field-join').innerHTML = 
            "Bet Amount of " + betAmount + " requried to join game. <button class=\"buttons\" id=\"start-game\" onclick=\"joinGameConfirmHandler()\">Confirm</button> <br><br>"
        }
        
    });
    
}

var joinGameConfirmHandler = function(){

    shipsGrid = createGrid();
    [secret, salt] = obfuscate(shipsGrid);

    Battleships.join(secret, { from: accounts[0], gas: '3000000',  value: web3.utils.toWei(betAmount.toString(), "ether")}).then(function(res) {
        Battleships.gridSize().then(function(res) {
            player = 2;
            document.querySelector('#player').innerHTML = "Player 2";
            document.querySelector('#bet-amount-field-join').innerHTML = "Game of " + betAmount + " ETH stakes joined."

            size = res[0];

            GRID_SIZE = size == GRID_SIZE_DEV ? GRID_SIZE_DEV : GRID_SIZE_STANDARD;
            displayGrid();
            displayShips();

            startTime = Date.now();
        });
        
    });
    
}

var endGameHandler = function(){
    document.querySelector('#timeout').innerHTML = "";
    turnDisplay.innerHTML = "";
}

var clickTargetHandler = function() {

    //called when the user clicks a cell on the board

    if (typeof Battleships != 'undefined'){
        if (checkWin()){
            return;
        }
        var target = this.getAttribute('data-pos-x');
        Battleships.validMove(target).then(function(isValidMove){
            if (isValidMove[0]) {
                Battleships.turn().then(function(whoseTurn) {
                    if (whoseTurn[0] == accounts[0]) {
                        Battleships.status().then(function(curStatus){
                            if (curStatus[0].toNumber() == GAME_READY) {
                                Battleships.attack(target).catch(function(err){
                                    console.log('something went wrong ' + String(err));
                                }).then(function(res){
                                    targetsBoxes[target].className += ' shipAttack';
                                    this.removeEventListener('click', clickTargetHandler);
                                    render();
                                });
                            } else if (curStatus[0].toNumber() == GAME_STARTED) {
                                Battleships.targetIndex().then(function(res) {
                                    console.log(res[0].toNumber())
                                    targetIndex = res[0].toNumber();

                                    var wasHit = false;
                                    if (shipsGrid[targetIndex] > 0) {
                                        wasHit = true;
                                    }

                                    Battleships.counterAttack(target, wasHit).catch(function(err){
                                        console.log('something went wrong ' + String(err));
                                    }).then(function(res){
                                        if (wasHit) {
                                            shipsHits[targetIndex] = HIT;
                                        } else {
                                            shipsHits[targetIndex] = MISS;
                                        }
                                        
                                        targetsBoxes[target].className += ' shipAttack';
                                        this.removeEventListener('click', clickTargetHandler);
                                        render();
                                    });
                                });
                                
                            }
                        });
                    }
                });
            }
        });
    }
}

init();
