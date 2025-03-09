### อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
โค้ดนี้ใช้ 3 ฟังก์ชันหลัก คือ function _checkWinnerAndPay(), function checkTimeout() และ function resetGame()

1. function _checkWinnerAndPay() private {

    uint p0Choice = player_choice[players[0]];

    uint p1Choice = player_choice[players[1]];

    address payable account0 = payable(players[0]);

    address payable account1 = payable(players[1]);


    // ผู้เล่นที่เลือกชนะ

    if ((p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) ||

        (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) ||

        (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) ||

        (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) ||

        (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))) {

        (bool success0, ) = account0.call{value: reward}("");

        require(success0, "Transfer failed");

    } 

    // ผู้เล่นที่แพ้

    else if ((p1Choice == 0 && (p0Choice == 2 || p0Choice == 3)) ||

             (p1Choice == 1 && (p0Choice == 0 || p0Choice == 4)) ||
             
             (p1Choice == 2 && (p0Choice == 1 || p0Choice == 3)) ||

             (p1Choice == 3 && (p0Choice == 1 || p0Choice == 4)) ||

             (p1Choice == 4 && (p0Choice == 0 || p0Choice == 2))) {

        (bool success1, ) = account1.call{value: reward}("");

        require(success1, "Transfer failed");
    } 

    // เสมอกัน: แบ่งรางวัลให้ทั้งสองฝ่าย

    else {

        uint halfReward = reward / 2;

        (bool success0, ) = account0.call{value: halfReward}("");

        (bool success1, ) = account1.call{value: reward - halfReward}("");

        require(success0 && success1, "Transfer failed");

    }


    // รีเซ็ตสถานะเกมหลังจากโอนเงินเสร็จ

    resetGame();

}

จะทำการตัดสินผลการแข่งขัน (หลังจากผู้เล่นทั้งสองได้เปิดเผยตัวเลือกแล้ว) และโอนเงินรางวัลให้กับผู้ชนะ หรือแบ่งเงินให้ทั้งสองฝ่ายในกรณีที่เสมอกัน เมื่อทั้งสองฝ่ายเปิดเผยตัวเลือกครบแล้ว ระบบจะดึงค่า choice จาก mapping player_choice แล้วใช้เงื่อนไข if-else เพื่อตัดสินผลการแข่งขัน จากนั้นจะโอนเงินรางวัลให้กับผู้ชนะ (หรือแบ่งให้กรณีเสมอ) และสุดท้ายเรียก resetGame() เพื่อรีเซ็ตสถานะของเกม ไม่ให้เงินถูก lock ไว้นาน


2. function checkTimeout() ตรวจสอบว่าเกมเกินเวลาที่กำหนด (timeout) หรือไม่ หากเวลา timeout ผ่านไป ( 1 นาที )และยังมีผู้เล่นที่ไม่เปิดเผยตัวเลือกครบ (หรือมีแค่ผู้เล่นเดียวที่เลือก) ระบบจะคืนเงินให้แต่ละฝ่ายครึ่งหนึ่ง แล้วรีเซ็ตเกมด้วย resetGame()

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

3. function resetGame() ใช้รีเซ็ตสถานะของเกมหลังจากที่เกมจบหรือเกิด timeout
ซึ่งจะลบข้อมูลต่างๆ ของผู้เล่นจาก mapping ที่เกี่ยวข้อง เช่น player_choice, player_commitment, player_revealHash  ทำให้เกมพร้อมสำหรับการเริ่มใหม่

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
มีการใช้กลไก commit-reveal เพื่อซ่อนและยืนยันตัวเลือกของผู้เล่น โดยการใช้ function commitChoice และ function reveal เพื่อให้การเลือกของผู้เล่นไม่สามารถถูกมองเห็นโดยฝ่ายตรงข้ามก่อนที่จะเปิดเผย

1. function commitChoice(bytes32 commitmentHash) public {

    require(numPlayer == 2, "Two players are required to start the game");

    require(player_not_played[msg.sender], "Player has already committed");

    player_commitment[msg.sender] = commitmentHash;

    player_not_played[msg.sender] = false;

}


- ผู้เล่นจะใช้ฟังก์ชันนี้ เพื่อทำการ commit ตัวเลือกของตน (ซึ่งถูกแปลงเป็น commitmentHash) ไปยัง Smart Contract
- ฟังก์ชันนี้จะตรวจสอบว่าเกมมีผู้เล่นครบ 2 คนหรือไม่ (numPlayer == 2) และตรวจสอบว่าผู้เล่นนั้นยังไม่ได้ commit มาก่อน (player_not_played[msg.sender]).
- เมื่อผู้เล่น commit ตัวเลือกแล้ว ค่า commitmentHash จะถูกบันทึกไว้ใน player_commitment[msg.sender] หลังจาก commit แล้ว สถานะ player_not_played จะถูกตั้งค่าเป็น false เพื่อบอกว่าได้ทำการ commit แล้ว

กลไก commit นี้ช่วยให้ผู้เล่นไม่สามารถรู้ได้ว่าอีกฝ่ายเลือกอะไรก่อนที่จะเปิดเผย ทำให้ไม่สามารถโกงได้ เช่น ไม่สามารถเลือกตัวเลือกที่เอาชนะคู่แข่งได้หลังจากเห็นตัวเลือกของเขาแล้ว

2. function reveal(bytes32 revealHash, uint choice) public {

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

ซึ่งผู้เล่นสามารถ เปิดเผย (reveal) ตัวเลือกของเขาได้หลังจากที่ได้ commit ไปแล้ว
- ฟังก์ชันนี้จะตรวจสอบว่า ผู้เล่นได้ทำการ commit ตัวเลือกก่อนแล้ว (!player_not_played[msg.sender])
ตัวเลือกที่เปิดเผยนั้นต้องอยู่ในช่วงที่ถูกต้อง (0-4)
- ค่า revealHash ที่เปิดเผยต้องตรงกับ commitmentHash ที่ผู้เล่นได้ทำการ commit ไว้ก่อนหน้า
- หากการตรวจสอบทั้งหมดผ่านไปได้สำเร็จ ตัวเลือกของผู้เล่น (choice) จะถูกบันทึกลงใน player_choice[msg.sender] และสถานะ player_revealed[msg.sender] จะถูกตั้งค่าเป็น true
- เมื่อผู้เล่นทั้งสองได้เปิดเผยตัวเลือกครบแล้ว function _checkWinnerAndPay จะถูกเรียกเพื่อตัดสินผลแพ้-ชนะ และโอนเงินให้ผู้ชนะ

กลไก reveal นี้ช่วยให้ผู้เล่นเปิดเผยตัวเลือกของตนในลำดับที่ถูกต้อง โดยไม่มีการเห็นตัวเลือกของคู่แข่งก่อน การใช้ commitmentHash และ revealHash ช่วยให้การเปิดเผยมีความปลอดภัยและไม่สามารถโกงได้

- ความสัมพันธ์กับโค้ดของ CommitReveal Contract ในส่วนของ Contract CommitReveal จะช่วยให้การคำนวณค่าของ commitmentHash และ revealHash มีความปลอดภัยและมีความเป็นส่วนตัว (ไม่สามารถรู้ได้จนกว่าจะถึงขั้นตอน reveal):

function getHash(bytes32 data) public pure returns(bytes32){

    return keccak256(abi.encodePacked(data));

}


- function getHash ใน CommitReveal ใช้ keccak256 ในการคำนวณ hash ของข้อมูลที่ส่งมา ซึ่งใช้สำหรับการสร้างและตรวจสอบค่า commitmentHash และ revealHash ที่มีความปลอดภัย
- function reveal จะตรวจสอบว่า revealHash ที่ผู้เล่นส่งมาในฟังก์ชันนั้นตรงกับค่า commitmentHash ที่ถูกบันทึกไว้ก่อนหน้านี้ เพื่อยืนยันความถูกต้อง


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

2. function _checkWinnerAndPay() เมื่อผู้เล่นทั้งสองเปิดเผยตัวเลือกแล้ว ฟังก์ชันนี้จะดึงค่าที่ผู้เล่นเลือกมาจาก mapping player_choice จากนั้นใช้กฎของเกม Rock-Paper-Scissors-Lizard-Spock เพื่อตัดสินผลแพ้-ชนะ
- ดึงค่า choice ของผู้เล่น 0 และ 1:

uint p0Choice = player_choice[players[0]];
uint p1Choice = player_choice[players[1]];

- ใช้เงื่อนไข if-else เปรียบเทียบตัวเลือกของทั้งสองฝ่าย เพื่อตัดสินผลว่าผู้เล่น 0 หรือผู้เล่น 1 ชนะ หรือถ้าเสมอกันให้แบ่งรางวัล:

// ผู้เล่นที่เลือกชนะ

    if ((p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) ||

        (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) ||

        (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) ||

        (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) ||

        (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))) {

        (bool success0, ) = account0.call{value: reward}("");

        require(success0, "Transfer failed");

    } 

    // ผู้เล่นที่แพ้

    else if ((p1Choice == 0 && (p0Choice == 2 || p0Choice == 3)) ||

             (p1Choice == 1 && (p0Choice == 0 || p0Choice == 4)) ||
             
             (p1Choice == 2 && (p0Choice == 1 || p0Choice == 3)) ||

             (p1Choice == 3 && (p0Choice == 1 || p0Choice == 4)) ||

             (p1Choice == 4 && (p0Choice == 0 || p0Choice == 2))) {

        (bool success1, ) = account1.call{value: reward}("");

        require(success1, "Transfer failed");
    } 

    // เสมอกัน: แบ่งรางวัลให้ทั้งสองฝ่าย

    else {

        uint halfReward = reward / 2;

        (bool success0, ) = account0.call{value: halfReward}("");

        (bool success1, ) = account1.call{value: reward - halfReward}("");

        require(success0 && success1, "Transfer failed");

    }

หลังจากโอนเงินเสร็จแล้ว เรียกใช้ resetGame() เพื่อรีเซ็ตสถานะของเกม
