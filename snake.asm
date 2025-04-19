    .text
    .globl main
main:
    # ------------------------------------------------------------
    # RARS Snake Game (wrap‑around) with WASD, hard‑coded MMIO
    # + one 16×16 “golden coin” at a random cell each run
    # ------------------------------------------------------------

    # ----------------------------------------
    # 0) Setup constants & registers
    # ----------------------------------------
    mv    s2, gp          # FB_BASE = 0x10008000
    li    s0, 256         # FULL_WIDTH (pixels)
    li    s1, 16          # CELL_PX
    li    s5, 2           # SEGMENTS (head + 1 body)
    li    s6, 1           # WIDTH_IN_CELLS
    li    s7, 1           # HEIGHT_IN_CELLS
    mul   s8, s6, s1      # SEG_W_PX
    mul   s9, s7, s1      # SEG_H_PX

    li    s10, 4          # START_X (cell)
    li    s11, 6          # START_Y (cell)

    # Colors
    li    s3, 255         # BG = bright green (0x00_00_FF_00)
    slli  s3, s3, 8
    li    a0, 255         # HEAD = bright purple (0x00_FF_00_FF)
    slli  a0, a0, 16
    ori   a0, a0, 255
    li    a1, 127         # BODY = dark purple (0x00_7F_00_7F)
    slli  a1, a1, 16
    ori   a1, a1, 127

    # save head color in s4 (only free s‑reg)
    mv    s4, a0          # S4 = HEAD_COLOR

    li    a2, 0           # dir = 0 (▶)

    # ----------------------------------------
    # 0.1) Generate random coin position in [0..15]
    # ----------------------------------------
    li    a7, 42          # syscall: random integer
    ecall
    mv    t0, a0
    li    t1, 16
    rem   a3, t0, t1      # a3 = coin_x

    li    a7, 42
    ecall
    mv    t0, a0
    rem   a4, t0, t1      # a4 = coin_y

    # ----------------------------------------
    # 1) Draw solid background
    # ----------------------------------------
    li    t1, 0
Y_LOOP:
    bge   t1, s0, DRAW_SNAKE
    li    t2, 0
X_LOOP:
    bge   t2, s0, NEXT_ROW
    mv    t3, s3
STORE_BG:
    mul   t5, t1, s0
    add   t5, t5, t2
    slli  t5, t5, 2
    add   t5, t5, s2
    sw    t3, 0(t5)
    addi  t2, t2, 1
    j     X_LOOP
NEXT_ROW:
    addi  t1, t1, 1
    j     Y_LOOP

# ----------------------------------------
# 2) Draw Initial Snake (head + body)
# ----------------------------------------
DRAW_SNAKE:
    li    t6, 0
SEG_LOOP:
    bge   t6, s5, DRAW_COIN
    beqz  t6, HEAD_COLOR_SEG
    mv    t3, a1        # body color from a1
    j     DO_DRAW
HEAD_COLOR_SEG:
    mv    t3, s4        # head color from s4
DO_DRAW:
    jal   ra, DRAW_SEGMENTS
    addi  t6, t6, 1
    j     SEG_LOOP

# ----------------------------------------
# 2.1) Draw Golden Coin at (a3,a4)
# ----------------------------------------
DRAW_COIN:
    mv    t0, a3
    mul   t0, t0, s1        # x_offset_pixels
    mv    t1, a4
    mul   t1, t1, s1
    mul   t1, t1, s0        # y_offset_pixels*FULL_WIDTH

    li    t2, 0             # row = 0
COIN_ROW:
    bge   t2, s1, COIN_DONE
    li    t3, 0             # col = 0
COIN_COL:
    bge   t3, s1, NEXT_COIN_ROW
    mul   t4, t2, s0        # row*FULL_WIDTH
    add   t4, t4, t1        # + y_offset
    add   t4, t4, t0        # + x_offset
    add   t4, t4, t3        # + col
    slli  t4, t4, 2
    add   t4, t4, s2        # + FB_BASE
    li    t5, 0x00FFD700    # gold colour
    sw    t5, 0(t4)
    addi  t3, t3, 1
    j     COIN_COL
NEXT_COIN_ROW:
    addi  t2, t2, 1
    j     COIN_ROW
COIN_DONE:
    j     START_GAME

# ----------------------------------------
# 3) Main Game Loop
# ----------------------------------------
START_GAME:
MOVEMENT_LOOP:
    li    t0, 0xFFFF0000
    lb    t1, 0(t0)
    beqz  t1, SKIP_INPUT
    li    t0, 0xFFFF0004
    lb    t1, 0(t0)
    li    t2, 'W'
    beq   t1, t2, SET_UP
    li    t2, 'S'
    beq   t1, t2, SET_DOWN
    li    t2, 'A'
    beq   t1, t2, SET_LEFT
    li    t2, 'D'
    beq   t1, t2, SET_RIGHT
    j     SKIP_INPUT
SET_UP:
    li    a2, 1
    j     SKIP_INPUT
SET_DOWN:
    li    a2, 2
    j     SKIP_INPUT
SET_LEFT:
    li    a2, 3
    j     SKIP_INPUT
SET_RIGHT:
    li    a2, 0
SKIP_INPUT:

    # Clear previous snake segments
    li    t6, 0
CLEAR_SEGMENTS:
    bge   t6, s5, UPDATE_POS
    mv    t3, s3
    jal   ra, DRAW_SEGMENTS
    addi  t6, t6, 1
    j     CLEAR_SEGMENTS

UPDATE_POS:
    li    t0, 0
    beq   a2, t0, DIR_RIGHT
    li    t0, 1
    beq   a2, t0, DIR_UP
    li    t0, 2
    beq   a2, t0, DIR_DOWN
    j     DIR_LEFT
DIR_RIGHT:
    addi  s10, s10, 1
    j     WRAP_POS
DIR_UP:
    addi  s11, s11, -1
    j     WRAP_POS
DIR_DOWN:
    addi  s11, s11, 1
    j     WRAP_POS
DIR_LEFT:
    addi  s10, s10, -1

WRAP_POS:
    li    t0, 16
    blt   s10, t0, WRAP_Y
    li    s10, 0
WRAP_Y:
    li    t0, 0
    bge   s10, t0, CHECK_Y_NEG
    li    s10, 15
CHECK_Y_NEG:
    li    t0, 16
    blt   s11, t0, REDRAW
    li    s11, 0
REDRAW:

    # Draw snake at new position
    li    t6, 0
REDRAW_SEGMENTS:
    bge   t6, s5, DELAY
    beqz  t6, RED_HEAD_SEG
    mv    t3, a1        # body color
    j     RED_DRAW
RED_HEAD_SEG:
    mv    t3, s4        # head color
RED_DRAW:
    jal   ra, DRAW_SEGMENTS
    addi  t6, t6, 1
    j     REDRAW_SEGMENTS

DELAY:
    li    t5, 80000
WAIT:
    addi  t5, t5, -1
    bnez  t5, WAIT
    j     MOVEMENT_LOOP

# DRAW_SEGMENTS subroutine
DRAW_SEGMENTS:
    mul   t0, t6, s6
    add   t0, t0, s10
    mul   t0, t0, s1

    mul   t1, s11, s1
    mul   t1, t1, s0

    li    t2, 0
DRAW_DY_LOOP:
    bge   t2, s9, END_SEG
    li    t4, 0
DRAW_DX_LOOP:
    bge   t4, s8, NEXT_Y
    mul   t5, t2, s0
    add   t5, t5, t1
    add   t5, t5, t0
    add   t5, t5, t4
    slli  t5, t5, 2
    add   t5, t5, s2
    sw    t3, 0(t5)
    addi  t4, t4, 1
    j     DRAW_DX_LOOP
NEXT_Y:
    addi  t2, t2, 1
    j     DRAW_DY_LOOP
END_SEG:
    jr    ra

# Exit (never reached)
EXIT:
    li    a7, 10
    ecall
