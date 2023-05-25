//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BingoGame {
    event GameJoined(address player, uint256 gameId);
    IERC20 immutable TokenERC20;
    address immutable Owner;
    mapping(uint256 => Game) game;
    mapping(address => mapping(uint256 => uint256)) private gameBoard;
    mapping(address => mapping(uint256 => bool[5][5]))
        private playerMarkedNumberBoard;
    mapping(uint256 => uint8[]) private gameNumberDrawn;
    uint8 constant mask = 0xFF;

    uint256 private gameCount = 0;
    struct Game {
        uint256 entryFee;
        uint256 minimumJoinDuration;
        uint256 minimumTurnDuration;
        uint256 randomNumber;
        uint256 lastDrawnTime;
        bool gameCompleted;
        bool gameStarted;
    }

    constructor(address _TokenERC20) {
        TokenERC20 = IERC20(_TokenERC20);
        Owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == Owner,
            "BingoGame: Only owner execute this function."
        );
        _;
    }

    function gameSchedule(
        uint256 _entryFee,
        uint256 _minimumJoinDuration,
        uint256 _minimumTurnDuration
    ) external onlyOwner {
        game[++gameCount] = Game(
            _entryFee,
            _minimumJoinDuration,
            _minimumTurnDuration,
            generateRandomNumber(gameCount),
            0,
            false,
            false
        );
    }

    function updateSchedule(
        uint256 gameId,
        uint256 _entryFee,
        uint256 _minimumJoinDuration,
        uint256 _minimumTurnDuration
    ) external onlyOwner {
        require(
            gameId <= gameCount,
            "BingoGame: game whose schedule to update does not exist."
        );
        Game memory gameToUpdate = game[gameId];
        require(
            gameToUpdate.gameStarted == false,
            "BingoGame: cannot update the schedule after it have started."
        );
        game[gameId] = Game(
            _entryFee,
            _minimumJoinDuration,
            _minimumTurnDuration,
            gameToUpdate.randomNumber,
            0,
            false,
            false
        );
    }

    function joinGame(uint256 gameId) external {
        require(gameId <= gameCount, "BingoGame: game to join does not exist.");
        require(
            gameBoard[msg.sender][gameId] == 0,
            "BingoGame: User have already joined this game."
        );
        Game memory gameToJoin = game[gameId];
        require(
            gameToJoin.gameStarted == false,
            "BingoGame: game to join have already started."
        );
        TokenERC20.transferFrom(msg.sender, address(this), gameToJoin.entryFee);
        gameBoard[msg.sender][gameId] = generateRandomNumber(gameId);
        emit GameJoined(msg.sender, gameId);
    }

    function gameStart(uint256 gameId) external onlyOwner {
        require(
            gameId <= gameCount,
            "BingoGame: game to start does not exist."
        );

        Game memory gameToStart = game[gameId];
        require(
            gameToStart.gameCompleted == false,
            "BingoGame: game to start have already completed."
        );
        game[gameId].gameStarted = true;
    }

    function rollNumber(uint256 gameId) public returns (uint8) {
        require(gameId <= gameCount, "BingoGame: game does not exist.");
        Game memory gameToRoll = game[gameId];
        require(
            gameToRoll.gameStarted == true,
            "BingoGame: cannot roll as game has not been started by game owner."
        );
        require(
            gameToRoll.gameCompleted == false,
            "BingoGame: cannot roll as this game have already been completed"
        );
        require(
            block.timestamp >=
                gameToRoll.lastDrawnTime + gameToRoll.minimumTurnDuration,
            "BingoGame: wait for turn duration to pass."
        );

        uint8 randomNumber = uint8(gameToRoll.randomNumber & mask);
        game[gameId].randomNumber = (gameToRoll.randomNumber) >> 8;
        game[gameId].lastDrawnTime = block.timestamp;
        gameNumberDrawn[gameId].push(randomNumber);
        return randomNumber;
    }

    function markNumberOnBoard(
        uint256 gameId,
        uint8 randomNumber
    ) external returns (bools) {
        uint256 playerBoard = gameBoard[msg.sender][gameId];
        // uint8 numberOnPlayerBoard;
        for (uint256 i = 24; i >= 0; i--) {
            if (i == 12) {
                playerMarkedNumberBoard[2][2] = true;
            }
            else ((playerBoard & randomNumber) == randomNumber) {
                playerMarkedNumberBoard[i / 5][i % 4] = true;
            }
            playerBoard >>=8;



        }
    }

    function generateRandomNumber(
        uint256 gameId
    ) private view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(gameId + block.timestamp))) +
            uint256(keccak256(abi.encodePacked(msg.sender))));
    }

    //     function gameIdRandomNumber(uint256 gameId) public view returns(uint256){
    //  Game memory gameToRetrive = game[gameId];
    //  return gameToRetrive.randomNumber;
    //     }
    //     function playerBoard(uint256 gameId) public view returns(uint256){
    //         return gameBoard[msg.sender][gameId];
    //     }
}
