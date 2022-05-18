//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.24;

/**
 * @title Battleships contract
 **/
contract Battleships {
    uint8 constant GRID_SIZE = 10;

    // Target hit or miss values
    int8 constant HIT = 1;
    int8 constant MISS = -1;

    // Status constants
    uint8 constant GAME_READY = 1;
    uint8 constant GAME_STARTED = 2;
    uint8 constant GAME_FINISHED = 3;
    uint8 constant GAME_DONE = 4;

    // Ship size constants
    uint8 constant SHIP_CARRIER = 5;
    uint8 constant SHIP_BATTLESHIP = 4;
    uint8 constant SHIP_DESTROYER = 3;
    uint8 constant SHIP_SUBMARINE = 3;
    uint8 constant SHIP_PATROL_BOAT = 2;



    address[2] public players;

    uint8 public playersJoined;

    mapping(address => uint8) public walletToPlayer;

    address winner;

    /**
      Amount to bet
     */
    uint public betAmount;

    /**
     turn
     address of whos turn it is 
     */
    address public turn;

    /**
     status
     0 - Not started
     1 - Game Ready
     2 - Ongoing
     3 - void
     4 - done
     */
    uint8 public status = 0;

    uint8 targetIndex;

    mapping (address => bytes32) secrets;
    mapping (address => string) ships;
    mapping (address => int8[]) targets;
    mapping (address => bool) cheated;

    /**
    No.	          Class of ship 	Hit Required
    shipsHit[0]	  Carrier	        5
    shipsHit[1]	  Battleship   	  4
    shipsHit[2]	  Destroyer	      3
    shipsHit[3]	  Submarine	      3
    shipsHit[4]	  Patrol Boat	    2
     */


    /**
      Timeout
     */
    uint256 timeout = 1.5 minutes;
    uint256 nextTimeoutPhase;

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

    modifier _validMove(uint8 index) {
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
    require(bytes(ships[msg.sender]).length == 0);
    _;
  }

    // Events 

    /**
     * @dev `owner` Address who created the game
     * @dev `gridSize` The size of the target/ocean grid
     * @dev `bet` The amount of the bet
     */
    event GameCreated(address indexed owner, uint bet);
    
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

    /// @dev `player1` Address who performed the attack
    /// @dev `player2` Address who suffured the attack
    /// @dev `index` Index of the attack
    /// @dev `hit` Result of the attack
    event AttackResult(address indexed player1, address indexed player2, uint index, bool hit);

    /// @dev `winner` Address who won the game
    /// @dev `opponent` Address of opponent player
    /// @dev `void` If game is void (cheated)
    event GameFinished(address indexed winner, address indexed opponent, bool void);

    /// @dev `revealer` Address who revealed its ships positions
    /// @dev `opponent` Address of opponent player
    /// @dev `ships` Unobfuscated ships positions
    /// @dev `void` If ships positions are void (cheated)
    event GameRevealed(address indexed revealer, address indexed opponent, string ships, bool void);



    // Functions

    /**
      * @dev Deploy the contract to create a new game
      * @param opponent The address of player2
      * dir  
        0   left
        1   right
        2   up
        3   down
      **/
    constructor(address opponent, bytes32 secret) public payable {
      require(msg.sender != opponent, "No self play.");
      require(msg.value > 0, "Bet too small");

      betAmount = msg.value;
      turn = msg.sender;
      players[0] = msg.sender;
      players[1] = opponent;
      walletToPlayer[msg.sender] = 1;
      secrets[msg.sender] = secret;
      targets[msg.sender] = new int8[](GRID_SIZE ** 2);
      playersJoined = 1;

      emit GameCreated(msg.sender, msg.value);
    }

    function join(bytes32 secret) external payable {
      require(msg.sender == players[1], "You are not an opponent.");
      require(playersJoined == 1, "Opponent already joined.");
      require(msg.value == betAmount, "Wrong bet amount.");

      secrets[msg.sender] = secret;
      walletToPlayer[msg.sender] = 2;
      playersJoined = 2;
      betAmount += msg.value;

      nextTimeoutPhase = (now + timeout);
      status = GAME_READY;
      emit GameJoined(players[0], msg.sender, msg.value);
    }


    function attack(uint8 index) public _gameReady _validMove(index) _checkTimeout _myTurn {
      status = GAME_STARTED;
      _attack(msg.sender, _getOpponent(msg.sender), index);
    }

    function counterAttack(uint8 index, bool hit) public _gameStarted _validMove(index) _checkTimeout _myTurn {
      address opponent = _getOpponent(msg.sender);

      // Result of Opponent's Attack
      targets[opponent][targetIndex] = hit ? HIT : MISS;

      emit AttackResult(opponent, msg.sender, targetIndex, hit);

      // Counter Attack
      _attack(msg.sender, opponent, index);

      // Check status
      uint[3] memory gridState = _getGridState(targets[opponent]);
      uint fleetSize = SHIP_CARRIER + SHIP_BATTLESHIP 
                        + SHIP_DESTROYER + SHIP_SUBMARINE + SHIP_PATROL_BOAT;

      bool isWon = gridState[1] == fleetSize;
      bool isVoid = (fleetSize - gridState[1]) > gridState[2];

      if (isWon || isVoid) {
        status = GAME_FINISHED;
        winner = opponent;

        emit GameFinished(opponent, msg.sender, isVoid);
      }
    }

    function reveal(string player_ships, string salt) public _gameFinished _isPlayer _notRevealed {
      bytes32 secret = _getSecret(player_ships, salt);

      // Checks the integrity of ships
      require(secret == secrets[msg.sender]);

      // Checks if they cheated (reported MISS when HIT)
      bytes memory positions = bytes(player_ships);
      bool player_cheated = false;

      address opponent = _getOpponent(msg.sender);
      // Check if ships are all HITs
      for (uint i = 0; i < positions.length; i++) {
        // Position on ocean is empty (ignore)
        if (positions[i] == "0") {
          continue;
        }

        // Position on target is empty (ignore)
        if (targets[opponent][i] == 0) {
          continue;
        }

        // Position is a ship
        // Check if HIT
        player_cheated = targets[opponent][i] != HIT;

        if (player_cheated) {
          break;
        }
      }

      ships[msg.sender] = player_ships;
      cheated[msg.sender] = player_cheated;

      bool isDone = bytes(ships[opponent]).length > 0;

      if (isDone) {
        status = GAME_DONE;
      }

      if (player_cheated) {
        // If was winner, remove
        if (winner == msg.sender) {
          winner = address(0);
        }

        // If opponent has not cheated, make him winner
        if (isDone && cheated[opponent] == false) {
          winner = opponent;
        }
      }

      emit GameRevealed(msg.sender, opponent, player_ships, player_cheated);

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
    function validMove(uint8 index) public view returns (bool) {
      /*Please complete the code here.*/
      return index >= 0 && index < 100 && targets[msg.sender][index] == 0;
    }


    // /**
    //  * @dev show the current board
    //  * @return guesses
    //  */
    // function showTargets(address player) public view returns (uint8[]) {
    //   return targets[player];
    // }


    function unlockFundsAfterTimeout() public {
        //Game must be timed out & still active
        require(nextTimeoutPhase < now, "Game has not yet timed out");
        require(status == GAME_STARTED, "Game has already been rendered inactive.");
        require(betAmount > 0, "Winner already paid.");
        require(turn == _getOpponent(msg.sender) , "Must be called by winner.");

        status = GAME_DONE;
        winner = msg.sender;
        payWinner();
    }

    function _attack(address attacker, address defender, uint8 index) private {
      targetIndex = index;
      turn = defender;

      emit Attack(attacker, defender, index);
    }

    function _getOpponent(address player) internal view returns(address) {
      return player == players[0] ? players[1] : players[0];
    }

    function _getSecret(string player_ships, string salt) internal pure returns(bytes32) {
      return keccak256(abi.encodePacked(player_ships, salt));
    }

    /**
     * @param grid Target/ocean grid of positions
     * @return number of misses, number of hits, number of empty positions
     */

    function _getGridState(int8[] grid) internal pure returns(uint[3]) {
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

    // function draw() private {
    //   uint amount = betAmount;
    //   betAmount = 0;
    //   players[0].transfer(amount / 2);
    //   players[1].transfer(amount / 2);
    // }

    function payWinner() private _isWinner {
      uint amount = betAmount;
      betAmount = 0;

      msg.sender.transfer(amount);
    }
}

