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
check_horizontal_match:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # start_x
    sw $s1, 8($sp)      # start_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # current_x

    move $s0, $a0       # start_x
    move $s1, $a1       # start_y
    move $s2, $a2       # target_color

    # Check starting cell
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, horiz_no_match

    # Count matches to the right
    li $s3, 1           # count = 1
    addi $s4, $s0, 1    # current_x = start_x + 1

horiz_count_loop:
    bge $s4, 6, horiz_count_done    # reached edge?

    move $a0, $s4       # x = current_x
    move $a1, $s1       # y = start_y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, horiz_count_done    # no match?

    addi $s3, $s3, 1    # count++
    addi $s4, $s4, 1    # current_x++
    j horiz_count_loop

horiz_count_done:
    # Need at least 3
    blt $s3, 3, horiz_no_match

    # Mark all matched cells
    move $s4, $s0       # current_x = start_x
    li $t0, 0           # offset = 0

horiz_mark_loop:
    bge $t0, $s3, horiz_no_match    # marked all?

    move $a0, $s4       # x
    move $a1, $s1       # y
    jal mark_cell

    addi $s4, $s4, 1    # current_x++
    addi $t0, $t0, 1    # offset++
    j horiz_mark_loop

horiz_no_match:
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 24
    jr $ra


####################################################################
# Check and mark VERTICAL matches starting at (x, y)
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_vertical_match:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # start_x
    sw $s1, 8($sp)      # start_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # current_y

    move $s0, $a0       # start_x
    move $s1, $a1       # start_y
    move $s2, $a2       # target_color

    # Check starting cell
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, vert_no_match

    # Count matches downward
    li $s3, 1           # count = 1
    addi $s4, $s1, 1    # current_y = start_y + 1

vert_count_loop:
    bge $s4, 12, vert_count_done    # reached edge?

    move $a0, $s0       # x = start_x
    move $a1, $s4       # y = current_y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, vert_count_done     # no match?

    addi $s3, $s3, 1    # count++
    addi $s4, $s4, 1    # current_y++
    j vert_count_loop

vert_count_done:
    # Need at least 3
    blt $s3, 3, vert_no_match

    # Mark all matched cells
    move $s4, $s1       # current_y = start_y
    li $t0, 0           # offset = 0

vert_mark_loop:
    bge $t0, $s3, vert_no_match     # marked all?

    move $a0, $s0       # x
    move $a1, $s4       # y
    jal mark_cell

    addi $s4, $s4, 1    # current_y++
    addi $t0, $t0, 1    # offset++
    j vert_mark_loop

vert_no_match:
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 24
    jr $ra


####################################################################
# Check and mark DIAGONAL matches (top-left to bottom-right)
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_diagonal_tlbr_match:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # start_x
    sw $s1, 8($sp)      # start_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # current_x
    sw $s5, 24($sp)     # current_y

    move $s0, $a0       # start_x
    move $s1, $a1       # start_y
    move $s2, $a2       # target_color

    # Check starting cell
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, diag_tlbr_no_match

    # Count matches diagonally (down-right)
    li $s3, 1           # count = 1
    addi $s4, $s0, 1    # current_x = start_x + 1
    addi $s5, $s1, 1    # current_y = start_y + 1

diag_tlbr_count_loop:
    bge $s4, 6, diag_tlbr_count_done    # reached right edge?
    bge $s5, 12, diag_tlbr_count_done   # reached bottom edge?

    move $a0, $s4       # x = current_x
    move $a1, $s5       # y = current_y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, diag_tlbr_count_done    # no match?

    addi $s3, $s3, 1    # count++
    addi $s4, $s4, 1    # current_x++
    addi $s5, $s5, 1    # current_y++
    j diag_tlbr_count_loop

diag_tlbr_count_done:
    # Need at least 3
    blt $s3, 3, diag_tlbr_no_match

    # Mark all matched cells
    move $s4, $s0       # current_x = start_x
    move $s5, $s1       # current_y = start_y
    li $t0, 0           # offset = 0

diag_tlbr_mark_loop:
    bge $t0, $s3, diag_tlbr_no_match    # marked all?

    move $a0, $s4       # x
    move $a1, $s5       # y
    jal mark_cell

    addi $s4, $s4, 1    # current_x++
    addi $s5, $s5, 1    # current_y++
    addi $t0, $t0, 1    # offset++
    j diag_tlbr_mark_loop

diag_tlbr_no_match:
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
# Check and mark DIAGONAL matches (top-right to bottom-left)
# Input: $a0 = x, $a1 = y, $a2 = target_color
####################################################################
check_diagonal_trbl_match:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # start_x
    sw $s1, 8($sp)      # start_y
    sw $s2, 12($sp)     # target_color
    sw $s3, 16($sp)     # match_count
    sw $s4, 20($sp)     # current_x
    sw $s5, 24($sp)     # current_y

    move $s0, $a0       # start_x
    move $s1, $a1       # start_y
    move $s2, $a2       # target_color

    # Check starting cell
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal check_cell_matches
    beq $v0, $zero, diag_trbl_no_match

    # Count matches diagonally (down-left)
    li $s3, 1           # count = 1
    addi $s4, $s0, -1   # current_x = start_x - 1
    addi $s5, $s1, 1    # current_y = start_y + 1

diag_trbl_count_loop:
    bltz $s4, diag_trbl_count_done      # reached left edge?
    bge $s5, 12, diag_trbl_count_done   # reached bottom edge?

    move $a0, $s4       # x = current_x
    move $a1, $s5       # y = current_y
    move $a2, $s2       # color
    jal check_cell_matches
    beq $v0, $zero, diag_trbl_count_done    # no match?

    addi $s3, $s3, 1    # count++
    addi $s4, $s4, -1   # current_x--
    addi $s5, $s5, 1    # current_y++
    j diag_trbl_count_loop

diag_trbl_count_done:
    # Need at least 3
    blt $s3, 3, diag_trbl_no_match

    # Mark all matched cells
    move $s4, $s0       # current_x = start_x
    move $s5, $s1       # current_y = start_y
    li $t0, 0           # offset = 0

diag_trbl_mark_loop:
    bge $t0, $s3, diag_trbl_no_match    # marked all?

    move $a0, $s4       # x
    move $a1, $s5       # y
    jal mark_cell

    addi $s4, $s4, -1   # current_x--
    addi $s5, $s5, 1    # current_y++
    addi $t0, $t0, 1    # offset++
    j diag_trbl_mark_loop

diag_trbl_no_match:
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
# Scan all cells for matches of a specific color
# Input: $s0 = target_color (caller-saved register)
####################################################################
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
