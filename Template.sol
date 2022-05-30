//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.24;

/**
 * @title BaseGameTemplate contract
 **/
contract BaseGameTemplate {
    // Status constants
    uint constant GAME_NOT_STARTED = 0;
    uint constant GAME_READY = 1;
    uint constant GAME_STARTED = 2;
    uint constant GAME_FINISHED = 3;
    uint constant GAME_DONE = 4;

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

    uint public status = GAME_NOT_STARTED;

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

    modifier _validMove(uint move) {
      /*Please complete the code here.*/
      require(validMove(move), "Invalid Move.");
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
      require(status == GAME_STARTED, "Game not started.");
      _;
    }  

    modifier _gameFinished {
      /*Please complete the code here.*/
      require(status == GAME_FINISHED, "Game not finished.");
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
     * @dev `player1` Address who created the game
     * @dev `player2` Address who joined the open game
     * @dev `bet` The matching amount of the bet
     */
    event GameJoined(address indexed player1, address indexed player2, uint bet);
    
    /** 
     * @dev `player1` Address who performed the attack
     * @dev `player2` Address who suffured the attack
     * @dev `move` Index of the attack
     */
    event Move(address indexed player1, address indexed player2, uint move);

    /**
     * @dev `winner` Address who won the game
     * @dev `opponent` Address of opponent player
     * @dev `void` If game is void (cheated)
     */

    event GameFinished(address indexed winner, address indexed opponent, bool void);



    // Functions

    /**
      * @dev Deploy the contract to create a new game
      * @param opponent The address of player2
      **/
    constructor(address opponent) public payable {
      require(msg.sender != opponent, "No self play.");
      require(msg.value > 0, "Bet too small");

      turn = msg.sender;
      players[0] = msg.sender;
      players[1] = opponent;
      walletToPlayer[msg.sender] = 1;
      playersJoined = 1;
      betAmount = msg.value;

      joinDeadline = (now + joinTimeout);

      emit GameCreated(msg.sender, msg.value, size);
    }

    function join(bytes32 secret) external payable _checkJoinTimeout {
      require(msg.sender == players[1], "You are not an opponent.");
      require(playersJoined == 1, "Opponent already joined.");
      require(msg.value == betAmount, "Wrong bet amount.");

      walletToPlayer[msg.sender] = 2; 
      playersJoined = 2;
      betAmount += msg.value;

      nextTimeoutPhase = (now + timeout);
      status = GAME_READY;

      emit GameJoined(players[0], msg.sender, msg.value);
    }


    function attack(uint move) public _gameReady _validMove(move) _checkTimeout _myTurn {
      status = GAME_STARTED;
      _attack(msg.sender, _getOpponent(msg.sender), index);
    }

    function counterAttack(uint move) public _gameStarted _validMove(move) _checkTimeout _myTurn {
      address opponent = _getOpponent(msg.sender);

      // Counter Attack
      _attack(msg.sender, opponent, index);

      // Check game status
      bool isWon = true;

      if (isWon) {
        status = GAME_FINISHED;
        winner = opponent;

        emit GameFinished(opponent, msg.sender, isVoid);
      }
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
    function validMove(uint move) public view returns (bool) {
      /*Please complete the code here.*/
      return true;
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
        require(nextTimeoutPhase < now && status == GAME_STARTED && turn == _getOpponent(msg.sender));
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

    function _attack(address attacker, address defender, uint move) private {
      turn = defender;

      emit Attack(attacker, defender, move);
    }

    function _getOpponent(address player) internal view returns(address) {
      return player == players[0] ? players[1] : players[0];
    }
