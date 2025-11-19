####################################################################
# LINE-BASED MATCH DETECTION
# Scan all lines (rows, columns, diagonals) once
# Mark all matches in match_buffer, then delete all at once
####################################################################

####################################################################
# Scan all ROWS for matches of target color
# Input: $a0 = target_color
####################################################################
scan_all_rows:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # target_color
    sw $s1, 8($sp)      # row (y)
    sw $s2, 12($sp)     # start_x of current run
    sw $s3, 16($sp)     # run_length
    sw $s4, 20($sp)     # current_x

    move $s0, $a0       # target_color
    li $s1, 0           # row = 0

scan_rows_loop:
    bge $s1, 12, scan_rows_done

    # Scan this row from left to right
    li $s2, -1          # start_x = -1 (no run yet)
    li $s3, 0           # run_length = 0
    li $s4, 0           # current_x = 0

scan_row_cells:
    bge $s4, 6, check_row_end   # reached end of row?

    # Check cell at (current_x, row)
    move $a0, $s4       # x
    move $a1, $s1       # y
    move $a2, $s0       # color
    jal check_cell_matches

    beq $v0, $zero, row_run_break   # no match, break run

    # Cell matches - extend run
    beq $s3, $zero, row_start_run   # starting new run?
    addi $s3, $s3, 1    # extend existing run
    j row_next_cell

row_start_run:
    move $s2, $s4       # start_x = current_x
    li $s3, 1           # run_length = 1
    j row_next_cell

row_run_break:
    # Run broken - mark if length >= 3
    blt $s3, 3, row_no_mark
    move $a0, $s2       # start_x
    move $a1, $s1       # row
    move $a2, $s3       # length
    jal mark_horizontal_run
row_no_mark:
    li $s2, -1          # reset start_x
    li $s3, 0           # reset run_length

row_next_cell:
    addi $s4, $s4, 1    # current_x++
    j scan_row_cells

check_row_end:
    # Check if there's a run at end of row
    blt $s3, 3, row_next_row
    move $a0, $s2       # start_x
    move $a1, $s1       # row
    move $a2, $s3       # length
    jal mark_horizontal_run

row_next_row:
    addi $s1, $s1, 1    # row++
    j scan_rows_loop

scan_rows_done:
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 24
    jr $ra


####################################################################
# Mark a horizontal run
# Input: $a0 = start_x, $a1 = y, $a2 = length
####################################################################
mark_horizontal_run:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # current_x
    sw $s1, 8($sp)      # y
    sw $s2, 12($sp)     # remaining

    move $s0, $a0       # current_x = start_x
    move $s1, $a1       # y
    move $s2, $a2       # remaining = length

mark_h_loop:
    beq $s2, $zero, mark_h_done

    move $a0, $s0       # x
    move $a1, $s1       # y
    jal mark_cell

    addi $s0, $s0, 1    # current_x++
    addi $s2, $s2, -1   # remaining--
    j mark_h_loop

mark_h_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


####################################################################
# Scan all COLUMNS for matches of target color
# Input: $a0 = target_color
####################################################################
scan_all_columns:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # target_color
    sw $s1, 8($sp)      # col (x)
    sw $s2, 12($sp)     # start_y of current run
    sw $s3, 16($sp)     # run_length
    sw $s4, 20($sp)     # current_y

    move $s0, $a0       # target_color
    li $s1, 0           # col = 0

scan_cols_loop:
    bge $s1, 6, scan_cols_done

    # Scan this column from top to bottom
    li $s2, -1          # start_y = -1 (no run yet)
    li $s3, 0           # run_length = 0
    li $s4, 0           # current_y = 0

scan_col_cells:
    bge $s4, 12, check_col_end  # reached end of column?

    # Check cell at (col, current_y)
    move $a0, $s1       # x
    move $a1, $s4       # y
    move $a2, $s0       # color
    jal check_cell_matches

    beq $v0, $zero, col_run_break   # no match, break run

    # Cell matches - extend run
    beq $s3, $zero, col_start_run   # starting new run?
    addi $s3, $s3, 1    # extend existing run
    j col_next_cell

col_start_run:
    move $s2, $s4       # start_y = current_y
    li $s3, 1           # run_length = 1
    j col_next_cell

col_run_break:
    # Run broken - mark if length >= 3
    blt $s3, 3, col_no_mark
    move $a0, $s1       # col
    move $a1, $s2       # start_y
    move $a2, $s3       # length
    jal mark_vertical_run
col_no_mark:
    li $s2, -1          # reset start_y
    li $s3, 0           # reset run_length

col_next_cell:
    addi $s4, $s4, 1    # current_y++
    j scan_col_cells

check_col_end:
    # Check if there's a run at end of column
    blt $s3, 3, col_next_col
    move $a0, $s1       # col
    move $a1, $s2       # start_y
    move $a2, $s3       # length
    jal mark_vertical_run

col_next_col:
    addi $s1, $s1, 1    # col++
    j scan_cols_loop

scan_cols_done:
    lw $s4, 20($sp)
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 24
    jr $ra


####################################################################
# Mark a vertical run
# Input: $a0 = x, $a1 = start_y, $a2 = length
####################################################################
mark_vertical_run:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # x
    sw $s1, 8($sp)      # current_y
    sw $s2, 12($sp)     # remaining

    move $s0, $a0       # x
    move $s1, $a1       # current_y = start_y
    move $s2, $a2       # remaining = length

mark_v_loop:
    beq $s2, $zero, mark_v_done

    move $a0, $s0       # x
    move $a1, $s1       # y
    jal mark_cell

    addi $s1, $s1, 1    # current_y++
    addi $s2, $s2, -1   # remaining--
    j mark_v_loop

mark_v_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra


####################################################################
# Mark a diagonal run (top-left to bottom-right)
# Input: $a0 = start_x, $a1 = start_y, $a2 = length
####################################################################
mark_diagonal_tlbr_run:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # current_x
    sw $s1, 8($sp)      # current_y
    sw $s2, 12($sp)     # remaining
    sw $s3, 16($sp)     # temp

    move $s0, $a0       # current_x = start_x
    move $s1, $a1       # current_y = start_y
    move $s2, $a2       # remaining = length

mark_tlbr_loop:
    beq $s2, $zero, mark_tlbr_done

    move $a0, $s0       # x
    move $a1, $s1       # y
    jal mark_cell

    addi $s0, $s0, 1    # current_x++
    addi $s1, $s1, 1    # current_y++
    addi $s2, $s2, -1   # remaining--
    j mark_tlbr_loop

mark_tlbr_done:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


####################################################################
# Mark a diagonal run (top-right to bottom-left)
# Input: $a0 = start_x, $a1 = start_y, $a2 = length
####################################################################
mark_diagonal_trbl_run:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # current_x
    sw $s1, 8($sp)      # current_y
    sw $s2, 12($sp)     # remaining
    sw $s3, 16($sp)     # temp

    move $s0, $a0       # current_x = start_x
    move $s1, $a1       # current_y = start_y
    move $s2, $a2       # remaining = length

mark_trbl_loop:
    beq $s2, $zero, mark_trbl_done

    move $a0, $s0       # x
    move $a1, $s1       # y
    jal mark_cell

    addi $s0, $s0, -1   # current_x--
    addi $s1, $s1, 1    # current_y++
    addi $s2, $s2, -1   # remaining--
    j mark_trbl_loop

mark_trbl_done:
    lw $s3, 16($sp)
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 20
    jr $ra


####################################################################
# Scan all DIAGONALS (top-left to bottom-right) for matches
# Input: $a0 = target_color
####################################################################
scan_all_diagonals_tlbr:
    addi $sp, $sp, -32
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # target_color
    sw $s1, 8($sp)      # start_x
    sw $s2, 12($sp)     # start_y
    sw $s3, 16($sp)     # current_x
    sw $s4, 20($sp)     # current_y
    sw $s5, 24($sp)     # run_start_x
    sw $s6, 28($sp)     # run_start_y

    move $s0, $a0       # target_color

    # First set: Diagonals starting from top row (y=0, x=0 to 5)
    li $s2, 0           # start_y = 0
    li $s1, 0           # start_x = 0

tlbr_top_row_loop:
    bge $s1, 6, tlbr_left_col_start

    # Scan diagonal starting at (start_x, 0)
    move $s3, $s1       # current_x = start_x
    move $s4, $s2       # current_y = start_y
    li $t0, 0           # run_length = 0
    li $s5, -1          # run_start_x = -1
    li $s6, -1          # run_start_y = -1

tlbr_top_scan:
    bge $s3, 6, tlbr_top_end        # reached right edge?
    bge $s4, 12, tlbr_top_end       # reached bottom edge?

    # Check cell at (current_x, current_y)
    move $a0, $s3       # x
    move $a1, $s4       # y
    move $a2, $s0       # color
    jal check_cell_matches

    beq $v0, $zero, tlbr_top_break  # no match, break run

    # Cell matches - extend run
    beq $t0, $zero, tlbr_top_start_run
    addi $t0, $t0, 1    # run_length++
    j tlbr_top_continue

tlbr_top_start_run:
    move $s5, $s3       # run_start_x = current_x
    move $s6, $s4       # run_start_y = current_y
    li $t0, 1           # run_length = 1
    j tlbr_top_continue

tlbr_top_break:
    # Run broken - mark if length >= 3
    blt $t0, 3, tlbr_top_no_mark
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_tlbr_run
tlbr_top_no_mark:
    li $t0, 0           # reset run_length
    li $s5, -1          # reset run_start_x
    li $s6, -1          # reset run_start_y

tlbr_top_continue:
    addi $s3, $s3, 1    # current_x++
    addi $s4, $s4, 1    # current_y++
    j tlbr_top_scan

tlbr_top_end:
    # Check if there's a run at end of diagonal
    blt $t0, 3, tlbr_top_next
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_tlbr_run

tlbr_top_next:
    addi $s1, $s1, 1    # start_x++
    j tlbr_top_row_loop

tlbr_left_col_start:
    # Second set: Diagonals starting from left column (x=0, y=1 to 11)
    li $s1, 0           # start_x = 0
    li $s2, 1           # start_y = 1 (skip 0,0 already covered)

tlbr_left_col_loop:
    bge $s2, 12, tlbr_done

    # Scan diagonal starting at (0, start_y)
    move $s3, $s1       # current_x = start_x
    move $s4, $s2       # current_y = start_y
    li $t0, 0           # run_length = 0
    li $s5, -1          # run_start_x = -1
    li $s6, -1          # run_start_y = -1

tlbr_left_scan:
    bge $s3, 6, tlbr_left_end       # reached right edge?
    bge $s4, 12, tlbr_left_end      # reached bottom edge?

    # Check cell at (current_x, current_y)
    move $a0, $s3       # x
    move $a1, $s4       # y
    move $a2, $s0       # color
    jal check_cell_matches

    beq $v0, $zero, tlbr_left_break # no match, break run

    # Cell matches - extend run
    beq $t0, $zero, tlbr_left_start_run
    addi $t0, $t0, 1    # run_length++
    j tlbr_left_continue

tlbr_left_start_run:
    move $s5, $s3       # run_start_x = current_x
    move $s6, $s4       # run_start_y = current_y
    li $t0, 1           # run_length = 1
    j tlbr_left_continue

tlbr_left_break:
    # Run broken - mark if length >= 3
    blt $t0, 3, tlbr_left_no_mark
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_tlbr_run
tlbr_left_no_mark:
    li $t0, 0           # reset run_length
    li $s5, -1          # reset run_start_x
    li $s6, -1          # reset run_start_y

tlbr_left_continue:
    addi $s3, $s3, 1    # current_x++
    addi $s4, $s4, 1    # current_y++
    j tlbr_left_scan

tlbr_left_end:
    # Check if there's a run at end of diagonal
    blt $t0, 3, tlbr_left_next
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_tlbr_run

tlbr_left_next:
    addi $s2, $s2, 1    # start_y++
    j tlbr_left_col_loop

tlbr_done:
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
# Scan all DIAGONALS (top-right to bottom-left) for matches
# Input: $a0 = target_color
####################################################################
scan_all_diagonals_trbl:
    addi $sp, $sp, -32
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # target_color
    sw $s1, 8($sp)      # start_x
    sw $s2, 12($sp)     # start_y
    sw $s3, 16($sp)     # current_x
    sw $s4, 20($sp)     # current_y
    sw $s5, 24($sp)     # run_start_x
    sw $s6, 28($sp)     # run_start_y

    move $s0, $a0       # target_color

    # First set: Diagonals starting from top row (y=0, x=5 to 0)
    li $s2, 0           # start_y = 0
    li $s1, 5           # start_x = 5

trbl_top_row_loop:
    bltz $s1, trbl_right_col_start

    # Scan diagonal starting at (start_x, 0)
    move $s3, $s1       # current_x = start_x
    move $s4, $s2       # current_y = start_y
    li $t0, 0           # run_length = 0
    li $s5, -1          # run_start_x = -1
    li $s6, -1          # run_start_y = -1

trbl_top_scan:
    bltz $s3, trbl_top_end          # reached left edge?
    bge $s4, 12, trbl_top_end       # reached bottom edge?

    # Check cell at (current_x, current_y)
    move $a0, $s3       # x
    move $a1, $s4       # y
    move $a2, $s0       # color
    jal check_cell_matches

    beq $v0, $zero, trbl_top_break  # no match, break run

    # Cell matches - extend run
    beq $t0, $zero, trbl_top_start_run
    addi $t0, $t0, 1    # run_length++
    j trbl_top_continue

trbl_top_start_run:
    move $s5, $s3       # run_start_x = current_x
    move $s6, $s4       # run_start_y = current_y
    li $t0, 1           # run_length = 1
    j trbl_top_continue

trbl_top_break:
    # Run broken - mark if length >= 3
    blt $t0, 3, trbl_top_no_mark
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_trbl_run
trbl_top_no_mark:
    li $t0, 0           # reset run_length
    li $s5, -1          # reset run_start_x
    li $s6, -1          # reset run_start_y

trbl_top_continue:
    addi $s3, $s3, -1   # current_x--
    addi $s4, $s4, 1    # current_y++
    j trbl_top_scan

trbl_top_end:
    # Check if there's a run at end of diagonal
    blt $t0, 3, trbl_top_next
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_trbl_run

trbl_top_next:
    addi $s1, $s1, -1   # start_x--
    j trbl_top_row_loop

trbl_right_col_start:
    # Second set: Diagonals starting from right column (x=5, y=1 to 11)
    li $s1, 5           # start_x = 5
    li $s2, 1           # start_y = 1 (skip 5,0 already covered)

trbl_right_col_loop:
    bge $s2, 12, trbl_done

    # Scan diagonal starting at (5, start_y)
    move $s3, $s1       # current_x = start_x
    move $s4, $s2       # current_y = start_y
    li $t0, 0           # run_length = 0
    li $s5, -1          # run_start_x = -1
    li $s6, -1          # run_start_y = -1

trbl_right_scan:
    bltz $s3, trbl_right_end        # reached left edge?
    bge $s4, 12, trbl_right_end     # reached bottom edge?

    # Check cell at (current_x, current_y)
    move $a0, $s3       # x
    move $a1, $s4       # y
    move $a2, $s0       # color
    jal check_cell_matches

    beq $v0, $zero, trbl_right_break    # no match, break run

    # Cell matches - extend run
    beq $t0, $zero, trbl_right_start_run
    addi $t0, $t0, 1    # run_length++
    j trbl_right_continue

trbl_right_start_run:
    move $s5, $s3       # run_start_x = current_x
    move $s6, $s4       # run_start_y = current_y
    li $t0, 1           # run_length = 1
    j trbl_right_continue

trbl_right_break:
    # Run broken - mark if length >= 3
    blt $t0, 3, trbl_right_no_mark
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_trbl_run
trbl_right_no_mark:
    li $t0, 0           # reset run_length
    li $s5, -1          # reset run_start_x
    li $s6, -1          # reset run_start_y

trbl_right_continue:
    addi $s3, $s3, -1   # current_x--
    addi $s4, $s4, 1    # current_y++
    j trbl_right_scan

trbl_right_end:
    # Check if there's a run at end of diagonal
    blt $t0, 3, trbl_right_next
    move $a0, $s5       # start_x
    move $a1, $s6       # start_y
    move $a2, $t0       # length
    jal mark_diagonal_trbl_run

trbl_right_next:
    addi $s2, $s2, 1    # start_y++
    j trbl_right_col_loop

trbl_done:
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
# NEW: Scan for matches of one color
# Input: $s0 = target_color
####################################################################
scan_color_matches_new:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

    # Scan all rows
    move $a0, $s0
    jal scan_all_rows

    # Scan all columns
    move $a0, $s0
    jal scan_all_columns

    # Scan diagonals
    move $a0, $s0
    jal scan_all_diagonals_tlbr
    move $a0, $s0
    jal scan_all_diagonals_trbl

    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra
