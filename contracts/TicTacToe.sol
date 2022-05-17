//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.24;

/**
 * @title TicTacToe contract
 **/
contract TicTacToe {
    address[2] public players;
    uint8 public playersJoined;
    mapping(address => uint8) public walletToPlayer;

    /**
      Amount to bet
     */
    uint public betAmount;

    /**
     turn
     1 - players[0]'s turn
     2 - players[1]'s turn 
     */
    uint public turn = 1;

    /**
     status
     0 - Not started
     1 - players[0] won
     2 - players[1] won
     3 - draw
     4 - Ongoing
     */
    uint public status = 0;
    bool public paidWinner = false;
    /**
    No.	Class of ship	Size
    1	  Carrier	      5
    2	  Battleship   	4
    3	  Destroyer	    3
    4	  Submarine	    3
    5	  Patrol Boat	  2
     */
    uint8[10][10][2] private fleet;
    uint8[10][10][2] private guesses;


    /**
    No.	          Class of ship 	Hit Required
    shipsHit[0]	  Carrier	        5
    shipsHit[1]	  Battleship   	  4
    shipsHit[2]	  Destroyer	      3
    shipsHit[3]	  Submarine	      3
    shipsHit[4]	  Patrol Boat	    2
     */
    uint8[5] public shipLength = [5, 4, 3, 3, 2];
    uint8[2][5] public shipsHit;
    bool[2][5] public shipSank;
    /**
      Timeout
     */
    uint256 timeout = 1.5 minutes;
    uint256 nextTimeoutPhase;

    /**
      * @dev Deploy the contract to create a new game
      * @param opponent The address of player2
      * @param _rows row of ship i
      * @param _cols col of ship i
      * @param _dirs direction of ship i
      * dir  
        0   left
        1   right
        2   up
        3   down
      **/
    constructor(address opponent, uint8[5] _rows, uint8[5] _cols, uint8[5] _dirs) public payable _validFleet(_rows, _cols, _dirs){
      require(msg.sender != opponent, "No self play.");
      require(msg.value > 0, "Bet too small");
      // require(msg.value <= msg.sender.balance, "Player 1 insufficient balance.");
      // require(msg.value <= opponent.balance, "Player 2 insufficient balance.");

      betAmount = msg.value;

      players[0] = msg.sender;
      players[1] = opponent;
      walletToPlayer[msg.sender] = 1;

      playersJoined = 1;

      // bool valid = true;
      // for (uint8 i = 0; i < _rows.length; i++) {
      //   valid = valid && try_to_place_ship_on_grid(fleet[0], _rows[i], _cols[i], _dirs[i], i);
      // }
      // require(valid, "Invalid Fleet");
    }

    function join(uint8[5] _rows, uint8[5] _cols, uint8[5] _dirs) external payable _validFleet(_rows, _cols, _dirs){
      require(msg.sender == players[1], "You are not an opponent.");
      require(playersJoined == 1, "Opponent already joined.");
      require(msg.value == betAmount, "Wrong bet amount.");

      walletToPlayer[msg.sender] = 2;
      playersJoined = 2;

      nextTimeoutPhase = (now + timeout);
      status = 4;
    }


    function validate_grid_and_place_ship(uint8[10][10] _fleet, uint8 start_row, uint8 end_row, uint8 start_col, uint8 end_col, uint8 shipI) private pure returns (bool) {
      for (uint8 i = start_row; i < end_row; i++) {
        for (uint8 j = start_col; j < end_col; j++) {
          if (_fleet[i][j] > 0) {
            return false;
          }
        }
      }

      for (uint r = start_row; r < end_row; r++) {
        for (uint c = start_col; c < end_col; c++) {
          _fleet[r][c] = shipI + 1;
        }
      }
      
      return true;
    }
  
    function try_to_place_ship_on_grid(uint8[10][10] _fleet, uint8 row, uint8 col, uint8 dir, uint8 shipI) private view returns (bool) {
      uint8 start_row = row;
      uint8 end_row = row + 1;
      uint8 start_col = col;
      uint8 end_col = col + 1;

      if (row < 0 || row > 9 || col < 0 || col > 9 || dir < 0 || dir > 3) {
        return false;
      }

      if (dir == 0) {
        if (start_col - shipLength[shipI] < 0) {
          return false;
        }

        start_col = col - shipLength[shipI] + 1;

      } else if (dir == 1) {
        if (col + shipLength[shipI] > 9){
          return false;
        }

        end_col = col + shipLength[shipI];

      } else if (dir == 2){
        if (row - shipLength[shipI] < 0) {
          return false;
        }

        start_row = row - shipLength[shipI] + 1;
      } else if (dir == 3) {
        if (row + shipLength[shipI] > 9) {
          return false;
        }

        end_row = row + shipLength[shipI];
      } 

      return validate_grid_and_place_ship(_fleet, start_row, end_row, start_col, end_col, shipI);
    }

    function validFleet(uint8[5] _rows, uint8[5] _cols, uint8[5] _dirs) private view returns (bool) {
      uint8[10][10] memory _fleet;
      for (uint8 i = 0; i < _rows.length; i++) {
        if (!try_to_place_ship_on_grid(_fleet, _rows[i], _cols[i], _dirs[i], i)) {
          return false;
        }
      }

      return true;
    }


    /**
     * @dev ensure it's a valid fleet configuration
     */
    modifier _validFleet(uint8[5] _rows, uint8[5] _cols, uint8[5] _dirs) {
      /*Please complete the code here.*/

      require(validFleet(_rows, _cols, _dirs), "Invalid Fleet!");
      _;
    }


    function allSank(uint8 player) public view returns (bool) {
      for (uint8 i=0; i < shipSank.length; i++) {
        if (!shipSank[player-1][i]) {
          return false;
        }
      }

      return true;
    }

    /**
     * @dev get the status of the game
     * @return the status of the game
     */
    function _getStatus() private view returns (uint) {
        /*Please complete the code here.*/
        bool p1Win = allSank(1);
        bool p2Win = allSank(2);

        if (p1Win && p2Win) {
          return 3;
        }

        if (p1Win) {
          return 1;
        }

        if (p2Win) {
          return 2;
        }

        return 4;
    }

    function _updateShipsHit(uint pos_x, uint pos_y) private {
      uint cur_ship = fleet[pos_x][pos_y][turn - 1];

        if (cur_ship > 0){
          shipsHit[turn - 1][cur_ship - 1] += 1;
          if (shipsHit[turn - 1][cur_ship - 1] == shipLength[cur_ship - 1]) {
            shipSank[turn - 1][cur_ship - 1] = true;
          }
        }

    }

    /**
     * @dev ensure the game is still ongoing before a player moving
     * update the status of the game after a player moving
     */
    modifier _checkStatus(uint pos_x, uint pos_y) {
        /*Please complete the code here.*/
        require(status == 4, "Game is not in progess.");
        _;
        _updateShipsHit(pos_x, pos_y);

        if (turn == 2) {
          status = _getStatus();

          if (status == 3) {
            draw();
          } else if (status > 0 && status < 3 && !paidWinner) {
            paidWinner = true;
            payWinner(status);
          }
        }
        
    }

    /**
     * @dev check if it's msg.sender's turn
     * @return true if it's msg.sender's turn otherwise false
     */
    function myTurn() public view returns (bool) {
       /*Please complete the code here.*/
       return msg.sender == players[turn-1];
    }

    /**
     * @dev ensure it's a msg.sender's turn
     * update the turn after a move
     */
    modifier _myTurn {
      /*Please complete the code here.*/
      require(myTurn(), "Not your turn!");
      _;
      turn = (turn % 2) + 1;
    }

    /**
     * @dev check a move is valid
     * @param pos_x the position the player places at
     * @param pos_y the position the player places at
     * @return true if valid otherwise false
     */
    function validMove(uint pos_x, uint pos_y) public view returns (bool) {
      /*Please complete the code here.*/
      return pos_x >= 0 && pos_x < 10 && pos_y >= 0 && pos_y < 10 && guesses[pos_x][pos_y][turn-1] == 0;

    }

    /**
     * @dev ensure a move is made is valid before it is made
     */

    modifier _validMove(uint pos_x, uint pos_y) {
      /*Please complete the code here.*/
      require(validMove(pos_x, pos_y), "Invalid Move.");
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
     * @dev a player makes a move
     * @param pos_x the position the player places at
     * @param pos_y the position the player places at
     */
    function move(uint pos_x, uint pos_y) public _validMove(pos_x, pos_y) _checkTimeout _checkStatus(pos_x, pos_y) _myTurn {
      guesses[pos_x][pos_y][turn - 1] = 1;
    }

    /**
     * @dev show the current board
     * @return guesses
     */
    function showGuesses(uint player) public view returns (uint8[10][10]) {
      return guesses[player-1];
    }

    /**
     * @dev show the current board
     * @return fleet
     */
    function showFleet(uint player) public view returns (uint8[10][10]) {
      return fleet[player-1];
    }

    function unlockFundsAfterTimeout() public {
        //Game must be timed out & still active
        require(nextTimeoutPhase < now, "Game has not yet timed out");
        require(status == 4, "Game has already been rendered inactive.");
        require(!paidWinner, "Winner already paid.");
        require(players[(turn % 2)] == msg.sender , "Must be called by winner.");

        status = (turn % 2) + 1;
        paidWinner = true;
        payWinner(status);
    }

    function draw() private {
      players[0].transfer(betAmount);
      players[1].transfer(betAmount);
    }

    function payWinner(uint player) private {
      players[player - 1].transfer(betAmount + betAmount);
    }
}

