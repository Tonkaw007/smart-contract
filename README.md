### อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
โดยใช้ 3 ฟังก์ชันหลัก ได้แก่ function _checkWinnerAndPay(), function refund() และ function withdraw()
1. function _checkWinnerAndPay()
function นี้ใช้ตัดสินผู้ชนะและโอนเงินรางวัลให้ทันที หลังจากที่ทั้งสองฝ่ายเปิดเผยตัวเลือกครบ ซึ่งทำการตรวจสอบตัวเลือกของทั้งสองฝ่ายและเปรียบเทียบว่าใครเป็นผู้ชนะตามกติกา Rock-Paper-Scissors-Lizard-Spock (5 choice)
ถ้ามีผู้ชนะ จะโอนเงินรางวัลทั้งหมดไปยังผู้ชนะ
แต่ถ้าเสมอกัน เงินรางวัลจะถูกแบ่งคนละครึ่ง
หลังจากจบเกม จะเรียก function _resetGame() เพื่อล้างข้อมูลเก่าและเริ่มรอบใหม่

2. function refund()
function นี้ใช้คืนเงินให้กับผู้เล่นหากมีแค่คนเดียวเข้าร่วมเกม แล้วไม่มีใครมาเป็นผู้เล่นที่สองภายในเวลาที่กำหนด ซึ่งทำการตรวจสอบว่ามีผู้เล่นแค่คนเดียว (numPlayer == 1)
และก็ตรวจสอบว่าเลยกำหนดเวลาสำหรับการส่งค่า commit (block.timestamp > commitDeadline) ของผู้เล่นคนที่สอง ก็จะโอนเงินรางวัลกลับไปให้ผู้เล่นคนเดียวที่เข้าร่วม
และรีเซ็ตเกมเพื่อล้างข้อมูลและเตรียมเกมใหม่

3. function withdraw()
function นี้อนุญาตให้ผู้เล่นสามารถถอนเงินได้หากเกมค้างหรือมีความล่าช้า ซึ่งทำการตรวจสอบว่ามีผู้เล่นครบ 2 คน (numPlayer == 2)
แล้วก็ตรวจสอบว่าเวลาผ่านไปเกิน 2 นาทีแล้ว (timeUnit.elapsedSeconds() > 120)
อนุญาตให้ผู้เล่นถอนเงินของตัวเองครึ่งหนึ่งออกมาได้ (reward / 2)  เพื่อป้องกันการล็อกเงินไว้ใน contract

### อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
โดยใช้ 2 ฟังก์ชันหลัก ได้แก่ function commitMove(bytes32 dataHash), function revealMove(string memory choice, string memory secret) 

1. function commitMove(bytes32 dataHash)
function นี้ใช้เพื่อให้ผู้เล่นทำการ commit ค่าเลือกของตัวเอง โดยแฮชค่าที่เลือกและรหัสลับ (secret) ก่อน แล้วส่งมาเป็นค่า dataHash
โดยกำหนดให้ต้องมีผู้เล่นครบ 2 คน (numPlayer == 2), ต้องอยู่ในช่วงเวลาที่กำหนด (block.timestamp <= commitDeadline)
, ต้องยังไม่ได้ commit มาก่อน (player_not_played[msg.sender])
แล้วก็ทำการ commit ค่าแฮช โดยเรียก commitReveal.commit(dataHash)
และเก็บค่า commit ไว้ใน player_commit[msg.sender]
ซึ่งยังไม่มีใครรู้ว่าเลือกอะไรไป จนกว่าจะ reveal

2. function revealMove(string memory choice, string memory secret)
function นี้ใช้เปิดเผยค่าเลือกของผู้เล่น โดยตรวจสอบว่าแฮชของ (choice, secret) ตรงกับค่า commitMove() ที่ส่งมาก่อนหน้านี้หรือไม่
โดยกำหนดให้ต้องมีผู้เล่นครบ 2 คน (numPlayer == 2), ต้องอยู่ในช่วงเวลาที่กำหนด
- block.timestamp > commitDeadline → หมดช่วง commit
- block.timestamp <= revealDeadline → ยังอยู่ในช่วง reveal
แล้วก็ตรวจสอบว่าค่า reveal ตรงกับ commit โดยสร้างค่าแฮช revealHash = keccak256(abi.encodePacked(choice, secret))
และเรียก commitReveal.reveal(revealHash) เพื่อตรวจสอบ
บันทึกตัวเลือกของผู้เล่น (player_choice[msg.sender] = getChoice(choice))
อัปเดตสถานะว่าได้ reveal แล้ว (player_not_played[msg.sender] = false)
ถ้าทั้งสองคน reveal ครบ (numInput == 2) ก็จะสามารถตัดสินผลลัพธ์ได้ (_checkWinnerAndPay())



### อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
โดยใช้ 2 ฟังก์ชัน คือ function refund() และ function withdraw() ในการช่วยแก้ปัญหา
1. function refund()
function นี้ใช้คืนเงินให้กับผู้เล่นหากมีแค่คนเดียวเข้าร่วมเกม แล้วไม่มีใครมาเป็นผู้เล่นที่สองภายในเวลาที่กำหนด ซึ่งทำการตรวจสอบว่ามีผู้เล่นแค่คนเดียว (numPlayer == 1)
และก็ตรวจสอบว่าเลยกำหนดเวลาสำหรับการส่งค่า commit (block.timestamp > commitDeadline) ของผู้เล่นคนที่สอง ก็จะโอนเงินรางวัลกลับไปให้ผู้เล่นคนเดียวที่เข้าร่วม
และรีเซ็ตเกมเพื่อล้างข้อมูลและเตรียมเกมใหม่

2. function withdraw()
function นี้อนุญาตให้ผู้เล่นสามารถถอนเงินได้หากเกมค้างหรือมีความล่าช้า ซึ่งทำการตรวจสอบว่ามีผู้เล่นครบ 2 คน (numPlayer == 2)
แล้วก็ตรวจสอบว่าเวลาผ่านไปเกิน 2 นาทีแล้ว (timeUnit.elapsedSeconds() > 120)
อนุญาตให้ผู้เล่นถอนเงินของตัวเองครึ่งหนึ่งออกมาได้ (reward / 2) 

### อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ 
ใช้ function revealMove() เพื่อนำค่าที่ commit ไว้ออกมาเปิดเผย
โดยตรวจสอบว่าเกมอยู่ในช่วงเวลา reveal และใช้ keccak256 แฮชค่า (choice + secret) เพื่อตรวจสอบว่าตรงกับค่าที่ commit หรือไม่
หากผู้เล่นทั้งสองเปิดเผยตัวเลือกครบแล้ว จะเรียก function_checkWinnerAndPay() เพื่อตัดสินผลแพ้ชนะ และแจกจ่ายรางวัลให้กับผู้ชนะ หรือแบ่งรางวัลหากเสมอกัน

function _checkWinnerAndPay()
function นี้ทำหน้าที่ ตรวจสอบผลแพ้ชนะและแจกจ่ายรางวัล ให้กับผู้ชนะหรือแบ่งรางวัลหากเสมอกัน
- ดึงค่าตัวเลือกของผู้เล่นจาก mapping player_choice
p0Choice = player_choice[players[0]];
p1Choice = player_choice[players[1]];

- กำหนดที่อยู่ของผู้เล่น
account0 = payable(players[0]);
account1 = payable(players[1]);
ใช้ payable เพื่อเตรียมโอน ETH ให้กับผู้เล่น

- ตรวจสอบผลแพ้ชนะ โดยใช้เงื่อนไข (p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice
ระบบจะตรวจสอบว่าผู้เล่นที่สอง (p1Choice) ชนะ หรือไม่ ถ้าชนะก็โอน reward ให้ account1
ถ้า (p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice เป็นจริง แสดงว่าผู้เล่นที่หนึ่ง (p0Choice) ชนะ และรับรางวัล

- กรณีเสมอกัน
ถ้าทั้งสองตัวเลือกไม่เข้าเงื่อนไขแพ้ชนะ ระบบจะแบ่งเงินรางวัล คนละครึ่ง
account0.transfer(reward / 2);
account1.transfer(reward / 2);

- รีเซ็ตเกม
_resetGame();
คืนค่าตัวแปรของเกมทั้งหมดเพื่อให้เริ่มรอบใหม่ได้