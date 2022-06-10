//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.24;

/**
 * @title Battleships contract
 **/
contract Battleships {
    // Target hit or miss values
    uint8 constant HIT = 1;
    uint8 constant MISS = 2;

    uint8 constant GRID_STANDARD = 10;
    uint8 constant GRID_DEV = 3;

    // Status constants
    uint8 constant GAME_NOT_STARTED = 0;
    uint8 constant GAME_READY = 1;
    uint8 constant GAME_STARTED = 2;
    uint8 constant GAME_FINISHED = 3;
    uint8 constant GAME_DONE = 4;

    // Ship size constants
    uint8 constant SHIP_PATROL_BOAT = 2;
    uint8 constant SHIP_SUBMARINE = 3;
    uint8 constant SHIP_DESTROYER = 3;
    uint8 constant SHIP_BATTLESHIP = 4;
    uint8 constant SHIP_CARRIER = 5;
    
    
    uint8 constant SHIP_SIZES = [SHIP_PATROL_BOAT, SHIP_SUBMARINE, SHIP_DESTROYER, SHIP_BATTLESHIP, SHIP_CARRIER];


    uint public gridSize;

    address[2] public players;

    uint public playersJoined;

    mapping(address => uint8) public walletToPlayer;

    address public winner;

    /**
      Amount to bet
     */
    uint public betAmount;

    /**
     turn
     address of whos turn it is 
     */
    address public turn;

    uint8 public status = GAME_NOT_STARTED;

    uint public targetIndex;

    mapping (address => bytes32) secretsLocation;
    mapping (address => bytes32) secretsGrid;
    mapping (address => string) shipsLocation;
    mapping (address => string) shipsGrid;
    mapping (address => uint8[]) public targets;
    mapping (address => bool) cheated;

      /**
      Join Game Timeout
     */
    uint256 joinTimeout = 5 minutes;
    uint256 joinDeadline;

    /**
      Move Timeout
     */
    uint256 timeout = 1.5 minutes;
    uint256 nextTimeoutPhase;

        /**
      Reveal Timeout
     */
    uint256 revealTimeout = 5 minutes;
    uint256 nextRevealTimeoutPhase;

    // Modifiers


    /**
     * @dev ensure it's a msg.sender's turn
     * update the turn after a move
     */
    modifier _isPlayer {
      /*Please complete the code here.*/
      require(msg.sender == players[0] || msg.sender == players[1], "You are not a Player!");
      _;
    }

    modifier _isWinner {
      require(status == GAME_DONE);
      require(winner == msg.sender);
      _;
    }

    /**
     * @dev ensure it's a msg.sender's turn
     * update the turn after a move
     */
    modifier _myTurn {
      /*Please complete the code here.*/
      require(myTurn(), "Not your turn!");
      _;
    }

    /**
     * @dev ensure a move is made is valid before it is made
     */

    modifier _validMove(uint index) {
      /*Please complete the code here.*/
      require(validMove(index), "Invalid Move.");
      _;
    }   

    /**
     * @dev ensure a move is made before the timeout
     */

    modifier _checkTimeout {
      /*Please complete the code here.*/
      require(nextTimeoutPhase > now, "Took too long to make move.");
      _;
      nextTimeoutPhase = (now + timeout);
    }    

    /**
     * @dev ensure the ships are revealed before the timeout
     */

    modifier _checkRevealTimeout {
      /*Please complete the code here.*/
      require(nextRevealTimeoutPhase > now, "Took too long to make move.");
      _;
    } 

    modifier _checkJoinTimeout {
      /*Please complete the code here.*/
      require(joinDeadline > now, "Took too long to join.");
      _;
    }   

    /**
     * @dev ensure the game status is game ready
    */

    modifier _gameReady {
      /*Please complete the code here.*/
      require(status == GAME_READY, "Game not ready.");
      _;
    }  

    /**
     * @dev ensure the game status is game started
     */

    modifier _gameStarted {
      /*Please complete the code here.*/
      require(status == GAME_STARTED, "Game not ready.");
      _;
    }  

    modifier _gameFinished {
      /*Please complete the code here.*/
      require(status == GAME_FINISHED, "Game not finished.");
      _;
    } 

    modifier _notRevealed {
    require(bytes(shipsGrid[msg.sender]).length == 0);
    _;
  }

    // Events 

    /**
     * @dev `owner` Address who created the game
     * @dev `gridSize` The size of the target/ocean grid
     * @dev `bet` The amount of the bet
     */
    event GameCreated(address indexed owner, uint bet, uint gridSize);
    
    /**
     * @dev `owner` Address who created the game
     * @dev `challenger` Address who joined the open game
     * @dev `bet` The matching amount of the bet
     */
    event GameJoined(address indexed player1, address indexed player2, uint bet);
    
    /** 
     * @dev `attacker` Address who performed the attack
     * @dev `defender` Address who suffured the attack
     * @dev `index` Index of the attack
     */
    event Attack(address indexed player1, address indexed player2, uint index);

    /**
     * @dev `player1` Address who performed the attack
     * @dev `player2` Address who suffured the attack
     * @dev `index` Index of the attack
     * @dev `hit` Result of the attack
     */
    event AttackResult(address indexed player1, address indexed player2, uint index, bool wasHit);

    /**
     * @dev `winner` Address who won the game
     * @dev `opponent` Address of opponent player
     * @dev `void` If game is void (cheated)
     */

    event GameFinished(address indexed winner, address indexed opponent, bool void);
    /**
     * @dev `revealer` Address who revealed its ships positions
     * @dev `opponent` Address of opponent player
     * @dev `ships` Unobfuscated ships positions
     * @dev `void` If ships positions are void (cheated)
     */
     
    event GameRevealed(address indexed revealer, address indexed opponent, string ships, bool void);


    // Functions

    /**
      * @dev Deploy the contract to create a new game
      * @param opponent The address of player2
      **/
    constructor(address opponent, bytes32 secretGrid, bytes32 secretLocation, uint size) public payable {
      require(msg.sender != opponent, "No self play.");
      require(msg.value > 0, "Bet too small");

      turn = msg.sender;
      players[0] = msg.sender;
      players[1] = opponent;
      walletToPlayer[msg.sender] = 1;
      playersJoined = 1;
      betAmount = msg.value;

      gridSize = size;
      secretsGrid[msg.sender] = secretGrid;
      secretsLocation[msg.sender] = secretLocation;
      targets[msg.sender] = new uint8[](gridSize ** 2);

      joinDeadline = (now + joinTimeout);

      emit GameCreated(msg.sender, msg.value, size);
    }

    function join(bytes32 secretGrid, bytes32 secretLocation) external payable _checkJoinTimeout {
      require(msg.sender == players[1], "You are not an opponent.");
      require(playersJoined == 1, "Opponent already joined.");
      require(msg.value == betAmount, "Wrong bet amount.");

      walletToPlayer[msg.sender] = 2;
      secretsGrid[msg.sender] = secretGrid;
      secretsLocation[msg.sender] = secretLocation;
      targets[msg.sender] = new uint8[](gridSize ** 2);      
      playersJoined = 2;
      betAmount += msg.value;

      nextTimeoutPhase = (now + timeout);
      status = GAME_READY;

      emit GameJoined(players[0], msg.sender, msg.value);
    }


    function firstAttack(uint index) public _gameReady _validMove(index) _checkTimeout _myTurn {
      status = GAME_STARTED;
      _takeTurn(msg.sender, _getOpponent(msg.sender), index);
    }

    function attack(uint index, bool wasHit) public _gameStarted _validMove(index) _checkTimeout _myTurn {
      address opponent = _getOpponent(msg.sender);

      // Result of Opponent's Attack
      targets[opponent][targetIndex] = wasHit ? HIT : MISS;

      emit AttackResult(opponent, msg.sender, targetIndex, wasHit);

      // Counter Attack
      _takeTurn(msg.sender, opponent, index);

      // Check game status
      uint[3] memory gridState = _getGridState(targets[opponent]);
      uint fleetSize = _getFleetSize();

      bool isWon = gridState[1] == fleetSize;
      bool isVoid = (fleetSize - gridState[1]) > gridState[2];

      if (isWon || isVoid) {
        status = GAME_FINISHED;
        winner = opponent;
        nextRevealTimeoutPhase = (now + revealTimeout);

        emit GameFinished(opponent, msg.sender, isVoid);
      }
    }

    function reveal(string playerShipGrid, string playerShipLoaction, string saltGrid, string saltLocation) public _gameFinished _isPlayer _notRevealed _checkRevealTimeout {
      bytes32 secretGrid = _getSecret(playerShipGrid, saltGrid);
      // Checks the integrity of ships grid
      require(secretGrid == secretsGrid[msg.sender]);

      bytes32 secretLocation = _getSecret(playerShipLoaction, saltLocation);
      // Checks the integrity of ships locations
      require(secretLocation == secretLocation[msg.sender]);

      // Checks if they cheated (reported MISS when HIT)
      bool playerCheated = false;

      bytes memory positions = bytes(playerShipGrid);
      bytes memory locations = bytes(playerShipLoaction);

      // Check ship locations match ship grid
      if (gridSize == GRID_DEV && locations.length != 3 || gridSize == GRID_STANDARD && locations.length != 15) {
        playerCheated = true;
      } else {
        
        uint shipNum = 0;
        for (uint i = 0; i< locations.length; i+=3) {
          bytes row = uint(locations[i]);
          bytes col = uint(locations[i+1]);
          bytes dir = uint(locations[i+2]);

          for (uint j = 0; j < SHIP_SIZES[shipNum]; j++) {
            if (row < 0 || row >= gridSize || col < 0 || col >= gridSize || dir < 0 || dir > 1) {
              playerCheated = true;
              break;
            }

            uint curIndex = row*gridSize + col;
            if (positions[curIndex] == '0') {
              playerCheated = true;
              break;
            }
          
            if (dir == 0) {
              //Vertical
              row++;
            } else {
              //Horizontal
              col++;
            }
          }

          if (playerCheated) {
            break;
          }
          
          shipNum++;
        }

        if (!playerCheated) {
          address opponent = _getOpponent(msg.sender);
          uint shipCount = 0;

          // Check if ships are all HITs
          for (uint k = 0; k < positions.length; k++) {
            // Position on ocean is empty (ignore) 
            // continue saves gas
            if (positions[k] == "0") {
              continue;
            }

            // Position on target is not empty
            if (targets[opponent][k] != 0) {
              // Position is a ship then Check if HIT
              playerCheated = targets[opponent][k] != HIT;
            }
            
            shipCount++;

            // Break to save gas
            if (playerCheated) {
              break;
            }
          }

          if (!playerCheated) {
            playerCheated = shipCount != _getFleetSize();
          } 
        }
      // Check player initial ship configuration was legit
      }

      shipsGrid[msg.sender] = playerShipGrid;
      cheated[msg.sender] = playerCheated;

      bool isDone = bytes(shipsGrid[opponent]).length > 0;

      if (isDone) {
        status = GAME_DONE;
      }

      if (playerCheated) {
        // If was winner, remove
        if (winner == msg.sender) {
          winner = address(0);
        }

        // If opponent has not cheated, make him winner
        if (isDone && cheated[opponent] == false) {
          winner = opponent;
        }
      }
      
      emit GameRevealed(msg.sender, opponent, playerShipGrid, playerCheated);

    }


    /**
     * @dev check if it's msg.sender's turn
     * @return true if it's msg.sender's turn otherwise false
     */
    function myTurn() public view returns (bool) {
       /*Please complete the code here.*/
       return turn == msg.sender;
    }

    /**
     * @dev check a move is valid
     * @param index the position the player places at
     * @return true if valid otherwise false
     */
    function validMove(uint index) public view returns (bool) {
      /*Please complete the code here.*/
      return index >= 0 && index < gridSize ** 2 && targets[msg.sender][index] == 0;
    }


    /**
     * @dev show the current board
     * @return guesses
     */
    function showTargets(address player) public view returns (uint8[] memory) {
      return targets[player];
    }

    function unlockFundsAfterJoinTimeout() public {
        //Game must be timed out & still active
        require(joinDeadline < now, "Game has not yet timed out");
        require(status == GAME_NOT_STARTED, "Game has Started.");
        // require(, "Must be called by winner.");

        status = GAME_DONE;
        winner = msg.sender;
        payWinner();
    }

    function unlockFundsAfterTimeout() public {
        //Game must be timed out & still active
        require(nextTimeoutPhase < now && status == GAME_STARTED && turn == _getOpponent(msg.sender)
              || nextRevealTimeoutPhase < now && status == GAME_FINISHED 
                                              && bytes(shipsGrid[msg.sender]).length > 0 
                                              && bytes(shipsGrid[_getOpponent(msg.sender)]).length == 0
                                              && !cheated[msg.sender], "Game has not yet timed out");
        require(betAmount > 0, "Winner already paid.");

        status = GAME_DONE;
        winner = msg.sender;
        payWinner();
    }

    function payWinner() public _isWinner {
      uint amount = betAmount;
      betAmount = 0;
      
      msg.sender.transfer(amount);
    }

    function _takeTurn(address attacker, address defender, uint index) private {
      targetIndex = index;
      turn = defender;

      emit Attack(attacker, defender, index);
    }

    function _getOpponent(address player) internal view returns(address) {
      return player == players[0] ? players[1] : players[0];
    }

    function _getSecret(string playerShipGrid, string salt) internal pure returns(bytes32) {
      return keccak256(abi.encodePacked(playerShipGrid, salt));
    }


    function _getFleetSize() internal view returns(uint) {
      if (gridSize == GRID_DEV) {
        return SHIP_PATROL_BOAT;
      }

      return SHIP_CARRIER + SHIP_BATTLESHIP 
                        + SHIP_DESTROYER + SHIP_SUBMARINE + SHIP_PATROL_BOAT;
    }



    /**
     * @param grid Target/ocean grid of positions
     * @return number of misses, number of hits, number of empty positions
     */

    function _getGridState(uint8[] grid) internal pure returns(uint[3]) {
      uint misses;
      uint hits;
      uint empty;

      for (uint i = 0; i < grid.length; i++) {
        if (grid[i] == MISS) {
          misses++;
        } else if (grid[i] == HIT) {
          hits++;
        } else if (grid[i] == 0) {
          empty++;
        }
      }

      return [misses, hits, empty];
    }

}

