### อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
โค้ดนี้ใช้ 3 ฟังก์ชันหลัก คือ function _checkWinnerAndPay(), function checkTimeout() และ function resetGame():
1. function _checkWinnerAndPay()ทำหน้าที่ตัดสินผู้ชนะและโอนเงินให้แก่ผู้ชนะทันทีหลังจากที่ผู้เล่นทั้งสองได้เปิดเผยตัวเลือกแล้ว
- ดึงข้อมูลตัวเลือกของผู้เล่น: ฟังก์ชันนี้จะเริ่มต้นโดยการดึงข้อมูลการเลือก (choice) ของผู้เล่นทั้งสองคนจาก  player_choice:

uint p0Choice = player_choice[players[0]];

uint p1Choice = player_choice[players[1]];

ตัวแปร p0Choice และ p1Choice เก็บค่าการเลือกของผู้เล่นแต่ละคน ซึ่งเป็นตัวเลือกจากเกม 0 = Rock, 1 = Paper, 2 = Scissors, 3 = Lizard, 4 = Spock
- การตัดสินผู้ชนะ: ใช้กฎการตัดสินเกมตามตัวเลือกที่ผู้เล่นเลือก โดยใช้เงื่อนไข if-else เพื่อตรวจสอบว่าใครชนะ:
ผู้เล่น 0 (Player 0) หรือคนแรก จะชนะ ถ้าเลือกตัวเลือกที่ชนะตัวเลือกของผู้เล่น 1 (Player 1) หรือคนที่ 2
ซึ่งกฎการชนะจะเป็นไปตามตัวเลือกที่ผู้เล่นทั้งสองเลือก เช่น Rock (0) ชนะ Scissors (2) และ Lizard (3)
ถ้าผลการเลือกของทั้งสองฝ่ายเหมือนกัน (เสมอ) จะทำการแบ่งรางวัลให้ทั้งสองฝ่าย
ถ้าผู้เล่น 1 ชนะ ก็จะโอนเงินให้ผู้เล่น 1 แทน
- การโอนเงินรางวัลให้ผู้ชนะ:
 เมื่อผลการเล่นตัดสินแล้ว ฟังก์ชันจะทำการโอนเงินให้แก่ผู้ชนะโดยใช้ call:

uint rewardForPlayer0 = reward;
(bool success0, ) = payable(players[0]).call{value: rewardForPlayer0}("");
require(success0, "Transfer failed for Player 0");

ในกรณีที่ผู้เล่น 0 ชนะ ระบบจะโอนรางวัลทั้งหมดไปให้ผู้เล่น 0
หากเสมอ จะทำการแบ่งรางวัลให้ทั้งสองฝ่าย:

uint rewardForEach = reward / 2;

(bool success0, ) = payable(players[0]).call{value: rewardForEach}("");

(bool success1, ) = payable(players[1]).call{value: rewardForEach}("");

require(success0 && success1, "Transfer failed");

- การรีเซ็ตเกม: เมื่อการโอนเงินเสร็จสมบูรณ์ ฟังก์ชันจะทำการรีเซ็ตเกม เพื่อให้พร้อมสำหรับการเริ่มต้นใหม่ โดยเรียกใช้ฟังก์ชัน resetGame()

2. function checkTimeout() ทำการตรวจสอบว่าเกมมีผู้เล่น 2 คนและตรวจสอบว่าเวลา timeout เกิดขึ้นแล้ว (ผ่านไป 1 นาที) โดยจะมีเงื่อนไขดังนี้:
- ต้องมีผู้เล่น 2 คน ถ้ามีผู้เล่นน้อยกว่า 2 คน จะไม่สามารถดำเนินเกมได้
- ต้องเป็นเวลาหมด (timeout): จะต้องมีเวลาผ่านไปมากกว่าหรือเท่ากับเวลาที่กำหนด ( 1 นาที) ใน gameTimeout หลังจากที่เกมเริ่มต้น (gameStartTime)
- การคืนเงินให้ผู้เล่น ถ้ามีผู้เล่นเพียงคนเดียวที่ทำการเลือกแล้ว หรือไม่มีผู้เล่นที่ทำการเลือกเลย ก็จะคืนเงินครึ่งหนึ่งให้ผู้เล่นแต่ละคน (reward / 2)
- การโอนเงิน: เงินจะถูกโอนไปยังผู้เล่นทั้งสองคน โดยจะใช้ฟังก์ชัน call{value:} เพื่อโอนเงินกลับไปยังผู้เล่น:
(bool success0, ) = account0.call{value: halfReward}("");
(bool success1, ) = account1.call{value: reward - halfReward}("");
require(success0 && success1, "Transfer failed");
- การรีเซ็ตเกม: เมื่อการโอนเงินเสร็จสมบูรณ์ ฟังก์ชันจะทำการรีเซ็ตเกม เพื่อให้พร้อมสำหรับการเริ่มต้นใหม่ โดยเรียกใช้ฟังก์ชัน resetGame()

3. function resetGame() ใช้รีเซ็ตสถานะของเกมหลังจากที่เกมจบหรือเกิด timeout
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
function commitChoice(bytes32 commitmentHash): ฟังก์ชันนี้รับ commitmentHash จากผู้เล่นซึ่งคำนวณจากการเลือกของผู้เล่นและข้อมูลสุ่ม โดยตรวจสอบว่าเกมมีผู้เล่นครบ 2 คน และผู้เล่นนั้นยังไม่ได้ส่ง commitmentHash ถ้าผู้เล่นยังไม่เคยส่ง commitmentHash มาก่อน ก็จะบันทึก commitmentHash ลงใน player_commitment และเปลี่ยนสถานะผู้เล่นใน player_not_played เป็น false เพื่อบอกว่าได้ทำการ commit แล้ว

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