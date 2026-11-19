.data
    msg_usage:  .asciiz "Usage: <bin1> <bin2> ...\n"
    msg_bin:    .asciiz "Checksum (Bin): "
    msg_hex:    .asciiz "\nChecksum (Hex): 0x"
    hex_chars:  .asciiz "0123456789ABCDEF"

.text
.globl main

# ==========================================
# โปรแกรมหลัก (รับค่าจาก Command-line)
# ==========================================
main:
    blt  $a0, 2, usage_error        # ถ้า argc < 2 ให้กระโดดไปแจ้งเตือน

    move $s0, $a0                   # เก็บ argc ไว้ใน $s0
    move $s1, $a1                   # เก็บ argv (Base Address) ไว้ใน $s1
    li   $s2, 0                     # sum = 0
    li   $t0, 1                     # i = 1 (ข้าม argv[0] ที่เป็นชื่อโปรแกรม)

# ==========================================
# 1. วนลูปแปลงเลขฐาน 2 และบวกรวมทันที
# ==========================================
outer_loop:
    bge  $t0, $s0, wrap_around      # ถ้า i >= argc ให้จบการรับข้อมูล

    sll  $t3, $t0, 2                # คำนวณ Offset: i * 4 (Pointer ขนาด 4 ไบต์)
    add  $t3, $s1, $t3              # หา Address ของ argv[i]
    lw   $t1, 0($t3)                # โหลด Pointer p = argv[i]
    li   $t2, 0                     # value = 0

inner_loop:
    lb   $t3, 0($t1)                # อ่านตัวอักษรทีละตัว (*p)
    beqz $t3, end_inner             # ถ้าเจอ '\0' (จบข้อความ) ให้ออกจากลูปใน

    addi $t3, $t3, -48              # แปลง ASCII เป็นตัวเลข (*p - '0')
    sll  $t2, $t2, 1                # เลื่อนบิตซ้าย 1 ตำแหน่ง (value << 1)
    add  $t2, $t2, $t3              # บวกบิตปัจจุบันเข้าไปใน value
    addi $t1, $t1, 1                # เลื่อน Pointer ไปตัวถัดไป (p++)
    j    inner_loop                 # วนอ่านตัวอักษรถัดไป

end_inner:
    add  $s2, $s2, $t2              # sum += value
    addi $t0, $t0, 1                # i++
    j    outer_loop                 # วนรับ Argument ชุดถัดไป

# ==========================================
# 2. คำนวณ Wrap-around และ 1's Complement
# ==========================================
wrap_around:
    ble  $s2, 0xFF, complement      # ถ้า sum <= 0xFF (ไม่เกิน 8 บิต) ให้ข้ามไปกลับบิต
    andi $t3, $s2, 0xFF             # ดึง 8 บิตล่าง (sum & 0xFF)
    srl  $s2, $s2, 8                # เลื่อนบิตที่ล้นมาทางขวา (sum >> 8)
    add  $s2, $t3, $s2              # บวกทบกลับเข้าไป
    j    wrap_around                # เช็กซ้ำเผื่อยังเกิน 8 บิต

complement:
    not  $s3, $s2                   # กลับบิตทั้งหมด (1's Complement)
    andi $s3, $s3, 0xFF             # ตัดให้เหลือเฉพาะ 8 บิตล่าง (checksum)

# ==========================================
# 3. แสดงผลลัพธ์ (Binary และ Hex)
# ==========================================
    li   $v0, 4                     # Syscall 4: แสดงข้อความ
    la   $a0, msg_bin               # พิมพ์ "Checksum (Bin): "
    syscall

    li   $t0, 7                     # ตัวนับตำแหน่งบิต i = 7 (เริ่มจากซ้ายสุด)
print_bin:
    bltz $t0, print_hex             # ถ้า i < 0 ให้ไปพิมพ์เลขฐาน 16
    srlv $t3, $s3, $t0              # เลื่อนบิตที่ต้องการมาขวาสุด (checksum >> i)
    andi $a0, $t3, 1                # ดึงค่าบิตขวาสุด (& 1)
    li   $v0, 1                     # Syscall 1: แสดงตัวเลข (0 หรือ 1)
    syscall
    addi $t0, $t0, -1               # i--
    j    print_bin                  # วนพิมพ์บิตถัดไป

print_hex:
    li   $v0, 4                     # Syscall 4: แสดงข้อความ
    la   $a0, msg_hex               # พิมพ์ "\nChecksum (Hex): 0x"
    syscall

    la   $t1, hex_chars             # โหลดตารางตัวอักษรฐาน 16

    srl  $t3, $s3, 4                # ดึง 4 บิตบน (หลักแรกของ Hex)
    add  $t3, $t1, $t3              # หาตำแหน่งตัวอักษรในตาราง
    lb   $a0, 0($t3)                # โหลดตัวอักษรฐาน 16 ตัวแรก
    li   $v0, 11                    # Syscall 11: แสดงตัวอักษร 1 ตัว
    syscall

    andi $t3, $s3, 0x0F             # ดึง 4 บิตล่าง (หลักที่สองของ Hex)
    add  $t3, $t1, $t3              # หาตำแหน่งตัวอักษรในตาราง
    lb   $a0, 0($t3)                # โหลดตัวอักษรฐาน 16 ตัวที่สอง
    li   $v0, 11                    # Syscall 11: แสดงตัวอักษร 1 ตัว
    syscall

    j    exit                       # จบการทำงาน

# ==========================================
# จบการทำงาน / แจ้งเตือน Error
# ==========================================
usage_error:
    li   $v0, 4                     # Syscall 4: แสดงข้อความแจ้งวิธีใช้
    la   $a0, msg_usage
    syscall

exit:
    li   $v0, 10                    # Syscall 10: จบโปรแกรม
    syscall