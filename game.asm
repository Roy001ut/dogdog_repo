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
COLOR_WHITE:   .word 0xffffff

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

    # Redraw to show the locked pieces
    jal clear_screen
    jal draw_border
    jal draw_game_field

    # Small delay to see the locked state
    li $v0, 32
    li $a0, 200
    syscall

    # Check for matches and clear them (with cascading)
    jal check_and_clear_matches

    # Redraw after clearing to show what was removed
    jal clear_screen
    jal draw_border
    jal draw_game_field

    # Delay to see the clearing effect
    li $v0, 32
    li $a0, 300
    syscall

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
# NEW: Use get_cell(x, y)
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    # get the location
    lw $s0, column_x        # $s0 = x
    lw $s1, column_y        # $s1 = y

    addi $s2, $s1, 2        # $s2 = y + 2 (bottom gem position)
    # 1. check if it hit the bottom
    li $t0, 11
    beq $s2, $t0, collision_detected

    # 2. check if it hit other column - get_cell(x, y)
    add $a0, $s0, $zero     # a0 = x
    addi $a1, $s2, 1        # a1 = y + 3 (one below bottom gem)
    jal get_cell
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
# NEW: Use get_cell(x, y)
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)     # new_x
    sw $s1, 8($sp)     # current_y

    add $s0, $a0, $zero     # new_x
    lw $s1, column_y        # current_y

    # Check all three gem positions
    # Check top gem - get_cell(x, y)
    add $a0, $s0, $zero     # a0 = new_x
    add $a1, $s1, $zero     # a1 = y
    jal get_cell
    bne $v0, $zero, h_collision_detected

    # Check middle gem
    add $a0, $s0, $zero     # a0 = new_x
    addi $a1, $s1, 1        # a1 = y + 1
    jal get_cell
    bne $v0, $zero, h_collision_detected

    # Check bottom gem
    add $a0, $s0, $zero     # a0 = new_x
    addi $a1, $s1, 2        # a1 = y + 2
    jal get_cell
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


####################################################################
# GAME FIELD CORE FUNCTIONS
# Convention: ALL functions use (x, y) where:
#   x = column (0-5, left to right)
#   y = row (0-11, top to bottom)
# Storage: game_field[y][x] at offset (y * 6 + x) * 4
####################################################################

get_cell:
# Get color at position (x, y)
# Input: $a0 = x (column 0-5), $a1 = y (row 0-11)
# Output: $v0 = color (0 if out of bounds or empty)
    # Bounds check
    bltz $a0, cell_out_of_bounds    # x < 0
    bgt $a0, 5, cell_out_of_bounds   # x > 5
    bltz $a1, cell_out_of_bounds    # y < 0
    bgt $a1, 11, cell_out_of_bounds  # y > 11

    # Calculate offset: (y * 6 + x) * 4
    li $t0, 6
    mul $t1, $a1, $t0      # t1 = y * 6
    add $t1, $t1, $a0      # t1 = y * 6 + x
    sll $t1, $t1, 2        # t1 = (y * 6 + x) * 4

    # Load from game_field
    la $t0, game_field
    add $t0, $t0, $t1
    lw $v0, 0($t0)
    jr $ra

cell_out_of_bounds:
    li $v0, 0
    jr $ra


set_cell:
# Set color at position (x, y)
# Input: $a0 = x (column 0-5), $a1 = y (row 0-11), $a2 = color
    # Bounds check
    bltz $a0, set_cell_done
    bgt $a0, 5, set_cell_done
    bltz $a1, set_cell_done
    bgt $a1, 11, set_cell_done

    # Calculate offset: (y * 6 + x) * 4
    li $t0, 6
    mul $t1, $a1, $t0      # t1 = y * 6
    add $t1, $t1, $a0      # t1 = y * 6 + x
    sll $t1, $t1, 2        # t1 = (y * 6 + x) * 4

    # Store to game_field
    la $t0, game_field
    add $t0, $t0, $t1
    sw $a2, 0($t0)

set_cell_done:
    jr $ra


# Legacy wrapper functions for compatibility
get_field_color:
# OLD INTERFACE: $a0 = y, $a1 = x -> $v0 = color
# Wrapper that converts to new convention
    addi $sp, $sp, -8
    sw $a0, 0($sp)
    sw $a1, 4($sp)

    # Swap arguments: old (y,x) -> new (x,y)
    lw $a0, 4($sp)      # a0 = old x
    lw $a1, 0($sp)      # a1 = old y

    addi $sp, $sp, 8
    j get_cell


set_field_color:
# OLD INTERFACE: $a0 = y, $a1 = x, $a2 = color
# Wrapper that converts to new convention
    addi $sp, $sp, -8
    sw $a0, 0($sp)
    sw $a1, 4($sp)

    # Swap arguments: old (y,x) -> new (x,y)
    move $t0, $a2       # save color
    lw $a0, 4($sp)      # a0 = old x
    lw $a1, 0($sp)      # a1 = old y
    move $a2, $t0       # restore color

    addi $sp, $sp, 8
    j set_cell


lock_column_to_field:
# lock the current column to the field
# NEW: Use set_cell(x, y, color) directly
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    # get column location
    lw $s0, column_x        # $s0 = x
    lw $s1, column_y        # $s1 = y
    la $s2, current_column
    # lock the top gem
    add $a0, $s0, $zero     # a0 = x
    add $a1, $s1, $zero     # a1 = y
    lw $a2, 0($s2)          # a2 = color
    jal set_cell
    # lock the middle gem
    add $a0, $s0, $zero     # a0 = x
    addi $a1, $s1, 1        # a1 = y + 1
    lw $a2, 4($s2)          # a2 = color
    jal set_cell
    # lock the bottom gem
    add $a0, $s0, $zero     # a0 = x
    addi $a1, $s1, 2        # a1 = y + 2
    lw $a2, 8($s2)          # a2 = color
    jal set_cell

    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


draw_game_field:
# Draw all gems in the field.
# NEW: Use get_cell(x, y)
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
    # first, get the color at the location - get_cell(x, y)
    add $a0, $s1, $zero     # a0 = x
    add $a1, $s0, $zero     # a1 = y
    jal get_cell

    beq $v0, $zero, draw_field_skip     # if $v0 is 0, it's empty
    # then draw the grid - draw_game_pixel(y, x, color)
    add $a0, $s0, $zero     # a0 = y (for drawing)
    add $a1, $s1, $zero     # a1 = x (for drawing)
    add $a2, $v0, $zero     # a2 = color
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

    # Flash matched gems in white before clearing
    jal flash_marked_gems

    # Show the flashing for a moment
    jal clear_screen
    jal draw_border
    jal draw_game_field

    li $v0, 32
    li $a0, 400
    syscall

    # Now clear them
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
    jal scan_color_matches

    la $t0, COLOR_ORANGE
    lw $s0, 0($t0)
    jal scan_color_matches

    la $t0, COLOR_YELLOW
    lw $s0, 0($t0)
    jal scan_color_matches

    la $t0, COLOR_GREEN
    lw $s0, 0($t0)
    jal scan_color_matches

    la $t0, COLOR_BLUE
    lw $s0, 0($t0)
    jal scan_color_matches

    la $t0, COLOR_PURPLE
    lw $s0, 0($t0)
    jal scan_color_matches

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


####################################################################
# COMPLETELY REWRITTEN MATCH DETECTION SYSTEM
# Simple, clear, and correct
####################################################################

# COORDINATE SYSTEM:
# - game_field and match_buffer both use [y][x] storage
# - Offset = (y * 6 + x) * 4
# - We use get_cell(x, y) to read, but mark_buffer uses (y, x) indexing

####################################################################
# Helper: Check if cell at (x, y) has target color
# Input: $a0 = x, $a1 = y, $a2 = target_color
# Output: $v0 = 1 if match, 0 if not
####################################################################
check_cell_matches:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a2, 4($sp)      # Save target color

    jal get_cell        # get_cell(x, y)
    lw $a2, 4($sp)      # Restore target color

    # Compare
    beq $v0, $a2, cell_matches
    li $v0, 0           # No match
    j cell_matches_done

cell_matches:
    li $v0, 1           # Match!

cell_matches_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra


####################################################################
# Helper: Mark cell at (x, y) for deletion
# Input: $a0 = x, $a1 = y
####################################################################
mark_cell:
    # Calculate offset = (y * 6 + x) * 4
    li $t0, 6
    mul $t1, $a1, $t0       # y * 6
    add $t1, $t1, $a0       # y * 6 + x
    sll $t1, $t1, 2         # (y * 6 + x) * 4

    # Mark in match_buffer
    la $t0, match_buffer
    add $t0, $t0, $t1
    li $t2, 1
    sw $t2, 0($t0)

    jr $ra


####################################################################
# Check and mark HORIZONTAL matches starting at (x, y)
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
####################################################################
# FIXED: Bidirectional Match Detection
# Each function checks BOTH directions from starting point
####################################################################

####################################################################
# Check and mark HORIZONTAL matches starting at (x, y)
# Checks BOTH left and right from starting position
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_horizontal_match:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # center_x
    sw $s1, 8($sp)      # center_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # left_x (leftmost matching cell)
    sw $s5, 24($sp)     # temp

    move $s0, $a0       # center_x
    move $s1, $a1       # center_y
    move $s2, $a2       # target_color

    # Check center cell first
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, horiz_no_match

    # Count matches - start at center
    li $s3, 1           # count = 1 (center cell)
    move $s4, $s0       # left_x = center_x

    # Count LEFT from center
    addi $s5, $s0, -1   # check_x = center_x - 1
horiz_left_loop:
    bltz $s5, horiz_left_done       # reached left edge?

    move $a0, $s5       # x
    move $a1, $s1       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, horiz_left_done # no match?

    addi $s3, $s3, 1    # count++
    move $s4, $s5       # left_x = check_x (update leftmost)
    addi $s5, $s5, -1   # check_x--
    j horiz_left_loop

horiz_left_done:
    # Count RIGHT from center
    addi $s5, $s0, 1    # check_x = center_x + 1
horiz_right_loop:
    bge $s5, 6, horiz_right_done    # reached right edge?

    move $a0, $s5       # x
    move $a1, $s1       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, horiz_right_done    # no match?

    addi $s3, $s3, 1    # count++
    addi $s5, $s5, 1    # check_x++
    j horiz_right_loop

horiz_right_done:
    # Need at least 3
    blt $s3, 3, horiz_no_match

    # Mark all matched cells (from left_x for count cells)
    move $s5, $s4       # current_x = left_x
    li $t0, 0           # offset = 0

horiz_mark_loop:
    bge $t0, $s3, horiz_no_match    # marked all?

    move $a0, $s5       # x
    move $a1, $s1       # y
    jal mark_cell

    addi $s5, $s5, 1    # current_x++
    addi $t0, $t0, 1    # offset++
    j horiz_mark_loop

horiz_no_match:
    lw $s5, 24($sp)
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 28
    jr $ra


####################################################################
# Check and mark VERTICAL matches starting at (x, y)
# Checks BOTH up and down from starting position
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_vertical_match:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # center_x
    sw $s1, 8($sp)      # center_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # top_y (topmost matching cell)
    sw $s5, 24($sp)     # temp

    move $s0, $a0       # center_x
    move $s1, $a1       # center_y
    move $s2, $a2       # target_color

    # Check center cell first
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, vert_no_match

    # Count matches - start at center
    li $s3, 1           # count = 1 (center cell)
    move $s4, $s1       # top_y = center_y

    # Count UP from center
    addi $s5, $s1, -1   # check_y = center_y - 1
vert_up_loop:
    bltz $s5, vert_up_done          # reached top edge?

    move $a0, $s0       # x
    move $a1, $s5       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, vert_up_done    # no match?

    addi $s3, $s3, 1    # count++
    move $s4, $s5       # top_y = check_y (update topmost)
    addi $s5, $s5, -1   # check_y--
    j vert_up_loop

vert_up_done:
    # Count DOWN from center
    addi $s5, $s1, 1    # check_y = center_y + 1
vert_down_loop:
    bge $s5, 12, vert_down_done     # reached bottom edge?

    move $a0, $s0       # x
    move $a1, $s5       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, vert_down_done  # no match?

    addi $s3, $s3, 1    # count++
    addi $s5, $s5, 1    # check_y++
    j vert_down_loop

vert_down_done:
    # Need at least 3
    blt $s3, 3, vert_no_match

    # Mark all matched cells (from top_y for count cells)
    move $s5, $s4       # current_y = top_y
    li $t0, 0           # offset = 0

vert_mark_loop:
    bge $t0, $s3, vert_no_match     # marked all?

    move $a0, $s0       # x
    move $a1, $s5       # y
    jal mark_cell

    addi $s5, $s5, 1    # current_y++
    addi $t0, $t0, 1    # offset++
    j vert_mark_loop

vert_no_match:
    lw $s5, 24($sp)
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 28
    jr $ra


####################################################################
# Check and mark DIAGONAL matches (both directions)
# Checks BOTH directions along top-left to bottom-right diagonal
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_diagonal_tlbr_match:
    addi $sp, $sp, -32
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # center_x
    sw $s1, 8($sp)      # center_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # topleft_x
    sw $s5, 24($sp)     # topleft_y
    sw $s6, 28($sp)     # temp

    move $s0, $a0       # center_x
    move $s1, $a1       # center_y
    move $s2, $a2       # target_color

    # Check center cell first
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, diag_tlbr_no_match

    # Count matches - start at center
    li $s3, 1           # count = 1 (center cell)
    move $s4, $s0       # topleft_x = center_x
    move $s5, $s1       # topleft_y = center_y

    # Count UP-LEFT from center
    addi $s6, $s0, -1   # check_x = center_x - 1
    addi $t1, $s1, -1   # check_y = center_y - 1
diag_tlbr_upleft_loop:
    bltz $s6, diag_tlbr_upleft_done     # reached left edge?
    bltz $t1, diag_tlbr_upleft_done     # reached top edge?

    move $a0, $s6       # x
    move $a1, $t1       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, diag_tlbr_upleft_done   # no match?

    addi $s3, $s3, 1    # count++
    move $s4, $s6       # topleft_x = check_x
    move $s5, $t1       # topleft_y = check_y
    addi $s6, $s6, -1   # check_x--
    addi $t1, $t1, -1   # check_y--
    j diag_tlbr_upleft_loop

diag_tlbr_upleft_done:
    # Count DOWN-RIGHT from center
    addi $s6, $s0, 1    # check_x = center_x + 1
    addi $t1, $s1, 1    # check_y = center_y + 1
diag_tlbr_downright_loop:
    bge $s6, 6, diag_tlbr_downright_done    # reached right edge?
    bge $t1, 12, diag_tlbr_downright_done   # reached bottom edge?

    move $a0, $s6       # x
    move $a1, $t1       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, diag_tlbr_downright_done    # no match?

    addi $s3, $s3, 1    # count++
    addi $s6, $s6, 1    # check_x++
    addi $t1, $t1, 1    # check_y++
    j diag_tlbr_downright_loop

diag_tlbr_downright_done:
    # Need at least 3
    blt $s3, 3, diag_tlbr_no_match

    # Mark all matched cells (from topleft for count cells)
    move $s6, $s4       # current_x = topleft_x
    move $t1, $s5       # current_y = topleft_y
    li $t0, 0           # offset = 0

diag_tlbr_mark_loop:
    bge $t0, $s3, diag_tlbr_no_match    # marked all?

    move $a0, $s6       # x
    move $a1, $t1       # y
    jal mark_cell

    addi $s6, $s6, 1    # current_x++
    addi $t1, $t1, 1    # current_y++
    addi $t0, $t0, 1    # offset++
    j diag_tlbr_mark_loop

diag_tlbr_no_match:
    lw $s6, 28($sp)
    lw $s5, 24($sp)
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 32
    jr $ra


####################################################################
# Check and mark DIAGONAL matches (both directions)
# Checks BOTH directions along top-right to bottom-left diagonal
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_diagonal_trbl_match:
    addi $sp, $sp, -32
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # center_x
    sw $s1, 8($sp)      # center_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # topright_x
    sw $s5, 24($sp)     # topright_y
    sw $s6, 28($sp)     # temp

    move $s0, $a0       # center_x
    move $s1, $a1       # center_y
    move $s2, $a2       # target_color

    # Check center cell first
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, diag_trbl_no_match

    # Count matches - start at center
    li $s3, 1           # count = 1 (center cell)
    move $s4, $s0       # topright_x = center_x
    move $s5, $s1       # topright_y = center_y

    # Count UP-RIGHT from center
    addi $s6, $s0, 1    # check_x = center_x + 1
    addi $t1, $s1, -1   # check_y = center_y - 1
diag_trbl_upright_loop:
    bge $s6, 6, diag_trbl_upright_done      # reached right edge?
    bltz $t1, diag_trbl_upright_done        # reached top edge?

    move $a0, $s6       # x
    move $a1, $t1       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, diag_trbl_upright_done  # no match?

    addi $s3, $s3, 1    # count++
    move $s4, $s6       # topright_x = check_x
    move $s5, $t1       # topright_y = check_y
    addi $s6, $s6, 1    # check_x++
    addi $t1, $t1, -1   # check_y--
    j diag_trbl_upright_loop

diag_trbl_upright_done:
    # Count DOWN-LEFT from center
    addi $s6, $s0, -1   # check_x = center_x - 1
    addi $t1, $s1, 1    # check_y = center_y + 1
diag_trbl_downleft_loop:
    bltz $s6, diag_trbl_downleft_done       # reached left edge?
    bge $t1, 12, diag_trbl_downleft_done    # reached bottom edge?

    move $a0, $s6       # x
    move $a1, $t1       # y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, diag_trbl_downleft_done # no match?

    addi $s3, $s3, 1    # count++
    addi $s6, $s6, -1   # check_x--
    addi $t1, $t1, 1    # check_y++
    j diag_trbl_downleft_loop

diag_trbl_downleft_done:
    # Need at least 3
    blt $s3, 3, diag_trbl_no_match

    # Mark all matched cells (from topright for count cells)
    move $s6, $s4       # current_x = topright_x
    move $t1, $s5       # current_y = topright_y
    li $t0, 0           # offset = 0

diag_trbl_mark_loop:
    bge $t0, $s3, diag_trbl_no_match    # marked all?

    move $a0, $s6       # x
    move $a1, $t1       # y
    jal mark_cell

    addi $s6, $s6, -1   # current_x--
    addi $t1, $t1, 1    # current_y++
    addi $t0, $t0, 1    # offset++
    j diag_trbl_mark_loop

diag_trbl_no_match:
    lw $s6, 28($sp)
    lw $s5, 24($sp)
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 32
    jr $ra
scan_color_matches:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # target_color
    sw $s1, 8($sp)      # y
    sw $s2, 12($sp)     # x
    sw $s3, 16($sp)     # temp

    li $s1, 0           # y = 0

scan_row_loop:
    bge $s1, 12, scan_done

    li $s2, 0           # x = 0

scan_col_loop:
    bge $s2, 6, scan_next_row

    # Check all 4 directions from this position
    move $a0, $s2       # x
    move $a1, $s1       # y
    move $a2, $s0       # color

    jal check_horizontal_match

    move $a0, $s2       # x
    move $a1, $s1       # y
    move $a2, $s0       # color
    jal check_vertical_match

    move $a0, $s2       # x
    move $a1, $s1       # y
    move $a2, $s0       # color
    jal check_diagonal_tlbr_match

    move $a0, $s2       # x
    move $a1, $s1       # y
    move $a2, $s0       # color
    jal check_diagonal_trbl_match

    addi $s2, $s2, 1    # x++
    j scan_col_loop

scan_next_row:
    addi $s1, $s1, 1    # y++
    j scan_row_loop

scan_done:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
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


flash_marked_gems:
# Flash marked gems in white to show what will be cleared
# NEW: Use set_cell(x, y, color) directly
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)

    la $t0, COLOR_WHITE
    lw $s2, 0($t0)          # $s2 = white color
    li $s0, 0               # $s0 = y (row)

flash_row_loop:
    bge $s0, 12, flash_done
    li $s1, 0               # $s1 = x (col)

flash_col_loop:
    bge $s1, 6, flash_next_row

    # Calculate offset in match_buffer: (y * 6 + x) * 4
    li $t0, 6
    mul $t1, $s0, $t0       # y * 6
    add $t1, $t1, $s1       # y * 6 + x
    sll $t1, $t1, 2         # (y * 6 + x) * 4

    # Check if this position is marked
    la $t0, match_buffer
    add $t0, $t0, $t1
    lw $t2, 0($t0)

    beq $t2, $zero, flash_col_next

    # Flash this gem to white - set_cell(x, y, color)
    add $a0, $s1, $zero     # a0 = x
    add $a1, $s0, $zero     # a1 = y
    add $a2, $s2, $zero     # a2 = white
    jal set_cell

flash_col_next:
    addi $s1, $s1, 1        # x++
    j flash_col_loop

flash_next_row:
    addi $s0, $s0, 1        # y++
    j flash_row_loop

flash_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


clear_marked_gems:
# clear all marked gems, and set them to be 0
# NEW: Use set_cell(x, y, color) directly
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)          # Use $s0 for y (row)
    sw $s1, 8($sp)          # Use $s1 for x (col)
    sw $s2, 12($sp)         # Use $s2 for marked flag

    li $s0, 0               # $s0 = y (row)

clear_marked_row_loop:
    bge $s0, 12, clear_marked_done

    li $s1, 0               # $s1 = x (col)

clear_marked_col_loop:
    bge $s1, 6, clear_marked_next_row

    # Calculate offset in match_buffer: (y * 6 + x) * 4
    li $t0, 6
    mul $t1, $s0, $t0       # y * 6
    add $t1, $t1, $s1       # y * 6 + x
    sll $t1, $t1, 2         # (y * 6 + x) * 4

    # Check if this position is marked
    la $t0, match_buffer
    add $t0, $t0, $t1
    lw $s2, 0($t0)          # Save marked flag in $s2

    beq $s2, $zero, clear_marked_col_next

    # Clear the gem at this position - set_cell(x, y, 0)
    add $a0, $s1, $zero     # a0 = x
    add $a1, $s0, $zero     # a1 = y
    li $a2, 0               # a2 = 0 (empty)
    jal set_cell

clear_marked_col_next:
    addi $s1, $s1, 1        # x++
    j clear_marked_col_loop

clear_marked_next_row:
    addi $s0, $s0, 1        # y++
    j clear_marked_row_loop

clear_marked_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


apply_gravity:
# NEW: Use get_cell(x, y) and set_cell(x, y, color) directly
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # $s0 = x (current column)
    sw $s1, 8($sp)              # $s1 = write_y (where to place next gem)
    sw $s2, 12($sp)             # $s2 = read_y (scanning for gems)
    sw $s3, 16($sp)             # $s3 = color

    li $s0, 0                   # start with column 0 (x=0)

gravity_column_loop:
    bge $s0, 6, gravity_complete    # processed all 6 columns?

    # For this column, compact all gems downward
    li $s1, 11                  # write_y starts at bottom (row 11)
    li $s2, 11                  # read_y starts at bottom too

gravity_scan_loop:
    bltz $s2, gravity_next_column   # scanned all rows in this column?

    # Get color at current read position - get_cell(x, y)
    add $a0, $s0, $zero         # a0 = x (current column)
    add $a1, $s2, $zero         # a1 = y (read_y)
    jal get_cell
    add $s3, $v0, $zero         # save color

    beq $s3, $zero, gravity_scan_next   # empty? skip

    # Found a gem at read_y, need to move it to write_y
    bne $s1, $s2, gravity_move_gem      # same position? no need to move

    # Same position, just decrement write_y
    addi $s1, $s1, -1
    j gravity_scan_next

gravity_move_gem:
    # Move gem from read_y to write_y
    # Set gem at write_y - set_cell(x, y, color)
    add $a0, $s0, $zero         # a0 = x (current column)
    add $a1, $s1, $zero         # a1 = y (write_y)
    add $a2, $s3, $zero         # a2 = color
    jal set_cell

    # Clear gem at read_y - set_cell(x, y, 0)
    add $a0, $s0, $zero         # a0 = x (current column)
    add $a1, $s2, $zero         # a1 = y (read_y)
    li $a2, 0                   # a2 = 0 (empty)
    jal set_cell

    # Move write_y up
    addi $s1, $s1, -1

gravity_scan_next:
    addi $s2, $s2, -1           # move read_y up
    j gravity_scan_loop

gravity_next_column:
    addi $s0, $s0, 1            # next column (x++)
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
# NEW: Use get_cell(x, y)
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    # Get the starting position (should be x=2, y=0)
    lw $s0, column_x    # $s0 = x (should be 2)
    lw $s1, column_y    # $s1 = y (should be 0)

    # Check if any of the three positions of the new column are occupied
    # Check top gem position - get_cell(x, y)
    add $a0, $s0, $zero     # a0 = x
    add $a1, $s1, $zero     # a1 = y
    jal get_cell
    bne $v0, $zero, initial_collision_detected

    # Check middle gem position (y + 1)
    add $a0, $s0, $zero     # a0 = x
    addi $a1, $s1, 1        # a1 = y + 1
    jal get_cell
    bne $v0, $zero, initial_collision_detected

    # Check bottom gem position (y + 2)
    add $a0, $s0, $zero     # a0 = x
    addi $a1, $s1, 2        # a1 = y + 2
    jal get_cell
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
