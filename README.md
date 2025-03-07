### อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
โดยใช้ 3 ฟังก์ชันหลัก คือ function _checkWinnerAndPay() , function checkTimeout() และ function resetGame()
1. function _checkWinnerAndPay()
ทำหน้าที่ตัดสินผู้ชนะและโอนเงินรางวัลให้ทันที หลังจากที่ทั้งสองฝ่ายเปิดเผยตัวเลือกครบถ้วน
- ดึงตัวเลือกของผู้เล่นจาก mapping player_choice
- ตรวจสอบผลแพ้-ชนะ ใช้เงื่อนไขของเกม Rock-Paper-Scissors-Lizard-Spock (RPSLS) เพื่อตัดสินผล
- รีเซ็ตเกม เรียก resetGame() เพื่อล้างข้อมูลเก่าและเริ่มรอบใหม่

2. function checkTimeout()
ทำหน้าที่คืนเงินให้ผู้เล่นหากเกิด timeout เช่น ผู้เล่นไม่ส่ง input ภายในเวลาที่กำหนด
- ตรวจสอบเงื่อนไข timeout โดยตรวจสอบว่าเกมมีผู้เล่น 2 คนและเวลา timeout เกิดขึ้นแล้ว
- คืนเงินให้ผู้เล่น หากมีผู้เล่นเพียงคนเดียวที่ส่ง input หรือไม่มีใครส่งเลย ระบบจะคืนเงินครึ่งหนึ่งให้ทั้งสองผู้เล่น
- รีเซ็ตเกม เรียก resetGame() เพื่อล้างข้อมูลเก่าและเริ่มรอบใหม่

3. function resetGame()
ทำหน้าที่รีเซ็ตสถานะของเกมหลังจากจบเกมหรือเกิด timeout
- ลบข้อมูลผู้เล่นจาก mapping player_choice, player_not_played, และ player_commitment

### อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
โค้ดนี้ใช้กลไก commit-reveal scheme เพื่อป้องกันการโกง (front-running) โดยใช้
function commitChoice(bytes32 commitmentHash)
ทำหน้าที่รับ commitmentHash จากผู้เล่นเพื่อซ่อนการเลือก
- ตรวจสอบว่ามีผู้เล่น 2 คนและผู้เล่นยังไม่ได้ส่ง commitmentHash มาก่อน
- บันทึก commitmentHash ไว้ใน mapping player_commitment
- อัปเดตสถานะผู้เล่น โดยตั้งค่าสถานะว่าผู้เล่นนี้ส่ง commitmentHash แล้ว


### อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
ใช้ function checkTimeout() ทำหน้าที่คืนเงินให้ผู้เล่นหากเกิด timeout
- ตรวจสอบเงื่อนไข timeout ว่าเกมมีผู้เล่น 2 คนและเวลา timeout เกิดขึ้นแล้ว
- คืนเงินให้ผู้เล่น หากมีผู้เล่นเพียงคนเดียวที่ส่ง input หรือไม่มีใครส่งเลย ระบบจะคืนเงินครึ่งหนึ่งให้ทั้งสองผู้เล่น
- รีเซ็ตเกม เรียก resetGame() เพื่อล้างข้อมูลเก่าและเริ่มรอบใหม่

### อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ 
โดยใช้ 3 ฟังก์ชันหลัก คือ function input(uint choice, string memory randomString) และ function _checkWinnerAndPay()
1. function input(uint choice, string memory randomString)
ทำหน้าที่เปิดเผยการเลือกของผู้เล่น
- ตรวจสอบเงื่อนไขว่ามีผู้เล่น 2 คนและผู้เล่นยังไม่ได้ส่ง input มาก่อน
- ตรวจสอบ commitmentHash โดยคำนวณ commitmentHash ใหม่จาก choice และ randomString แล้วก็เปรียบเทียบกับ commitmentHash ที่บันทึกไว้
- บันทึกการเลือกของผู้เล่นใน mapping player_choice
- ตรวจสอบว่าทั้งสองฝ่ายส่ง input ครบ หากทั้งสองฝ่ายส่ง input ครบ ระบบจะเรียก _checkWinnerAndPay() เพื่อตัดสินผลแพ้-ชนะ

2. function _checkWinnerAndPay()
ทำหน้าที่ตัดสินผู้ชนะและโอนเงินรางวัลให้ทันที หลังจากที่ทั้งสองฝ่ายเปิดเผยตัวเลือกครบถ้วน
- ดึงตัวเลือกของผู้เล่นจาก mapping player_choice
- ตรวจสอบผลแพ้-ชนะ ใช้เงื่อนไขของเกม Rock-Paper-Scissors-Lizard-Spock (RPSLS) เพื่อตัดสินผล
- รีเซ็ตเกม เรียก resetGame() เพื่อล้างข้อมูลเก่าและเริ่มรอบใหม่