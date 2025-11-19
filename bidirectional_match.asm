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
