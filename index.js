// import _times from "lodash/times";

//HTML page environement variables
var fleet = document.querySelector('#fleet');
var fleetBoxes;
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
var gameOver = false;
var accounts;
var betAmount;

var timerStarted = false;
var startTime;

const GRID_SIZE = 10;

const SHIP_CARRIER = 5;
const SHIP_BATTLESHIP = 4;
const SHIP_CRUISER = 3;
const SHIP_SUBMARINE = 3;
const SHIP_DESTROYER = 2;

const SHIPS_SIZES = [SHIP_CARRIER, SHIP_BATTLESHIP, SHIP_CRUISER, SHIP_SUBMARINE, SHIP_DESTROYER];


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
    
    displayGrid();

    
    fleetBoxes = fleet.querySelectorAll('li');
    targetsBoxes = targets.querySelectorAll('li');

    //events listeners for user to click on the board
    for(var i = 0; i < 10*10; i++) {
        // fleetBoxes[i].addEventListener('click', clickHandler, false);
        targetsBoxes[i].addEventListener('click', clickHandler, false);
    }
    renderInterval = setInterval(render, 1000);
    render();
}

var displayGrid = function (){
    fleet.innerHTML = "";
    targets.innerHTML = "";
    for(var i = 0; i < GRID_SIZE ** 2; i++) {
        fleet.innerHTML += "<li data-pos-x=\"" + i +"\"></li>";
        targets.innerHTML += "<li data-pos-x=\"" + i +"\" data-pos-y=\"" + j + "\"></li>";
    }
}

var createGrid = function(empty = false){
    const grid = createEmptyGrid(GRID_SIZE);

    if (empty) {
        return grid;
    }

    const ships = getShips();

    for (var i = 0; i < 5; i++) {
        const ship = ships[i];

        placeShipAt(grid, i, ship[0], ship[1], ship[2]);
        

        if (ship[0] > GRID_SIZE || ship[1] > GRID_SIZE) {
            throw new Error("Out of bounds");
        }
        
  }

  return grid;
}


var getShips = function() {
    const ships = new Array(5);

    for (var i = 0; i < 5; i++){
        const shipRow = parseInt(document.getElementById('ship-'+ i +'-row').value);
        const shipCol = parseInt(document.getElementById('ship-'+ i +'-col').value);
        const shipDir = parseInt(document.getElementById('ship-'+ i +'-dir').value);
        ships[i] = [shipRow, shipCol, shipDir]
    }
    return ships;
}

var placeShipAt = function(grid, shipI, x, y, isVertical) {
  
    const indexes = _times(SHIPS_SIZES[shipI])
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

var pointToIndex = function(point) {
    const [x, y] = point;
    return y * GRID_SIZE + x;
  }

var createEmptyGrid = function(){
  const grid = [];

  for (let i = 0; i < GRID_SIZE ** 2; i++) {
    grid.push(0);
  }

  return grid;
}

var checkWin = function(){

    //checks the contract on the blockchain to verify if there is a winner or not
    if (typeof Battleships != 'undefined'){
        var win;
        Battleships.status().then(function(res){
            win = res[0].words[0];
            // console.log(win)
            var displayResult;
            // statusDisplay.innerHTML = "Status: " + win
            if (win>0 && win<4){
                if (win==3){
                    displayResult = "Draw ! game is over";
                } else if (win == 2){
                    displayResult = "Player 2 wins ! game is over";
                } else if (win == 1) {
                    displayResult = "Player 1 wins ! game is over";
                }
                gameOver = true;
                document.querySelector('#game-messages').innerHTML = displayResult;

                for(var i = 0; i < 4; i++) {
                    for(var j = 0; j < 4*4; j++) {
                        games[i][j].removeEventListener('click', clickHandler);
                    }
                }

                return true;
            } else if (win == 0){
                document.querySelector('#game-messages').innerHTML = "Waiting for players...";
            } else if (win == 4) {
                document.querySelector('#game-messages').innerHTML = "Game in progress..."
                if (!timerStarted) {
                    start = Date.now();
                    timerStarted = true;
                    // document.querySelector('#timeout').innerHTML = "<button class=\"buttons\" id=\"timeoutOn\" onclick=\"timeoutHandler()\">Claim Opponent Timeout</button>"
                }
            }
        });
    }

    return false;
}


var render = function(){

    //renders the board byt fetching the state of the board from the blockchain
    if (typeof Battleships != 'undefined'){
        Battleships.showFleet(1).then(function(res){
            console.log(res[0][0][0].toNumber());
            for (var i = 0; i < 10; i++){
                for (var j = 0; j < 10; j++){
                    var state = res[0][i][j].toNumber();
                    
                    if (state > 0){
                        console.log(state);
                        var box_i = 4 * i + j;
                        fleetBoxes[box_i].className = 'x';
                        fleetBoxes[box_i].innerHTML = state;
                    }
                }   
            }
        });

        // Battleships.showTargets(1).then(function(res){
        //     for (var i = 0; i < 10; i++){
        //         for (var j = 0; j < 10; j++){
        //             var state = res[0][i][j].toNumber();
                    
        //             if (state > 0){
        //                 console.log(state);
        //                 var box_i = 4 * i + j;
        //                 targetsBoxes[box_i].className = 'x';
        //                 targetsBoxes[box_i].innerHTML = state;
        //             }
        //         }   
        //     }
        // });


        checkWin();

        if (!gameOver){
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
    timerDisplay.innerHTML = Math.floor((Date.now() - start)/ 1000);
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
    Battleships.turn().then(function(res){
        if (res[0].words[0] == player){
            turnDisplay.innerHTML = "Your turn Player " + res[0].words[0] + "!";
            document.querySelector('#timeout').innerHTML = "<button class=\"buttons\" id=\"timeout\" onclick=\"timeoutHandler()\" disabled>Claim Opponent Timeout</button>"
        } else {
            turnDisplay.innerHTML = "Not your turn! It's Player " + res[0].words[0] + "'s turn!";
            document.querySelector('#timeout').innerHTML = "<button class=\"buttons\" id=\"timeout\" onclick=\"timeoutHandler()\">Claim Opponent Timeout</button>"
        }
    });
}

var newGameHandler = function(){

    //creates a new contract based on the user input of their opponent's address
    if (typeof Battleships != 'undefined'){
        console.log("There seems to be an existing game going on already");
    } else{
        var opponentAddress = document.getElementById('opponent-address').value
        betAmount = document.getElementById('bet-amount').value;

        


        console.log(opponentAddress)
        console.log(fleetRow, fleetCol, fleetDir)
        BattleshipsContract.new(opponentAddress, fleetRow, fleetCol, fleetDir, { from: accounts[0], gas: '3000000',  value: web3.utils.toWei(betAmount.toString(), "ether")})
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
                    }
                })
            }, 300);
        
        })
        
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
    Battleships.join({ from: accounts[0], gas: '3000000',  value: web3.utils.toWei(betAmount.toString(), "ether")}).then(function(res) {
        Battleships.walletToPlayer(accounts[0]).then(function(res) {
            player = res[0]
            document.querySelector('#player').innerHTML = "Player " + player;
        });
        document.querySelector('#bet-amount-field-join').innerHTML = "Game of " + betAmount + " ETH stakes joined."

        startTime = Date.now()
    });
    
}

var endGameHandler = function(){
    document.querySelector('#timeout').innerHTML = ""
    turnDisplay.innerHTML = ""
    // Battleships.paidWinner().then(function(res){
    //     document.querySelector('#winner-paid').innerHTML = "Winner paid: " + res[0];
    // });
}

var clickHandler = function() {

    //called when the user clicks a cell on the board

    if (typeof Battleships != 'undefined'){
        if (checkWin()){
            return;
        }
        var target_x = this.getAttribute('data-pos-x');
        var target_y = this.getAttribute('data-pos-y');
        var target_z = this.getAttribute('data-pos-z');
        Battleships.validMove(target_x, target_y, target_z).then(function(res){
            if (res[0]) {
                Battleships.turn().then(function(res) {
                    if (res[0].words[0] == player) {
                        TicTacToe.move(target_x, target_y, target_z).catch(function(err){
                            console.log('something went wrong ' + String(err));
                        }).then(function(res){
                            this.removeEventListener('click', clickHandler);
                            render();
                        });
                    }
                });
            }
        });
    }
}

init();
