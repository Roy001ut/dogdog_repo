################# CSC258 Assembly Final Project ###################
# Columns (rewritten from scratch)
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256 (32 units * 8 pixels)
# - Display height in pixels:   256 (32 units * 8 pixels)
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL:      .word 0x10008000     # Bitmap display base address
ADDR_KBRD:      .word 0xffff0000     # Keyboard base address
SCREEN_WIDTH:   .word 32

COLOR_RED:      .word 0xff0000
COLOR_ORANGE:   .word 0xff8800
COLOR_YELLOW:   .word 0xffff00
COLOR_GREEN:    .word 0x00ff00
COLOR_BLUE:     .word 0x0000ff
COLOR_PURPLE:   .word 0x8800ff
COLOR_GRAY:     .word 0x808080
COLOR_BLACK:    .word 0x000000
COLOR_WHITE:    .word 0xffffff

# Board dimensions
BOARD_WIDTH:    .word 6
BOARD_HEIGHT:   .word 12
CELL_SIZE:      .word 8

# Gravity pacing
gravity_counter: .word 0
gravity_speed:   .word 20

# Palette used for random generation
palette:
    .word 0xff0000, 0xff8800, 0xffff00, 0x00ff00, 0x0000ff, 0x8800ff
palette_len: .word 6
palette_index: .word 0

##############################################################################
# Mutable Data
##############################################################################
current_column: .word 0, 0, 0       # top -> bottom
column_x:       .word 2             # spawn near center
column_y:       .word -2            # spawn above board

game_field:     .space 288          # 72 cells
match_buffer:   .space 288

##############################################################################
# Code
##############################################################################
    .text
    .globl main

main:
    jal init_game_field
    jal generate_new_column
    jal check_spawn_collision
    bne $v0, $zero, game_over

main_loop:
    jal handle_input
    jal apply_auto_gravity

    jal clear_screen
    jal draw_border
    jal draw_game_field
    jal draw_current_column

    li $v0, 32
    li $a0, 40
    syscall

    jal check_falling_collision
    beq $v0, $zero, main_loop

    jal lock_column_to_field

    jal clear_screen
    jal draw_border
    jal draw_game_field

    li $v0, 32
    li $a0, 150
    syscall

    jal check_and_clear_matches

    jal clear_screen
    jal draw_border
    jal draw_game_field

    li $v0, 32
    li $a0, 200
    syscall

    jal generate_new_column
    jal check_spawn_collision
    beq $v0, $zero, main_loop

game_over:
    jal clear_screen
    jal draw_border
    jal draw_game_field
    li $v0, 10
    syscall

##############################################################################
# Initialization
##############################################################################
init_game_field:
    la $t0, game_field
    li $t1, 72
    li $t2, 0
init_loop:
    beq $t2, $t1, init_done
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, 1
    j init_loop
init_done:
    jr $ra

##############################################################################
# Input handling
##############################################################################
handle_input:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, $zero, handle_input_done

    lw $t2, 4($t0)
    beq $t2, 0x61, move_left      # a
    beq $t2, 0x64, move_right     # d
    beq $t2, 0x73, soft_drop      # s
    beq $t2, 0x77, rotate_column  # w
    beq $t2, 0x71, quit_game      # q
    j handle_input_done

move_left:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t3, column_x
    beq $t3, $zero, move_left_exit
    addi $a0, $t3, -1
    jal check_horizontal_collision
    bne $v0, $zero, move_left_exit
    addi $t3, $t3, -1
    sw $t3, column_x
move_left_exit:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j handle_input_done

move_right:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t3, column_x
    lw $t4, BOARD_WIDTH
    addi $t4, $t4, -1
    beq $t3, $t4, move_right_exit
    addi $a0, $t3, 1
    jal check_horizontal_collision
    bne $v0, $zero, move_right_exit
    addi $t3, $t3, 1
    sw $t3, column_x
move_right_exit:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j handle_input_done

soft_drop:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal try_step_down
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j handle_input_done

rotate_column:
    lw $t0, current_column
    lw $t1, current_column+4
    lw $t2, current_column+8
    sw $t2, current_column
    sw $t0, current_column+4
    sw $t1, current_column+8
    j handle_input_done

quit_game:
    li $v0, 10
    syscall

handle_input_done:
    jr $ra

##############################################################################
# Gravity and collision
##############################################################################
apply_auto_gravity:
    lw $t0, gravity_counter
    addi $t0, $t0, 1
    lw $t1, gravity_speed
    blt $t0, $t1, store_counter
    li $t0, 0
    jal try_step_down
store_counter:
    sw $t0, gravity_counter
    jr $ra

try_step_down:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_falling_collision
    bne $v0, $zero, try_step_down_blocked
    lw $t0, column_y
    addi $t0, $t0, 1
    sw $t0, column_y
    li $v0, 1
    j try_step_down_done
try_step_down_blocked:
    li $v0, 0
try_step_down_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

check_falling_collision:
    lw $t0, column_y
    lw $t1, BOARD_HEIGHT
    lw $t2, BOARD_WIDTH
    lw $t3, column_x
    li $v0, 0
    li $t4, 0
check_fall_loop:
    beq $t4, 3, check_fall_done
    add $t5, $t0, $t4
    addi $t6, $t5, 1
    bge $t6, $t1, fall_collide
    blt $t6, $zero, check_next_seg
    mul $t7, $t6, $t2
    add $t7, $t7, $t3
    sll $t7, $t7, 2
    la $t8, game_field
    add $t8, $t8, $t7
    lw $t9, 0($t8)
    bne $t9, $zero, fall_collide
check_next_seg:
    addi $t4, $t4, 1
    j check_fall_loop
fall_collide:
    li $v0, 1
check_fall_done:
    jr $ra

check_horizontal_collision:
    lw $t0, column_y
    lw $t1, BOARD_HEIGHT
    lw $t2, BOARD_WIDTH
    move $t3, $a0
    bltz $t3, horiz_block
    bge $t3, $t2, horiz_block
    li $v0, 0
    li $t4, 0
horiz_loop:
    beq $t4, 3, horiz_done
    add $t5, $t0, $t4
    bltz $t5, horiz_next
    bge $t5, $t1, horiz_block
    mul $t6, $t5, $t2
    add $t6, $t6, $t3
    sll $t6, $t6, 2
    la $t7, game_field
    add $t7, $t7, $t6
    lw $t8, 0($t7)
    bne $t8, $zero, horiz_block
horiz_next:
    addi $t4, $t4, 1
    j horiz_loop
horiz_block:
    li $v0, 1
horiz_done:
    jr $ra

##############################################################################
# Locking and matches
##############################################################################
lock_column_to_field:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, column_y
    lw $t1, column_x
    lw $t2, BOARD_WIDTH
    la $t3, game_field
    li $t4, 0
lock_loop:
    beq $t4, 3, lock_done
    add $t5, $t0, $t4
    bltz $t5, skip_lock
    mul $t6, $t5, $t2
    add $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t7, $t3, $t6
    sll $t8, $t4, 2
    lw $t9, current_column($t8)
    sw $t9, 0($t7)
skip_lock:
    addi $t4, $t4, 1
    j lock_loop
lock_done:
    li $t0, -2
    sw $t0, column_y
    li $t1, 2
    sw $t1, column_x
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

check_and_clear_matches:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal clear_match_buffer
    jal find_matches
    beq $v0, $zero, check_clear_done
    jal clear_marked_cells
    jal apply_board_gravity
check_clear_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

clear_match_buffer:
    la $t0, match_buffer
    li $t1, 72
    li $t2, 0
clear_match_loop:
    beq $t2, $t1, clear_match_done
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, 1
    j clear_match_loop
clear_match_done:
    jr $ra

find_matches:
    # Save all $s registers used in this function
    addi $sp, $sp, -32
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $s4, 16($sp)
    sw $s5, 20($sp)
    sw $s6, 24($sp)
    sw $s7, 28($sp)

    lw $t0, BOARD_WIDTH
    lw $t1, BOARD_HEIGHT
    la $t2, game_field
    la $t3, match_buffer
    li $v0, 0
    li $t4, 0
find_row_loop:
    beq $t4, $t1, find_done
    li $t5, 0
find_col_loop:
    beq $t5, $t0, next_row
    mul $t6, $t4, $t0
    add $t6, $t6, $t5
    sll $t7, $t6, 2
    add $t8, $t2, $t7
    lw $t9, 0($t8)
    beq $t9, $zero, advance_col

    addi $s0, $t5, 1
    li $s1, 1
horiz_scan:
    beq $s0, $t0, horiz_eval
    mul $s2, $t4, $t0
    add $s2, $s2, $s0
    sll $s2, $s2, 2
    add $s3, $t2, $s2
    lw $s4, 0($s3)
    bne $s4, $t9, horiz_eval
    addi $s1, $s1, 1
    addi $s0, $s0, 1
    j horiz_scan
horiz_eval:
    blt $s1, 3, vert_check
    li $v0, 1
    li $s5, 0
mark_horiz:
    beq $s5, $s1, vert_check
    mul $s6, $t4, $t0
    add $s6, $s6, $t5
    add $s6, $s6, $s5
    sll $s6, $s6, 2
    add $s7, $t3, $s6
    sw $t9, 0($s7)
    addi $s5, $s5, 1
    j mark_horiz

vert_check:
    addi $s0, $t4, 1
    li $s1, 1
vert_scan:
    beq $s0, $t1, vert_eval
    mul $s2, $s0, $t0
    add $s2, $s2, $t5
    sll $s2, $s2, 2
    add $s3, $t2, $s2
    lw $s4, 0($s3)
    bne $s4, $t9, vert_eval
    addi $s1, $s1, 1
    addi $s0, $s0, 1
    j vert_scan
vert_eval:
    blt $s1, 3, advance_col
    li $v0, 1
    li $s5, 0
mark_vert:
    beq $s5, $s1, advance_col
    mul $s6, $t4, $t0
    add $s6, $s6, $t5
    mul $s7, $s5, $t0
    add $s6, $s6, $s7
    sll $s6, $s6, 2
    add $s7, $t3, $s6
    sw $t9, 0($s7)
    addi $s5, $s5, 1
    j mark_vert

advance_col:
    addi $t5, $t5, 1
    j find_col_loop
next_row:
    addi $t4, $t4, 1
    j find_row_loop
find_done:
    # Restore all $s registers
    lw $s7, 28($sp)
    lw $s6, 24($sp)
    lw $s5, 20($sp)
    lw $s4, 16($sp)
    lw $s3, 12($sp)
    lw $s2, 8($sp)
    lw $s1, 4($sp)
    lw $s0, 0($sp)
    addi $sp, $sp, 32
    jr $ra

clear_marked_cells:
    la $t2, game_field
    la $t3, match_buffer
    li $t5, 0
clear_mark_loop:
    beq $t5, 72, clear_mark_done
    sll $t6, $t5, 2
    add $t7, $t2, $t6
    add $t8, $t3, $t6
    lw $t9, 0($t8)
    beq $t9, $zero, no_clear
    sw $zero, 0($t7)
no_clear:
    addi $t5, $t5, 1
    j clear_mark_loop
clear_mark_done:
    jr $ra

apply_board_gravity:
    lw $t0, BOARD_WIDTH
    lw $t1, BOARD_HEIGHT
    la $t2, game_field
    li $t3, 0                 # column index
column_loop:
    beq $t3, $t0, gravity_done
    addi $t4, $t1, -1         # row pointer (scan from bottom)
    addi $t5, $t1, -1         # write pointer
col_scan:
    bltz $t4, fill_remainder
    mul $t6, $t4, $t0
    add $t6, $t6, $t3
    sll $t6, $t6, 2
    add $t7, $t2, $t6
    lw $t8, 0($t7)
    beq $t8, $zero, next_scan_row
    # move value to write pointer if different row
    mul $t9, $t5, $t0
    add $t9, $t9, $t3
    sll $t9, $t9, 2
    add $s0, $t2, $t9
    sw $t8, 0($s0)
    beq $t7, $s0, keep_write
    sw $zero, 0($t7)
keep_write:
    addi $t5, $t5, -1
next_scan_row:
    addi $t4, $t4, -1
    j col_scan
fill_remainder:
    bltz $t5, next_column
    mul $t6, $t5, $t0
    add $t6, $t6, $t3
    sll $t6, $t6, 2
    add $t7, $t2, $t6
    sw $zero, 0($t7)
    addi $t5, $t5, -1
    j fill_remainder
next_column:
    addi $t3, $t3, 1
    j column_loop
gravity_done:
    jr $ra

##############################################################################
# Drawing helpers
##############################################################################
clear_screen:
    lw $t0, ADDR_DSPL
    li $t1, 0
clear_loop:
    beq $t1, 1024, clear_done
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j clear_loop
clear_done:
    jr $ra

draw_border:
    lw $t0, ADDR_DSPL
    lw $t1, CELL_SIZE
    lw $t4, BOARD_WIDTH
    lw $t5, BOARD_HEIGHT
    lw $t3, COLOR_WHITE

    li $t2, 0
border_left_loop:
    beq $t2, $t5, border_right
    mul $t6, $t2, 32
    mul $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t7, $t0, $t6
    sw $t3, 0($t7)
    addi $t2, $t2, 1
    j border_left_loop

border_right:
    li $t2, 0
    addi $t8, $t4, 1
border_right_loop:
    beq $t2, $t5, border_bottom
    mul $t6, $t2, 32
    mul $t6, $t6, $t1
    add $t6, $t6, $t8
    sll $t6, $t6, 2
    add $t7, $t0, $t6
    sw $t3, 0($t7)
    addi $t2, $t2, 1
    j border_right_loop

border_bottom:
    li $t2, 0
    addi $t9, $t5, 1
border_bottom_loop:
    bgt $t2, $t4, border_done
    mul $s0, $t9, 32
    mul $s0, $s0, $t1
    add $s0, $s0, $t2
    sll $s0, $s0, 2
    add $s1, $t0, $s0
    sw $t3, 0($s1)
    addi $t2, $t2, 1
    j border_bottom_loop
border_done:
    jr $ra

draw_game_field:
    lw $t0, BOARD_WIDTH
    lw $t1, BOARD_HEIGHT
    la $t2, game_field
    li $t3, 0
row_draw_loop:
    beq $t3, $t1, draw_game_done
    li $t4, 0
col_draw_loop:
    beq $t4, $t0, next_draw_row
    mul $t5, $t3, $t0
    add $t5, $t5, $t4
    sll $t6, $t5, 2
    add $t7, $t2, $t6
    lw $t8, 0($t7)
    beq $t8, $zero, skip_cell
    move $a0, $t4
    move $a1, $t3
    move $a2, $t8
    jal draw_cell
skip_cell:
    addi $t4, $t4, 1
    j col_draw_loop
next_draw_row:
    addi $t3, $t3, 1
    j row_draw_loop
draw_game_done:
    jr $ra

draw_current_column:
    lw $t0, column_x
    lw $t1, column_y
    li $t2, 0
column_draw_loop:
    beq $t2, 3, column_draw_done
    add $t3, $t1, $t2
    bltz $t3, draw_next_seg
    lw $t4, BOARD_HEIGHT
    bge $t3, $t4, draw_next_seg
    sll $t5, $t2, 2
    lw $t6, current_column($t5)
    move $a0, $t0
    move $a1, $t3
    move $a2, $t6
    jal draw_cell
draw_next_seg:
    addi $t2, $t2, 1
    j column_draw_loop
column_draw_done:
    jr $ra

draw_cell:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, ADDR_DSPL
    lw $t1, CELL_SIZE
    addi $t2, $a0, 1
    addi $t3, $a1, 1
    mul $t4, $t3, 32
    mul $t4, $t4, $t1
    add $t4, $t4, $t2
    sll $t4, $t4, 2
    add $t6, $t0, $t4
    sw $a2, 0($t6)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Column spawning
##############################################################################
generate_new_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $t0, 0
spawn_loop:
    beq $t0, 3, spawn_done
    jal next_color
    sll $t1, $t0, 2
    sw $v0, current_column($t1)
    addi $t0, $t0, 1
    j spawn_loop
spawn_done:
    li $t1, -2
    sw $t1, column_y
    li $t2, 2
    sw $t2, column_x
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

next_color:
    lw $t0, palette_index
    lw $t1, palette_len
    div $t0, $t1        # $t0 / $t1, 商在LO，余数在HI
    mfhi $t2            # 将余数从HI移到$t2
    sll $t3, $t2, 2
    la $t4, palette
    add $t4, $t4, $t3
    lw $v0, 0($t4)
    addi $t0, $t0, 1
    sw $t0, palette_index
    jr $ra

check_spawn_collision:
    lw $t0, column_x
    lw $t1, column_y
    lw $t2, BOARD_WIDTH
    lw $t3, BOARD_HEIGHT
    la $t4, game_field
    li $v0, 0
    li $t5, 0
spawn_check_loop:
    beq $t5, 3, spawn_check_done
    add $t6, $t1, $t5
    bltz $t6, spawn_next
    bge $t6, $t3, spawn_next
    mul $t7, $t6, $t2
    add $t7, $t7, $t0
    sll $t7, $t7, 2
    add $t8, $t4, $t7
    lw $t9, 0($t8)
    beq $t9, $zero, spawn_next
    li $v0, 1
    j spawn_check_done
spawn_next:
    addi $t5, $t5, 1
    j spawn_check_loop
spawn_check_done:
    jr $ra
