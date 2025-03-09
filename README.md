### อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
โค้ดนี้ใช้ 2 ฟังก์ชันหลัก คือ function checkTimeout() และ function resetGame()

1. ฟังก์ชัน checkTimeout: ฟังก์ชันนี้จะตรวจสอบว่าเกมได้เริ่มต้นแล้วและเวลาที่กำหนดไว้สำหรับเกม (gameTimeout) ได้หมดลงหรือไม่ ซึ่ง timeout เกิดขึ้นเมื่อมีเวลาผ่านไปมากกว่าหรือเท่ากับเวลาที่กำหนด ( 1 นาที) ใน gameTimeout
หากเวลาหมดลงและยังมีผู้เล่นไม่ครบทั้งสองคน (numInput == 1 หรือ numInput == 0) ระบบจะจ่ายเงินรางวัลครึ่งหนึ่งให้กับผู้เล่นแต่ละคนและทำการ reset เกม

function checkTimeout() public {

    require(numPlayer == 2, "Game must have two players");
    
    require(gameStartTime != 0, "Game has not started yet");
    
    require(block.timestamp >= gameStartTime + gameTimeout, "Game timeout has not yet occurred");

    address payable account0 = payable(players[0]);
    address payable account1 = payable(players[1]);
    uint halfReward = reward / 2;
    if (numInput == 1 || numInput == 0) {
        (bool success0, ) = account0.call{value: halfReward}("");
        (bool success1, ) = account1.call{value: reward - halfReward}("");
        require(success0 && success1, "Transfer failed");
    }

    resetGame();
}

2. function resetGame() ใช้รีเซ็ตสถานะของเกมหลังจากที่เกมจบหรือเกิด timeout
ซึ่งจะลบข้อมูลต่างๆ ของผู้เล่นจาก mapping ที่เกี่ยวข้อง เช่น player_choice, player_commitment, player_revealHash และ player_revealed ทำให้เกมพร้อมสำหรับการเริ่มใหม่

function resetGame() private {

        for (uint i = 0; i < players.length; i++) {
            delete player_choice[players[i]];
            delete player_not_played[players[i]];
            delete player_commitment[players[i]];
            delete player_revealHash[players[i]];
            delete player_revealed[players[i]];
        }

        numPlayer = 0;
        reward = 0;
        numInput = 0;
        gameStartTime = 0;
        players = new address[](0);
    }

### อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
โค้ดนี้ใช้กลไก commit-reveal scheme เพื่อป้องกันการโกง (front-running) โดยใช้
function commitChoice(bytes32 commitmentHash) 
- การตรวจสอบจำนวนผู้เล่น:

require(numPlayer == 2, "Two players are required to start the game");

เงื่อนไขนี้ ใช้ตรวจสอบว่าในเกมมีผู้เล่นครบ 2 คนแล้วหรือไม่ ถ้ายังมีผู้เล่นไม่ครบ 2 คน ระบบจะไม่อนุญาตให้ทำการ commit

- ตรวจสอบสถานะของผู้เล่น:

require(player_not_played[msg.sender], "Player has already committed");

โดยจะตรวจสอบว่า ผู้เล่นยังไม่ได้ทำการ commit หรือยังไม่ได้เลือกมาก่อน ถ้าผู้เล่นนั้นเคย commit ไปแล้ว ระบบจะไม่อนุญาตให้ commit อีก
การบันทึก commitment:

solidity
คัดลอก
แก้ไข
player_commitment[msg.sender] = commitmentHash;
หลังจากที่ผู้เล่นทำการ commit โดยการคำนวณ commitmentHash จากการเลือกของตน (และข้อมูลสุ่มเพื่อป้องกันการทำนาย) ระบบจะบันทึกค่า commitmentHash ลงใน player_commitment สำหรับผู้เล่นคนนั้น
การเปลี่ยนสถานะของผู้เล่น:

solidity
คัดลอก
แก้ไข
player_not_played[msg.sender] = false;
หลังจากที่ผู้เล่นทำการ commit เสร็จแล้ว ฟังก์ชันจะอัพเดตสถานะของผู้เล่นใน player_not_played เป็น false ซึ่งหมายความว่า "ผู้เล่นได้ทำการ commit แล้ว" และไม่สามารถทำการ commit ใหม่ได้
3. การทำงานโดยรวม
ผู้เล่นจะส่ง commitmentHash ซึ่งเป็นการซ่อนตัวเลือกของเขา
ฟังก์ชันจะบันทึกค่า commitmentHash ลงในระบบและทำเครื่องหมายว่า ผู้เล่นนี้ได้ commit แล้ว
สิ่งนี้จะป้องกันไม่ให้ผู้เล่นสามารถเห็นการเลือกของคู่แข่งก่อนที่จะทำการเลือก (การป้องกันการโกงแบบ "front-running")
ตัวอย่าง
สมมติว่าผู้เล่น A เลือก "Rock" และผู้เล่น B เลือก "Paper" แล้วผู้เล่นทั้งสองก็ต้องทำการ commit ตัวเลือกของตนในลักษณะของ commitmentHash ซึ่งอาจจะคำนวณโดยใช้การผสมผสานระหว่างตัวเลือกที่เลือกและข้อมูลสุ่ม เช่น:

ผู้เล่น A: commitmentHash = keccak256(abi.encodePacked("Rock", "randomStringA"))
ผู้เล่น B: commitmentHash = keccak256(abi.encodePacked("Paper", "randomStringB"))
ฟังก์ชัน commitChoice() จะรับค่า commitmentHash จากผู้เล่น แล้วบันทึกข้อมูลนี้ในระบบ เพื่อให้ผู้เล่นไม่สามารถเปลี่ยนแปลงการเลือกของตนได้จนกว่าเกมจะมาถึงขั้นตอนการ reveal












function commitChoice(bytes32 commitmentHash) public {
    
    require(numPlayer == 2, "Two players are required to start the game");
    require(player_not_played[msg.sender], "Player has already committed");
    player_commitment[msg.sender] = commitmentHash;
    player_not_played[msg.sender] = false;
}

กลไกนี้จะทำให้ผู้เล่นไม่สามารถเปลี่ยนตัวเลือกได้หลังจากที่ทำการ commit แล้ว ซึ่งทำให้ไม่มีการโกง เช่น การเปลี่ยนตัวเลือกหลังจากเห็นตัวเลือกของฝ่ายตรงข้าม

### อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
ใช้ function checkTimeout() ทำหน้าที่คืนเงินให้ผู้เล่นหากเกิด timeout
- ตรวจสอบเงื่อนไข timeout ว่าเกมมีผู้เล่น 2 คนและเวลา timeout เกิดขึ้นแล้ว
- ถ้าผู้เล่นไม่ครบ หรือมีผู้เล่นเพียงคนเดียวที่ได้ทำการเปิดเผยตัวเลือก หรือไม่ส่งข้อมูลเลย ระบบจะคืนเงินให้ทั้งสองฝ่าย โดยการแบ่งรางวัลครึ่งหนึ่งให้กับผู้เล่นแต่ละคน

function checkTimeout() public {

    require(numPlayer == 2, "Game must have two players");
    require(gameStartTime != 0, "Game has not started yet");
    require(block.timestamp >= gameStartTime + gameTimeout, "Game timeout has not yet occurred");

    address payable account0 = payable(players[0]);
    address payable account1 = payable(players[1]);

    uint halfReward = reward / 2;
    if (numInput == 1 || numInput == 0) {
        (bool success0, ) = account0.call{value: halfReward}("");
        (bool success1, ) = account1.call{value: reward - halfReward}("");
        require(success0 && success1, "Transfer failed");
    }
    resetGame();
}

- การรีเซ็ตเกม: เมื่อการโอนเงินเสร็จสมบูรณ์ ฟังก์ชันจะทำการรีเซ็ตเกม เพื่อให้พร้อมสำหรับการเริ่มต้นใหม่ โดยเรียกใช้ฟังก์ชัน resetGame()

### อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ 
โดยใช้ 2 ฟังก์ชันหลัก คือ function reveal(bytes32 revealHash, uint choice) และ function _checkWinnerAndPay()
1. function reveal(bytes32 revealHash, uint choice) ทำหน้าที่เปิดเผยตัวเลือกของผู้เล่น 
- ตรวจสอบว่าเกมมีผู้เล่นครบสองคนและผู้เล่นยังไม่ได้เปิดเผยข้อมูล
- ตรวจสอบ revealHash ว่าตรงกับ commitmentHash ที่บันทึกไว้หรือไม่
ถ้าการเปิดเผยสำเร็จ จะบันทึกการเลือกของผู้เล่นใน player_choice และเปลี่ยนสถานะของ player_revealed เป็น true
เมื่อผู้เล่นทั้งสองเปิดเผยข้อมูลครบแล้ว ฟังก์ชันจะเรียก _checkWinnerAndPay() เพื่อตัดสินผลแพ้-ชนะ

function reveal(bytes32 revealHash, uint choice) public {

    require(numPlayer == 2, "Two players are required to start the game");
    require(!player_not_played[msg.sender], "Player has not committed yet");
    require(choice >= 0 && choice <= 4, "Invalid choice (0-4 expected)");

    bytes32 storedCommit = player_commitment[msg.sender];
    if (commitReveal.getHash(revealHash) != storedCommit) {
        revert("Commitment hash does not match, try again");
    }

    require(!player_revealed[msg.sender], "Already revealed correctly");
    player_revealHash[msg.sender] = revealHash;
    player_choice[msg.sender] = choice;
    player_revealed[msg.sender] = true;
    numInput++;

    if (numInput == 2) {
        _checkWinnerAndPay();
    }
}

2. function _checkWinnerAndPay() ทำหน้าที่ตัดสินผลแพ้-ชนะและโอนเงินให้ผู้ชนะ
- ดึงข้อมูลการเลือกจาก player_choice และใช้กฎของเกมเพื่อประเมินผล เมื่อทราบผลแพ้-ชนะแล้วจะทำการโอนเงินให้แก่ผู้ชนะหรือคืนเงินให้ทั้งสองฝ่ายในกรณีเสมอ
เมื่อทำการโอนเงินเสร็จแล้วจะรีเซ็ตเกมโดยเรียก resetGame() เพื่อให้พร้อมสำหรับการเริ่มใหม่