// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => bytes32) public player_commit;
    mapping(address => bool) public player_not_played;
    mapping(address => uint) public player_choice;
    address[] public players;
    uint public numInput = 0;
    mapping(address => bool) public isWhitelisted;

    CommitReveal public commitReveal;
    TimeUnit public timeUnit;

    uint public commitDeadline;
    uint public revealDeadline;

    constructor(address _commitReveal, address _timeUnit) {
        commitReveal = CommitReveal(_commitReveal);
        timeUnit = TimeUnit(_timeUnit);

        isWhitelisted[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        isWhitelisted[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        isWhitelisted[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        isWhitelisted[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    function addPlayer() public payable {
        require(isWhitelisted[msg.sender], "You are not allowed to play.");
        require(numPlayer < 2, "Already two players");
        require(msg.value == 1 ether, "Must send 1 ETH");

        if (numPlayer > 0) {
            require(msg.sender != players[0], "Player already joined");
        }
        
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;

        if (numPlayer == 1) {
            commitDeadline = block.timestamp + 5 minutes;
        } else if (numPlayer == 2) {
            revealDeadline = commitDeadline + 5 minutes;
        }
    }

    function commitMove(bytes32 dataHash) public {
        require(numPlayer == 2, "Must have exactly 2 players");
        require(block.timestamp <= commitDeadline, "Commit phase has ended");
        require(player_not_played[msg.sender], "Player has already committed");

        commitReveal.commit(dataHash);
        player_commit[msg.sender] = dataHash;
    }
\\แก้
    function revealMove(string memory choice, string memory secret) public {
        require(numPlayer == 2, "Must have exactly 2 players");
        require(block.timestamp > commitDeadline, "Commit phase still active");
        require(block.timestamp <= revealDeadline, "Reveal phase has ended");

        bytes32 revealHash = keccak256(abi.encodePacked(choice, secret));
        commitReveal.reveal(revealHash);
        player_choice[msg.sender] = getChoice(choice);
        player_not_played[msg.sender] = false;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        _resetGame();
    }

    function refund() public {
        require(numPlayer == 1, "Refund only if Player 1 is absent");
        require(block.timestamp > commitDeadline, "Wait until commit phase ends");

        address payable player1 = payable(players[0]);
        player1.transfer(reward);
        _resetGame();
    }

    function withdraw() external {
        require(numPlayer == 2, "Game not started");
        require(timeUnit.elapsedSeconds() > 300, "Wait at least 5 minutes");
        payable(msg.sender).transfer(reward / 2);
    }

    function getChoice(string memory choice) private pure returns (uint) {
        if (keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked("rock"))) {
            return 0;
        } else if (keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked("paper"))) {
            return 1;
        } else if (keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked("scissors"))) {
            return 2;
        } else if (keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked("lizard"))) {
            return 3;
        } else if (keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked("spock"))) {
            return 4;
        }
        return 0;
    }

    function _resetGame() private {
        delete players;
        numPlayer = 0;
        numInput = 0;
        reward = 0;
        delete player_commit[players[0]];
        delete player_commit[players[1]];
        delete player_not_played[players[0]];
        delete player_not_played[players[1]];
    }
}
