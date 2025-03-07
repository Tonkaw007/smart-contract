// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public gameStartTime;
    uint public gameTimeout = 3 minutes; // เวลาที่ผู้เล่นต้องเลือกก่อนจะล๊อกเงิน
    mapping(address => uint) public player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    mapping(address => bytes32) public player_commitment;
    address[] public players;

    uint public numInput = 0;

    // เปลี่ยน allowedPlayers เป็น private
    address[4] private allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    function isAllowedPlayer(address player) internal view returns (bool) {
        for (uint i = 0; i < allowedPlayers.length; i++) {
            if (allowedPlayers[i] == player) {
                return true;
            }
        }
        return false;
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "Maximum two players are allowed");
        require(isAllowedPlayer(msg.sender), "Player is not allowed to play");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Player 1 is already in the game");
        }
        require(msg.value == 1 ether, "You must stake 1 ether to play");
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
        // Set game start time only when both players are added
        if (numPlayer == 2) {
            gameStartTime = block.timestamp;
        }
    }

    function commitChoice(bytes32 commitmentHash) public {
        require(numPlayer == 2, "Two players are required to start the game");
        require(player_not_played[msg.sender], "Player has already committed");
        player_commitment[msg.sender] = commitmentHash;
        player_not_played[msg.sender] = false;
    }

    function input(uint choice, string memory randomString) public {
        require(numPlayer == 2, "Two players are required to start the game");
        require(!player_not_played[msg.sender], "Player has not committed yet");
        require(choice >= 0 && choice <= 4, "Invalid choice (0-4 expected)");
        
        bytes32 commitmentHash = keccak256(abi.encodePacked(randomString, choice));
        require(commitmentHash == player_commitment[msg.sender], "Commitment hash does not match");

        player_choice[msg.sender] = choice;
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

        // ตรวจสอบผลลัพธ์ของเกม RPSLS
        if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            // Player 1 ชนะ
            (bool success1, ) = account1.call{value: reward}("");
            require(success1, "Transfer failed");
        } else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            // Player 0 ชนะ
            (bool success0, ) = account0.call{value: reward}("");
            require(success0, "Transfer failed");
        } else {
            // เสมอ, แบ่งเงินรางวัล
            uint halfReward = reward / 2;
            (bool success0, ) = account0.call{value: halfReward}("");
            (bool success1, ) = account1.call{value: reward - halfReward}("");
            require(success0 && success1, "Transfer failed");
        }

        // รีเซ็ตเกม
        resetGame();
    }

    function checkTimeout() public {
        require(numPlayer == 2, "Game must have two players");
        require(gameStartTime != 0, "Game has not started yet");
        require(block.timestamp >= gameStartTime + gameTimeout, "Game timeout has not yet occurred");
        
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        uint halfReward = reward / 2;
        if (numInput == 1 || numInput == 0) {
            // คืนเงินครึ่งหนึ่งให้ทั้งสองผู้เล่น
            (bool success0, ) = account0.call{value: halfReward}("");
            (bool success1, ) = account1.call{value: reward - halfReward}("");
            require(success0 && success1, "Transfer failed");
        }

        // รีเซ็ตสถานะของเกมหลังจากคืนเงิน
        resetGame();
    }

    function resetGame() private {
        // รีเซ็ตสถานะผู้เล่น
        for (uint i = 0; i < players.length; i++) {
            delete player_choice[players[i]];
            delete player_not_played[players[i]];
            delete player_commitment[players[i]];
        }

        // รีเซ็ตตัวแปรสถานะ
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        gameStartTime = 0;
        players = new address[](0); // รีเซ็ต array players
    }
}