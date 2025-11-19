################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own
# creation, and will indicate otherwise when it is not.
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
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:    .word 0xffff0000
SCREEN_WIDTH:  .word 32

COLOR_RED:     .word 0xff0000
COLOR_ORANGE:  .word 0xff8800
COLOR_YELLOW:  .word 0xffff00
COLOR_GREEN:   .word 0x00ff00
COLOR_BLUE:    .word 0x0000ff
COLOR_PURPLE:  .word 0x8800ff
COLOR_GRAY:    .word 0x808080
COLOR_BLACK:   .word 0x000000

gravity_counter: .word 0
gravity_speed:   .word 20  # Fall every 20 frames (adjust as needed)
##############################################################################
# Mutable Data
##############################################################################

current_column: .word 0xff0000, 0x00ff00, 0x0000ff
column_x:       .word 2
column_y:       .word 0

game_field:     .space 288
match_buffer:   .space 288
##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal init_game_field
    jal generate_new_column

    # Check if initial spawn is blocked (should not happen on empty field)
    jal check_initial_collision
    bne $v0, $zero, game_over

game_loop:
    # Check keyboard input
    jal check_keyboard

    # Apply automatic gravity (makes column fall slowly)
    jal apply_auto_gravity

    # Clear screen and redraw everything
    jal clear_screen
    jal draw_border
    jal draw_game_field
    jal draw_current_column

    # Add a small delay to make the game playable (not too fast)
    li $v0, 32          # syscall: sleep
    li $a0, 50          # sleep for 50 milliseconds
    syscall

    # Check if current column hit the bottom or another piece
    jal check_bottom_collision
    beq $v0, $zero, game_loop   # No collision, continue loop

    # Collision detected - lock the column to the field
    jal lock_column_to_field

    # Check for matches and clear them (with cascading)
    jal check_and_clear_matches

    # Redraw after clearing
    jal clear_screen
    jal draw_border
    jal draw_game_field

    # Generate new column
    jal generate_new_column

    # Check if new column can spawn (game over check)
    jal check_initial_collision
    bne $v0, $zero, game_over

    # Continue game loop
    j game_loop

game_over:
    # Display game over (draw final state)
    jal clear_screen
    jal draw_border
    jal draw_game_field

    # Exit gracefully
    li $v0, 10
    syscall


##############################################################################
# Functions
##############################################################################
check_keyboard:
    lw $t0, ADDR_KBRD           # $t0 = base address
    lw $t1, 0($t0)              # check if pressed

    beq $t1, 1, key_pressed     # if pressed, jump
    jr $ra                      # else, jump back

key_pressed:
    lw $t2, 4($t0)

    # check which key pressed
    beq $t2, 0x61, respond_a    # 'a' = 0x61
    beq $t2, 0x64, respond_d    # 'd' = 0x64
    beq $t2, 0x73, respond_s    # 's' = 0x73
    beq $t2, 0x77, respond_w    # 'w' = 0x77
    beq $t2, 0x71, respond_q    # 'q' = 0x71

    jr $ra                      # other keys, ignore, and jump back

# key a pressed.
respond_a:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t3, column_x            # get prevous col
    beq $t3, 0, respond_a_done  # check if hit the leftmost, true: jump out

    # Check if moving left would cause collision
    addi $a0, $t3, -1           # new x position (left)
    jal check_horizontal_collision
    bne $v0, $zero, respond_a_done  # collision detected, don't move

    lw $t3, column_x            # reload column_x
    addi $t3, $t3, -1           # col - 1
    sw $t3, column_x            # put new col back
respond_a_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


respond_d:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t3, column_x                # get previous col
    li $t4, 5                       # set rightmost as 5
    beq $t3, $t4, respond_d_done    # check if hit the rightmist, true: jump out

    # Check if moving right would cause collision
    addi $a0, $t3, 1                # new x position (right)
    jal check_horizontal_collision
    bne $v0, $zero, respond_d_done  # collision detected, don't move

    lw $t3, column_x                # reload column_x
    addi $t3, $t3, 1                # col + 1
    sw $t3, column_x                # reload
respond_d_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


respond_s:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Check if can move down (use existing collision detection)
    jal check_bottom_collision
    bne $v0, $zero, respond_s_done  # collision detected, don't move

    # No collision, move down
    lw $t3, column_y
    addi $t3, $t3, 1
    sw $t3, column_y

respond_s_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


respond_w:
    # get initial color data
    la $t0, current_column
    lw $t1, 0($t0)
    lw $t2, 4($t0)
    lw $t3, 8($t0)
    # change order (1,2,3) -> (2, 3, 1)
    sw $t2, 0($t0)
    sw $t3, 4($t0)
    sw $t1, 8($t0)
    # done
    jr $ra


respond_q:
    li $v0, 10                      # Quit gracefully
	syscall


draw_pixel_at_screen:
# Draw a single pixel.
# input：$a0=row, $a1=col, $a2=color
    lw $t0, ADDR_DSPL # $t0 = initial location
    lw $t1, SCREEN_WIDTH # $t1 = 8

    # offset
    mul $t2, $a0, $t1 # row * 8, get row unit num
    add $t2, $t2, $a1 # add with col unit num
    sll $t2, $t2, 2   # $t2 * 4 get actual location
    add $t2, $t0, $t2 # using $t2 store final location

    sw $a2, 0($t2)    # write color

    jr $ra


draw_game_pixel:
# Draw a single pixel with offset 1 to fit the game border.
# input：$a0=row (y), $a1=col (x), $a2=color
    # use $sp to store previous $ra
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # change offset
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    add $a2, $a2, $zero
    # draw game pixel
    jal draw_pixel_at_screen

    # resume previous $ra
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_horizontal_line:
# 参数：$a0=行, $a1=起始列, $a2=结束列, $a3=颜色
    # use $sp to store previous $ra
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    # store arguments into $t0~$t3
    add $s0, $zero, $a0
    add $s1, $zero, $a1
    add $s2, $zero, $a2
    add $s3, $zero, $a3

draw_h_loop:
    # condition
    beq $s1, $s2, draw_h_done
    # set up new $a
    add $a0, $s0, $zero  # row num
    add $a1, $s1, $zero  # current col num
    add $a2, $s3, $zero  # color
    jal draw_pixel_at_screen

    addi $s1, $s1, 1     # current col num ++1
    j draw_h_loop

draw_h_done:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


draw_vertical_line:
# 参数：$a0=列, $a1=起始行, $a2=结束行, $a3=颜色
    # use $sp to store previous $ra
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    # store arguments into $t0~$t3
    add $s0, $zero, $a0
    add $s1, $zero, $a1
    add $s2, $zero, $a2
    add $s3, $zero, $a3

draw_v_loop:
    # condition
    beq $s1, $s2, draw_v_done
    # store arguments into $t0~$t3
    add $a1, $s0, $zero  # col num
    add $a0, $s1, $zero  # current row num
    add $a2, $s3, $zero  # color
    jal draw_pixel_at_screen

    addi $s1, $s1, 1     # row num ++1
    j draw_v_loop

draw_v_done:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


clear_screen:
# Clear the entire screen to black
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)

    la $t0, COLOR_BLACK
    lw $s2, 0($t0)      # $s2 = black color

    li $s0, 0           # row = 0

clear_row_loop:
    bge $s0, 14, clear_done     # 14 rows total (0-13)
    li $s1, 0           # col = 0

clear_col_loop:
    bge $s1, 8, clear_next_row  # 8 cols total (0-7)

    # Draw black pixel
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    add $a2, $s2, $zero
    jal draw_pixel_at_screen

    addi $s1, $s1, 1
    j clear_col_loop

clear_next_row:
    addi $s0, $s0, 1
    j clear_row_loop

clear_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


draw_border:
# 参数: N/A
    # use $sp to store previous $ra
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    la $t0, COLOR_GRAY
    lw $t9, 0($t0)
    # top
    li $a0, 0
    li $a1, 0
    li $a2, 8
    add $a3, $t9, $zero
    jal draw_horizontal_line

    # bottom
    li $a0, 13
    li $a1, 0
    li $a2, 8
    add $a3, $t9, $zero
    jal draw_horizontal_line

    # left
    li $a0, 0
    li $a1, 1
    li $a2, 13
    add $a3, $t9, $zero
    jal draw_vertical_line

    # right
    li $a0, 7
    li $a1, 1
    li $a2, 13
    add $a3, $t9, $zero
    jal draw_vertical_line

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


draw_current_column:
# 参数: N/A
    # Use stack to store previous value
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # 保存 $s0
    sw $s1, 8($sp)              # 保存 $s1
    sw $s2, 12($sp)             # 保存 $s2
    sw $s3, 16($sp)

    # Load position and color
    lw $s0, column_x
    lw $s1, column_y
    la $s2, current_column

    # Draw the top gem
    lw $s3, 0($s2)
    add $a0, $s1, $zero
    add $a1, $s0, $zero
    add $a2, $s3, $zero
    jal draw_game_pixel

    # Draw the middle gem
    lw $s3, 4($s2)
    addi $a0, $s1, 1
    add $a1, $s0, $zero
    add $a2, $s3, $zero
    jal draw_game_pixel

    # Draw the bottom gem
    lw $s3, 8($s2)
    addi $a0, $s1, 2
    add $a1, $s0, $zero
    add $a2, $s3, $zero
    jal draw_game_pixel

    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


clear_current_column:
# clear the column when move
    addi $sp, $sp, -16          # store return address
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)

    # get the top gem column position, and get color black
    lw $s0, column_x
    lw $s1, column_y
    la $t0, COLOR_BLACK
    lw $s2, 0($t0)

    # clear the top
    add $a0, $s1, $zero
    add $a1, $s0, $zero
    add $a2, $s2, $zero
    jal draw_game_pixel

    # clear the middle
    addi $a0, $s1, 1
    add $a1, $s0, $zero
    add $a2, $s2, $zero
    jal draw_game_pixel
    # clear the bottom
    addi $a0, $s1, 2
    add $a1, $s0, $zero
    add $a2, $s2, $zero
    jal draw_game_pixel


    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


############################################################################
# M3
init_game_field:
# initialize the game field
    la $t0, game_field  # set space
    li $t1, 72          # set counter

init_loop:
    beq $t1, $zero, init_done   # check counter
    sw $zero, 0($t0)            # write 0 to each grid
    addi $t0, $t0, 4            # move to the next grid
    addi $t1, $t1, -1           # counter decrement
    j init_loop
init_done:
    jr $ra


check_bottom_collision:
# check whether the column hit,
# return $v0 = 1/0

    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    # get the location
    lw $s0, column_x
    lw $s1, column_y

    addi $s2, $s1, 2
    # 1. check if it hit the bottom
    li $t0, 11
    beq $s2, $t0, collision_detected

    # 2. check if it hit other column
    addi $a0, $s2, 1
    add $a1, $s0, $zero
    jal get_field_color
    # recieve $v0 represent the T/F
    bne $v0, $zero, collision_detected # $v0 is True

    #otherwise, no collision
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    li $v0, 0
    jr $ra

collision_detected:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    li $v0, 1
    jr $ra


check_horizontal_collision:
# Check if moving the current column to new_x would cause collision
# $a0 = new_x position to check
# return $v0 = 1 if collision, 0 if OK
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)     # new_x
    sw $s1, 8($sp)     # current_y

    add $s0, $a0, $zero     # new_x
    lw $s1, column_y        # current_y

    # Check all three gem positions
    # Check top gem
    add $a0, $s1, $zero
    add $a1, $s0, $zero
    jal get_field_color
    bne $v0, $zero, h_collision_detected

    # Check middle gem
    addi $a0, $s1, 1
    add $a1, $s0, $zero
    jal get_field_color
    bne $v0, $zero, h_collision_detected

    # Check bottom gem
    addi $a0, $s1, 2
    add $a1, $s0, $zero
    jal get_field_color
    bne $v0, $zero, h_collision_detected

    # No collision
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    li $v0, 0
    jr $ra

h_collision_detected:
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    li $v0, 1
    jr $ra


get_field_color:
# get the color of field at that location
# $a0 = y, $a1 = x
# return $v0 = color
    # check it's inside
    bltz $a0, out_of_bounds
    bgt $a0, 11, out_of_bounds
    bltz $a1, out_of_bounds
    bgt $a1, 5, out_of_bounds
    # load the real index
    li $t0, 6
    mul $t1, $t0, $a0
    add $t1, $t1, $a1
    sll $t1, $t1, 2
    # get the real address and its color
    la $t0, game_field
    add $t0, $t0, $t1
    lw $v0, 0($t0)
    jr $ra

out_of_bounds:
    li $v0, 0
    jr $ra


set_field_color:
# set color to a location
# $a0 = y, $a1 = x, $a2 = color
    addi $sp, $sp, -4
    sw $s0, 0($sp)
    # load the real index
    li $t0, 6
    mul $t1, $t0, $a0
    add $t1, $t1, $a1
    sll $t1, $t1, 2
    # get the real address and write color into it
    la $t0, game_field
    add $t0, $t0, $t1
    sw $a2, 0($t0)   # write color

    lw $s0, 0($sp)
    addi $sp, $sp, 4
    jr $ra


lock_column_to_field:
# lock the current column to the field
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    # get column location
    lw $s0, column_x
    lw $s1, column_y
    la $s2, current_column
    # lock the top
    add $a0, $s1, $zero
    add $a1, $s0, $zero
    lw $a2, 0($s2)
    jal set_field_color
    # lock the middle
    addi $a0, $s1, 1
    add $a1, $s0, $zero
    lw $a2, 4($s2)
    jal set_field_color
    # lock the bottom
    addi $a0, $s1, 2
    add $a1, $s0, $zero
    lw $a2, 8($s2)
    jal set_field_color

    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


draw_game_field:
# Draw all column in the field.
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)

    li $s0, 0       # $s0 = y

draw_field_row_loop:
    li $t0, 12      # set max y
    bge $s0, $t0, draw_field_done       # check if hit

    li $s1, 0       # $s1 = x

draw_field_col_loop:
    li $t0, 6       # set max x
    bge $s1, $t0, draw_field_next_row        # check if hit
    # first, get the color at the location
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    jal get_field_color

    beq $v0, $zero, draw_field_skip     # if $v0 is 0, it's empty
    # then draw the grid
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    add $a2, $v0, $zero
    jal draw_game_pixel

draw_field_skip:
    addi $s1, $s1, 1        # x++
    j draw_field_col_loop

draw_field_next_row:
    addi $s0, $s0, 1        # y++
    j draw_field_row_loop

draw_field_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


check_and_clear_matches:
# check and clear
addi $sp, $sp, -4
    sw $ra, 0($sp)

match_loop:
    jal init_match_buffer

    jal scan_all_color_matches

    jal check_if_any_marked

    beq $v0, $zero, match_loop_done

    jal clear_marked_gems

    jal apply_gravity

    j match_loop

match_loop_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

scan_all_color_matches:
# scan all color
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

    la $t0, COLOR_RED
    lw $s0, 0($t0)
    jal scan_matches_by_color

    la $t0, COLOR_ORANGE
    lw $s0, 0($t0)
    jal scan_matches_by_color

    la $t0, COLOR_YELLOW
    lw $s0, 0($t0)
    jal scan_matches_by_color

    la $t0, COLOR_GREEN
    lw $s0, 0($t0)
    jal scan_matches_by_color

    la $t0, COLOR_BLUE
    lw $s0, 0($t0)
    jal scan_matches_by_color

    la $t0, COLOR_PURPLE
    lw $s0, 0($t0)
    jal scan_matches_by_color

    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra





init_match_buffer:
# initialize the match_buffer, set them 0.
    la $t0, match_buffer
    li $t1, 72  # 72 = 12*6

init_match_loop:
    beq $t1, $zero, init_match_done
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    j init_match_loop

init_match_done:
    jr $ra


scan_matches_by_color:
# scan all the grid by color
# input: $s0 = the color want to detect
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)

    li $s1, 0           # row = 0

color_scan_row_loop:
    bge $s1, 12, color_scan_done

    li $s2, 0           # col = 0

color_scan_col_loop:
    bge $s2, 6, color_scan_next_row

    # check horizontal
    add $a0, $s1, $zero
    add $a1, $s2, $zero
    add $a2, $s0, $zero
    jal check_and_mark_horizontal

    # check vertical
    add $a0, $s1, $zero
    add $a1, $s2, $zero
    add $a2, $s0, $zero
    jal check_and_mark_vertical

    # check diagonal form top left to bottom right
    add $a0, $s1, $zero
    add $a1, $s2, $zero
    add $a2, $s0, $zero
    jal check_and_mark_diagonal_tlbr

    # check diagonal from top right to bottom left
    add $a0, $s1, $zero
    add $a1, $s2, $zero
    add $a2, $s0, $zero
    jal check_and_mark_diagonal_trbl

    addi $s2, $s2, 1        # col ++
    j color_scan_col_loop

color_scan_next_row:
    addi $s1, $s1, 1        # row ++
    j color_scan_row_loop


color_scan_done:
    lw $s3, 12($sp)
    lw $s2, 8($sp)
    lw $s1, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


check_and_mark_horizontal:
# given color, check match left to right and mark
# input: $a0 = row, $a1 = col, $a2, = color
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = row
    sw $s1, 8($sp)              # $s1 = initial col
    sw $s2, 12($sp)             # $s2 = color
    sw $s3, 16($sp)             # $s3 = counter

    # store $a to $s
    add $s0, $a0, $zero
    add $s1, $a1, $zero
    add $s2, $a2, $zero

    # check if the start grid has same color,
    # otherwise, quit
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    jal get_field_color
    bne $v0, $s2, h_no_match

    # then prepare counting
    li $s3, 1           # including start point itself
    li $t0, 1           # initialize offset by one(the next point)

h_count_loop:
    # counting start
    add $t1, $s1, $t0               # initial col add offset
    bge $t1, 6, h_count_done        # make sure stay in the game
    # get the next color
    add $a0, $s0, $zero
    add $a1, $t1, $zero
    jal get_field_color
    # check the color is same
    bne $v0, $s2, h_count_done      # not same, stop counting
    addi $s3, $s3, 1                # same, counter +1
    addi $t0, $t0, 1                # offset +1
    j h_count_loop

h_count_done:
    # check at counter >= 3
    li $t0, 3
    blt $s3, $t0, h_no_match        # no match, quit
    # otherwise, start to mark in match_buffer
    li $t0, 0                       # initial offset in match_buffer(the start point)

h_mark_loop:
    bge $t0, $s3, h_no_match        # finish marking

    add $t1, $s1, $t0               # add the offset to get the marking col
    add $a0, $s0, $zero
    add $a1, $t1, $zero
    jal mark_position_for_deletion

    addi $t0, $t0, 1
    j h_mark_loop

h_no_match:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


check_and_mark_vertical:
# given color, check match top to bottom and mark
# input: $a0 = row, $a1 = col, $a2, = color
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = initial row
    sw $s1, 8($sp)              # $s1 =  col
    sw $s2, 12($sp)             # $s2 = color
    sw $s3, 16($sp)             # $s3 = counter

    # store $a to $s
    add $s0, $a0, $zero
    add $s1, $a1, $zero
    add $s2, $a2, $zero

    # check if the start grid has same color,
    # otherwise, quit
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    jal get_field_color
    bne $v0, $s2, v_no_match

    # then prepare counting
    li $s3, 1           # including start point itself
    li $t0, 1           # initialize offset by one(the next point)

v_count_loop:

    add $t1, $s0, $t0
    bge $t1, 12, v_count_done

    add $a0, $t1, $zero
    add $a1, $s1, $zero
    jal get_field_color

    bne $v0, $s2, v_count_done
    addi $s3, $s3, 1
    addi $t0, $t0, 1
    j v_count_loop

v_count_done:
    li $t0, 3
    blt $s3, $t0, v_no_match

    li $t0, 0
v_mark_loop:
    bge $t0, $s3, v_no_match

    add $t1, $s0, $t0
    add $a0, $t1, $zero
    add $a1, $s1, $zero
    jal mark_position_for_deletion

    addi $t0, $t0, 1
    j v_mark_loop

v_no_match:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


check_and_mark_diagonal_tlbr:
# given color, check match top left to bottom right and mark
# input: $a0 = row, $a1 = col, $a2, = color
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = initial row
    sw $s1, 8($sp)              # $s1 = initial col
    sw $s2, 12($sp)             # $s2 = color
    sw $s3, 16($sp)             # $s3 = counter

    # store $a to $s
    add $s0, $a0, $zero
    add $s1, $a1, $zero
    add $s2, $a2, $zero

    # check if the start grid has same color,
    # otherwise, quit
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    jal get_field_color
    bne $v0, $s2, d_tlbr_no_match

    # then prepare counting
    li $s3, 1           # including start point itself
    li $t0, 1           # initialize offset by one(the next point)

d_tlbr_count_loop:
    # calculating and check the next in the game
    add $t1, $s0, $t0                       # get the next row
    bge $t1, 12, d_tlbr_count_done          # check in boundary

    add $t2, $s1, $t0                       # get the next col
    bge $t2, 6, d_tlbr_count_done           # check in boundary

    # get the next color
    add $a0, $t1, $zero
    add $a1, $t2, $zero
    jal get_field_color

    bne $v0, $s2, d_tlbr_count_done         # color not match, quit
    addi $s3, $s3, 1                        # otherwise, counter++
    addi $t0, $t0, 1                        # offset++
    j d_tlbr_count_loop

d_tlbr_count_done:
    li $t0, 3
    blt $s3, $t0, d_tlbr_no_match

    li $t0, 0
d_tlbr_mark_loop:
    bge $t0, $s3, d_tlbr_no_match

    add $t1, $s0, $t0
    add $t2, $s1, $t0
    add $a0, $t1, $zero
    add $a1, $t2, $zero
    jal mark_position_for_deletion

    addi $t0, $t0, 1
    j d_tlbr_mark_loop

d_tlbr_no_match:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


check_and_mark_diagonal_trbl:
# given color, check match top right to bottom left and mark
# input: $a0 = row, $a1 = col, $a2, = color
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = initial row
    sw $s1, 8($sp)              # $s1 = initial col
    sw $s2, 12($sp)             # $s2 = color
    sw $s3, 16($sp)             # $s3 = counter

    # store $a to $s
    add $s0, $a0, $zero
    add $s1, $a1, $zero
    add $s2, $a2, $zero

    # check if the start grid has same color,
    # otherwise, quit
    add $a0, $s0, $zero
    add $a1, $s1, $zero
    jal get_field_color
    bne $v0, $s2, d_trbl_no_match

    # then prepare counting
    li $s3, 1           # including start point itself
    li $t0, 1           # initialize offset by one(the next point)

d_trbl_count_loop:
    add $t1, $s0, $t0
    bge $t1, 12, d_trbl_count_done

    sub $t2, $s1, $t0
    blt $t2, $zero, d_trbl_count_done


    add $a0, $t1, $zero
    add $a1, $t2, $zero
    jal get_field_color

    bne $v0, $s2, d_trbl_count_done
    addi $s3, $s3, 1
    addi $t0, $t0, 1
    j d_trbl_count_loop

d_trbl_count_done:
    li $t0, 3
    blt $s3, $t0, d_trbl_no_match

    li $t0, 0
d_trbl_mark_loop:
    bge $t0, $s3, d_trbl_no_match

    add $t1, $s0, $t0
    addi $t2, $s1, 0
    sub $t2, $t2, $t0
    add $a0, $t1, $zero
    add $a1, $t2, $zero
    jal mark_position_for_deletion

    addi $t0, $t0, 1
    j d_trbl_mark_loop
d_trbl_no_match:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


mark_position_for_deletion:
# mark a spot in match_buffer(set as 1)
# input: $a0 = row, $a1 = col
    # calculate offset = (row * 6 + col) * 4
    li $t0, 6
    mul $t1, $a0, $t0
    add $t1, $t1, $a1
    sll $t1, $t1, 2

    # mark this in match_buffer
    la $t0, match_buffer
    add $t0, $t0, $t1
    li $t2, 1
    sw $t2, 0($t0)

    jr $ra


check_if_any_marked:
# check match_buffer has marked spot one by one
# no input
# return 1 when find one spot, 0 otherwise
    la $t0, match_buffer
    li $t1, 72                              # has 72 spot to check

check_marked_loop:
    beq $t1, $zero, no_marked_found         # go through all spots

    lw $t2, 0($t0)
    bne $t2, $zero, marked_found            # $t2 = 1, which is marked

    addi $t0, $t0, 4                        # move to next spot
    addi $t1, $t1, -1                       # counter-1
    j check_marked_loop


no_marked_found:
    li $v0, 0
    jr $ra

marked_found:
    li $v0, 1
    jr $ra


clear_marked_gems:
# clear all marked gems, and set them to be 0
# no input
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 0                           # $t0 = row

clear_marked_row_loop:
    bge $t0, 12, clear_marked_done

    li $t1, 0                           # $t1 = col

clear_marked_col_loop:
    bge $t1, 6, clear_marked_next_row   # if col >= 6, enter the next row

    li $t2, 6
    mul $t3, $t0, $t2
    add $t3, $t3, $t1
    sll $t3, $t3, 2

    la $t2, match_buffer
    add $t2, $t2, $t3
    lw $t3, 0($t2)

    beq $t3, $zero, clear_marked_col_next

    add $a0, $t0, $zero
    add $a1, $t1, $zero
    li $a2, 0
    jal set_field_color

clear_marked_col_next:
    addi $t1, $t1, 1
    j clear_marked_col_loop

clear_marked_next_row:
    addi $t0, $t0, 1
    j clear_marked_row_loop

clear_marked_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


apply_gravity:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = current col
    sw $s1, 8($sp)              # $s1 = write_row (where to place next gem)
    sw $s2, 12($sp)             # $s2 = read_row (scanning for gems)
    sw $s3, 16($sp)             # $s3 = color

    li $s0, 0                   # start with column 0

gravity_column_loop:
    bge $s0, 6, gravity_complete    # processed all 6 columns?

    # For this column, compact all gems downward
    li $s1, 11                  # write_row starts at bottom (row 11)
    li $s2, 11                  # read_row starts at bottom too

gravity_scan_loop:
    bltz $s2, gravity_next_column   # scanned all rows in this column?

    # Get color at current read position
    add $a0, $s2, $zero         # y = read_row
    add $a1, $s0, $zero         # x = current column
    jal get_field_color
    add $s3, $v0, $zero         # save color

    beq $s3, $zero, gravity_scan_next   # empty? skip

    # Found a gem at read_row, need to move it to write_row
    bne $s1, $s2, gravity_move_gem      # same position? no need to move

    # Same position, just decrement write_row
    addi $s1, $s1, -1
    j gravity_scan_next

gravity_move_gem:
    # Move gem from read_row to write_row
    # Set gem at write_row
    add $a0, $s1, $zero         # y = write_row
    add $a1, $s0, $zero         # x = current column
    add $a2, $s3, $zero         # color
    jal set_field_color

    # Clear gem at read_row
    add $a0, $s2, $zero         # y = read_row
    add $a1, $s0, $zero         # x = current column
    li $a2, 0                   # color = 0 (empty)
    jal set_field_color

    # Move write_row up
    addi $s1, $s1, -1

gravity_scan_next:
    addi $s2, $s2, -1           # move read_row up
    j gravity_scan_loop

gravity_next_column:
    addi $s0, $s0, 1            # next column
    j gravity_column_loop

gravity_complete:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


apply_auto_gravity:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

    # Load and increment gravity counter
    lw $t0, gravity_counter
    lw $t1, gravity_speed
    addi $t0, $t0, 1
    sw $t0, gravity_counter

    # Check if it's time to fall
    blt $t0, $t1, auto_gravity_done

    # Reset counter
    sw $zero, gravity_counter

    # Move column down by 1
    lw $t2, column_y
    li $t3, 9  # Max y position (same as in respond_s)
    beq $t2, $t3, auto_gravity_done
    addi $t2, $t2, 1
    sw $t2, column_y

auto_gravity_done:
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra


check_game_over:
# check if game is over
# return $v0 = 1 (game over), 0 (continue)
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # check row 0
    li $t0, 0               # row = 0
    li $t1, 0               # col = 0

check_top_row:
    bge $t1, 6, check_row_1

    add $a0, $t0, $zero
    add $a1, $t1, $zero
    jal get_field_color

    bne $v0, $zero, game_over_detected  # if row 0 has gem, game over

    addi $t1, $t1, 1
    j check_top_row

check_row_1:
    # check row 1
    li $t0, 1
    li $t1, 0

check_row_1_loop:
    bge $t1, 6, check_row_2

    add $a0, $t0, $zero
    add $a1, $t1, $zero
    jal get_field_color

    bne $v0, $zero, game_over_detected

    addi $t1, $t1, 1
    j check_row_1_loop

check_row_2:
    # check row 2
    li $t0, 2
    li $t1, 0

check_row_2_loop:
    bge $t1, 6, no_game_over

    add $a0, $t0, $zero
    add $a1, $t1, $zero
    jal get_field_color

    bne $v0, $zero, game_over_detected

    addi $t1, $t1, 1
    j check_row_2_loop

no_game_over:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 0
    jr $ra

game_over_detected:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    li $v0, 1
    jr $ra


generate_new_column:
# generate a new 3 column
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = random color index
    sw $s1, 8($sp)              # $s1 = color 1
    sw $s2, 12($sp)             # $s2 = color 2

    li $v0, 42                  # syscall: random int in range
    li $a0, 0                   # generator ID = 0
    li $a1, 6                   # upper bound = 6
    syscall
    add $s0, $a0, $zero
    jal get_color_value
    add $s1, $v0, $zero

    li $v0, 42                  # syscall: random int in range
    li $a0, 0                   # generator ID = 0
    li $a1, 6                   # upper bound = 6
    syscall
    add $s0, $a0, $zero
    jal get_color_value
    add $s2, $v0, $zero
    # get color 3
    li $v0, 42                  # syscall: random int in range
    li $a0, 0                   # generator ID = 0
    li $a1, 6                   # upper bound = 6
    syscall
    add $s0, $a0, $zero
    jal get_color_value
    # $v0 = color 3

    la $t0, current_column
    sw $s1, 0($t0)
    sw $s2, 4($t0)
    sw $v0, 8($t0)

    li $t0, 2
    sw $t0, column_x
    sw $zero, column_y

    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


get_color_value:
# make color index(0~5) be actual color
# input $s0 = color index
# return $v0 = color
    beq $s0, 0, gv_red
    beq $s0, 1, gv_orange
    beq $s0, 2, gv_yellow
    beq $s0, 3, gv_green
    beq $s0, 4, gv_blue
    # default, purpule
    li $v0, 0x8800ff
    jr $ra

gv_red:
    la $t0, COLOR_RED
    lw $v0, 0($t0)          # Then load value from that address
    jr $ra
gv_orange:
    la $t0, COLOR_ORANGE
    lw $v0, 0($t0)
    jr $ra
gv_yellow:
    la $t0, COLOR_YELLOW
    lw $v0, 0($t0)
    jr $ra
gv_green:
    la $t0, COLOR_GREEN
    lw $v0, 0($t0)
    jr $ra
gv_blue:
    la $t0, COLOR_BLUE
    lw $v0, 0($t0)
    jr $ra


check_initial_collision:
# Check if the newly generated column at starting position collides
# return $v0 = 1 if collision (game over), 0 if OK
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    # Get the starting position (should be x=2, y=0)
    lw $s0, column_x    # Should be 2
    lw $s1, column_y    # Should be 0

    # Check if any of the three positions of the new column are occupied
    # Check top gem position (row 0)
    add $a0, $s1, $zero
    add $a1, $s0, $zero
    jal get_field_color
    bne $v0, $zero, initial_collision_detected

    # Check middle gem position (row 1)
    addi $a0, $s1, 1
    add $a1, $s0, $zero
    jal get_field_color
    bne $v0, $zero, initial_collision_detected

    # Check bottom gem position (row 2)
    addi $a0, $s1, 2
    add $a1, $s0, $zero
    jal get_field_color
    bne $v0, $zero, initial_collision_detected

    # No collision, game continues
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    li $v0, 0
    jr $ra

initial_collision_detected:
    # Collision detected at spawn point = game over
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    li $v0, 1
    jr $ra
