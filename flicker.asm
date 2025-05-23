################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Kabir Kumar, 1010244120
# Student 2: Name, Student Number (if applicable) NA
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    128
# - Display height in pixels:   128
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
    
COLOR_BOTTLE:   .word 0x808080
COLOR_RED:      .word 0xFF0000
COLOR_BLUE:     .word 0x0000FF
COLOR_YELLOW:   .word 0xFFFF00
COLOR_BLACK:    .word 0x000000

# Grid dimensions (24 
 X 
 40, 14 
 Y 
 42)
GRID_COLS:      .word 17             # 40 - 24 + 1
GRID_ROWS:      .word 29             # 42 - 14 + 1

##############################################################################
# Mutable Data
##############################################################################
VIRUS_DATA:     .word 0:9            # 3 viruses 
 (X, Y, color)
GRID:           .word 0:493          # 17 columns 
 29 rows

MATCH_BUFFER:   .word 0:493        # Buffer to mark blocks for removal
TEMP_ARRAY:     .word 0:29         # Temporary storage for gravity processing

CONNECTED_BUFFER: .word 0:493  # Tracks blocks connected to matches

# Pill data
PILL_LEFT_COLOR:  .word 0
PILL_RIGHT_COLOR: .word 0
PILL_X:           .word 32       # Initial X position
PILL_Y:           .word 14       # Initial Y position
PILL_ROTATION:    .word 0        # 0 = vertical, 1 = horizontal

##############################################################################
# Code
##############################################################################
	.text
	.globl main

main:
    # Initialize game elements
    jal draw_bottle
    jal generate_viruses  # Populate VIRUS_DATA and GRID
    jal spawn_new_pill
    jal draw_pill
    
    # li $v0, 10              # terminate the program gracefully
    # syscall
    
game_loop:
    jal check_keyboard               # Check for 'q' to quit
    jal draw_grid                    # Draw viruses from GRID
    jal draw_pill                    # Draw static pill
    jal sleep_33ms                   
    j game_loop

# -------------------- Virus Initialization --------------------
generate_viruses:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $s0, VIRUS_DATA               # Virus storage
    li $s1, 3                        # Virus counter
    la $s2, GRID                     # Grid base

virus_loop:
    beqz $s1, end_generate

    # Generate X (25-39)
    li $v0, 42
    li $a0, 0                        # Generator ID
    li $a1, 15                       # 0-14 
 25-39
    syscall
    addi $t0, $a0, 25
    sw $t0, 0($s0)                   # Store X

    # Generate Y (17-41)
    li $v0, 42
    li $a0, 0
    li $a1, 25                       # 0-24 
 17-41
    syscall
    addi $t1, $a0, 17
    sw $t1, 4($s0)                   # Store Y

    # Generate color (0-2)
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    sw $a0, 8($s0)                   # Store color index

    # Update GRID
    lw $t0, 0($s0)                   # X
    lw $t1, 4($s0)                   # Y
    lw $t2, 8($s0)                   # Color index

    # Calculate grid index: (Y-14)*17 + (X-24)
    addi $t3, $t0, -24               # Column index
    addi $t4, $t1, -14               # Row index
    mul $t5, $t4, 17                 # Row offset
    add $t5, $t5, $t3                # Grid index
    sll $t5, $t5, 2                  # Byte offset
    add $t5, $s2, $t5                # Grid address

    # Load color from index
    beq $t2, 0, load_red
    beq $t2, 1, load_blue
    lw $t6, COLOR_YELLOW
    j store_in_grid
    
load_red:
    lw $t6, COLOR_RED
    j store_in_grid
    
load_blue:
    lw $t6, COLOR_BLUE

store_in_grid:
    sw $t6, 0($t5)                   # Store color in GRID

    # Next virus
    addi $s0, $s0, 12                # Next virus entry
    addi $s1, $s1, -1
    j virus_loop

end_generate:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ------------ Grid Drawing --------------
draw_grid:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $s0, GRID                     # Grid base
    li $s1, 0                        # Row counter

row_loop:
    lw $t0, GRID_ROWS
    beq $s1, $t0, end_draw
    li $s2, 0                        # Column counter

col_loop:
    lw $t0, GRID_COLS
    beq $s2, $t0, next_row

    # Calculate grid index
    mul $t1, $s1, 17                 # Row offset
    add $t1, $t1, $s2                # Grid index
    sll $t1, $t1, 2                  # Byte offset
    add $t1, $s0, $t1                # Cell address
    lw $t2, 0($t1)                   # Color

    beqz $t2, skip_cell              # Skip empty cells

    # Convert to display coordinates
    addi $a0, $s2, 24                # X = 24 + column
    addi $a1, $s1, 14                # Y = 14 + row
    move $a2, $t2                    # Color
    jal draw_unit

skip_cell:
    addi $s2, $s2, 1                 # Next column
    j col_loop

next_row:
    addi $s1, $s1, 1                 # Next row
    j row_loop

end_draw:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# -------------------- Helper Functions --------------------
clear_screen:
    lw $t0, ADDR_DSPL
    lw $t1, COLOR_BLACK
    li $t2, 4096                   # 128x128 display (4096 words = 16384 bytes)
    
clear_loop:
    sw $t1, 0($t0)                # Store WORD (4 bytes) of black color
    addi $t0, $t0, 4              # Move to next word
    addi $t2, $t2, -1             # Decrement word counter
    bnez $t2, clear_loop
    jr $ra                        # No stack manipulation needed


sleep_33ms:
    li $v0, 32
    li $a0, 60                       # ~30 FPS
    syscall
    jr $ra
    
    
# Clearing the pill:
clear_pill:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    lw   $a2, COLOR_BLACK      # Use black to clear
    lw   $t2, PILL_X
    lw   $t3, PILL_Y
    lw   $t4, PILL_ROTATION
    
    # Determine pill parts based on rotation
    beq $t4, 0, clear_vertical
    beq $t4, 1, clear_horizontal
    beq $t4, 2, clear_vertical_flipped
    beq $t4, 3, clear_horizontal_flipped

clear_vertical:
    move $a0, $t2
    move $a1, $t3
    jal draw_unit
    move $a0, $t2
    addi $a1, $t3, 1
    jal draw_unit
    j end_clear_pill

clear_horizontal:
    move $a0, $t2
    move $a1, $t3
    jal draw_unit
    addi $a0, $t2, 1
    jal draw_unit
    j end_clear_pill

clear_vertical_flipped:
    move $a0, $t2
    move $a1, $t3
    jal draw_unit
    move $a0, $t2
    addi $a1, $t3, -1
    jal draw_unit
    j end_clear_pill

clear_horizontal_flipped:
    addi $a0, $t2, -1
    jal draw_unit
    move $a0, $t2
    jal draw_unit

end_clear_pill:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# ----- Drawing the bottle -----
draw_bottle:
    # Allocate stack space for $ra
    addi $sp, $sp, -4 
    sw   $ra, 0($sp)
    
    # Draw left wall
    li $a0, 24                      # Left wall X = 24
    li $a1, 16                       # Start Y = 16
    li $a2, 42                      # End Y = 42
    jal draw_vertical_line
    
    # Draw right wall
    li $a0, 40                      # Left wall X = 40
    li $a1, 16                       # Start Y = 16
    li $a2, 42                      # End Y = 42
    jal draw_vertical_line
    
    # Bottom of the bottle
    li $a0, 24                      # Start X = 20
    li $a1, 42                      # Y = 56
    li $a2, 40                      # End X = 43
    jal draw_horizontal_line
    
    # top left wall
    li $a0, 24                      # Start X = 20
    li $a1, 16                      # Y = 16
    li $a2, 29                      # End X = 28
    jal draw_horizontal_line
    
    # top right wall
    li $a0, 35                      # Start X = 35
    li $a1, 16                      # Y = 16
    li $a2, 40                      # End X = 43
    jal draw_horizontal_line
    
    # Draw left neck
    li $a0, 29                      # Left wall X = 28
    li $a1, 14                      # Start Y = 12
    li $a2, 16                      # End Y = 16
    jal draw_vertical_line
    
    # Draw right neck
    li $a0, 35                      # Left wall X = 35
    li $a1, 14                      # Start Y = 12
    li $a2, 16                      # End Y = 16
    jal draw_vertical_line
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4      
    jr $ra                 

# Draws a vertical line from (x, y_start) to (x, y_end)
# $a0 = X, $a1 = Y_start, $a2 = Y_end
draw_vertical_line:
    lw $t0, ADDR_DSPL               # Base address
    lw $t1, COLOR_BOTTLE            # Color
    move $t2, $a0                   # X-coordinate
    move $t3, $a1                   # Current Y

vertical_loop:
    bgt $t3, $a2, vertical_end      # Loop until Y > Y_end
    sll $t4, $t3, 6                 # Y * 64 (units per row)
    add $t4, $t4, $t2               # Y*64 + X
    sll $t4, $t4, 2                 # Convert to byte offset
    add $t4, $t0, $t4               # Full address
    sw $t1, 0($t4)                  # Draw pixel
    addi $t3, $t3, 1                # Y++
    j vertical_loop

vertical_end:
    jr $ra

# Draws a horizontal line from (x_start, y) to (x_end, y)
# $a0 = X_start, $a1 = Y, $a2 = X_end
draw_horizontal_line:
    lw $t0, ADDR_DSPL               # Base address
    lw $t1, COLOR_BOTTLE            # Color
    move $t2, $a0                   # Current X
    move $t3, $a1                   # Y-coordinate

horizontal_loop:
    bgt $t2, $a2, horizontal_end    # Loop until X > X_end
    sll $t4, $t3, 6                 # Y * 64
    add $t4, $t4, $t2               # Y*64 + X
    sll $t4, $t4, 2                 # Convert to byte offset
    add $t4, $t0, $t4               # Full address
    sw $t1, 0($t4)                  # Draw pixel
    addi $t2, $t2, 1                # X++
    j horizontal_loop

horizontal_end:
    jr $ra
    
    
# ----- Drawing pill functions -----
# Draws the initial pill at the top of the neck
spawn_new_pill:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Generate left color (use $t0)
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    beq $a0, 0, left_red
    beq $a0, 1, left_blue
    lw $t8, COLOR_YELLOW
    j store_left
    
left_red:
    lw $t8, COLOR_RED
    j store_left
    
left_blue:
    lw $t8, COLOR_BLUE
    j store_left
    
store_left:
    sw $t8, PILL_LEFT_COLOR
    
    # Generate right color (use $t1)
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    beq $a0, 0, right_red
    beq $a0, 1, right_blue
    lw $t9, COLOR_YELLOW
    j store_right
    
right_red:
    lw $t9, COLOR_RED
    j store_right
    
right_blue:
    lw $t9, COLOR_BLUE
    j store_right
    
store_right:
    sw $t9, PILL_RIGHT_COLOR
    
    # Reset position and rotation
    li $t0, 32
    sw $t0, PILL_X
    li $t0, 14
    sw $t0, PILL_Y
    li $t0, 0
    sw $t0, PILL_ROTATION
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_pill:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load pill data
    lw $t8, PILL_LEFT_COLOR
    lw $t9, PILL_RIGHT_COLOR
    lw $t2, PILL_X
    lw $t3, PILL_Y
    lw $t4, PILL_ROTATION
    
    # Check rotation state
    beq $t4, 0, draw_vertical         # Vertical (top-bottom)
    beq $t4, 1, draw_horizontal       # Horizontal (left-right)
    beq $t4, 2, draw_vertical_flipped # Vertical flipped (bottom-top)
    beq $t4, 3, draw_horizontal_flipped # Horizontal flipped (right-left)

draw_vertical:
    # Vertical: top (left), bottom (right)
    move $a0, $t2
    move $a1, $t3
    move $a2, $t8
    jal draw_unit
    move $a0, $t2
    addi $a1, $t3, 1
    move $a2, $t9
    jal draw_unit
    j end_draw_pill

draw_horizontal:
    # Horizontal: left (left), right (right)
    move $a0, $t2
    move $a1, $t3
    move $a2, $t8
    jal draw_unit
    addi $a0, $t2, 1
    move $a1, $t3
    move $a2, $t9
    jal draw_unit
    j end_draw_pill

draw_vertical_flipped:
    # Vertical flipped: bottom (left), top (right)
    move $a0, $t2
    move $a1, $t3
    move $a2, $t8
    jal draw_unit
    move $a0, $t2
    addi $a1, $t3, -1
    move $a2, $t9
    jal draw_unit
    j end_draw_pill

draw_horizontal_flipped:
    # Horizontal flipped: right (left), left (right)
    addi $a0, $t2, -1
    move $a1, $t3
    move $a2, $t9
    jal draw_unit
    move $a0, $t2
    move $a1, $t3
    move $a2, $t8
    jal draw_unit

end_draw_pill:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Helper function draws a single unit at (X,Y) with specified color
# $a0 = X, $a1 = Y, $a2 = color
draw_unit:
    lw $t0, ADDR_DSPL               # Base address
    sll $t1, $a1, 6                 # Y * 64 (units per row)
    add $t1, $t1, $a0               # Y*64 + X
    sll $t1, $t1, 2                 # Convert to byte offset
    add $t1, $t0, $t1               # Full address
    sw $a2, 0($t1)                  # Store color
    jr $ra

# -------------------- Keyboard Handling --------------------
check_keyboard:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    bne $t1, 1, no_key
    lw $t2, 4($t0)
    beq $t2, 0x71, quit_game     # 'q' to quit
    beq $t2, 0x61, move_left     # 'a' left
    beq $t2, 0x64, move_right    # 'd' right
    beq $t2, 0x73, move_down     # 's' down
    beq $t2, 0x77, rotate        # 'w' rotate
    j no_key
    
    
# ------ Movement handling ------
move_left:
    addi $sp, $sp, -20        # Allocate stack space
    sw   $ra, 0($sp)         # Save return address
    
    jal clear_pill # clearing the pill

    lw   $t2, PILL_X
    addi $t3, $t2, -1         # Proposed new X
    lw   $t4, PILL_Y
    lw   $t5, PILL_ROTATION
    
    # Save values to stack (preserve across jal)
    sw   $t2, 4($sp)         # Original X
    sw   $t3, 8($sp)         # New X
    sw   $t4, 12($sp)        # Y
    sw   $t5, 16($sp)        # Rotation

    # Check collision at new X
    move $a0, $t3            # Proposed X
    move $a1, $t4            # Current Y
    move $a2, $t5            # Rotation
    jal  check_collision

    # Restore values from stack
    lw   $t2, 4($sp)         # Original X
    lw   $t3, 8($sp)         # New X
    lw   $t4, 12($sp)        # Y
    lw   $t5, 16($sp)        # Rotation
    
    # no collision, move to the right
    beqz $v0, move_left_valid
    j move_left_exit

move_left_valid:
    # No collision: Update PILL_Y to new_Y
    sw   $t3, PILL_X

move_left_exit:
    lw   $ra, 0($sp)         # Restore return address
    addi $sp, $sp, 20        # Free stack space
    j    no_key              # Return to main loop

move_right:
    addi $sp, $sp, -20        # Allocate stack space
    sw   $ra, 0($sp)         # Save return address
    
    jal clear_pill # clearing the pill

    lw   $t2, PILL_X
    addi $t3, $t2, 1         # Proposed new X
    lw   $t4, PILL_Y
    lw   $t5, PILL_ROTATION
    
    # Save values to stack (preserve across jal)
    sw   $t2, 4($sp)         # Original X
    sw   $t3, 8($sp)         # New X
    sw   $t4, 12($sp)        # Y
    sw   $t5, 16($sp)        # Rotation

    # Check collision at new X
    move $a0, $t3            # Proposed X
    move $a1, $t4            # Current Y
    move $a2, $t5            # Rotation
    jal  check_collision

    # Restore values from stack
    lw   $t2, 4($sp)         # Original X
    lw   $t3, 8($sp)         # New X
    lw   $t4, 12($sp)        # Y
    lw   $t5, 16($sp)        # Rotation
    
    # no collision, move to the right
    beqz $v0, move_right_valid
    j move_right_exit


move_right_valid:
    # No collision: Update PILL_Y to new_Y
    sw   $t3, PILL_X

move_right_exit:
    lw   $ra, 0($sp)         # Restore return address
    addi $sp, $sp, 20        # Free stack space
    j    no_key              # Return to main loop



move_down:
    addi $sp, $sp, -20       # Allocate space for $ra, original_Y, new_Y, X, rotation
    sw   $ra, 0($sp)         # Save return address
    
    jal clear_pill # clearing the pill

    # Load current pill data
    lw   $t0, PILL_Y         # Original Y
    addi $t1, $t0, 1         # New Y = Y + 1
    lw   $t2, PILL_X         # Current X
    lw   $t3, PILL_ROTATION  # Current rotation

    # Save values to stack (preserve across jal)
    sw   $t0, 4($sp)         # Original Y
    sw   $t1, 8($sp)         # New Y
    sw   $t2, 12($sp)        # X
    sw   $t3, 16($sp)        # Rotation

    # Check collision at new_Y
    move $a0, $t2            # X
    move $a1, $t1            # New Y
    move $a2, $t3            # Rotation
    jal  check_collision

    # Restore values from stack
    lw   $t0, 4($sp)         # Original Y
    lw   $t1, 8($sp)         # New Y
    lw   $t2, 12($sp)        # X
    lw   $t3, 16($sp)        # Rotation

    # Handle collision result
    beqz $v0, move_down_valid

    # Collision: Lock pill at original position
    move $a0, $t2            # Original X
    move $a1, $t0            # Original Y
    move $a2, $t3            # Original rotation
    jal  lock_pill
    j    move_down_exit

move_down_valid:
    # No collision: Update PILL_Y to new_Y
    sw   $t1, PILL_Y

move_down_exit:
    lw   $ra, 0($sp)         # Restore return address
    addi $sp, $sp, 20        # Free stack space
    j    no_key              # Return to main loop

# $a0 = X, $a1 = Y, $a2 = rotation
rotate:
    addi $sp, $sp, -20        # Allocate stack space
    sw   $ra, 0($sp)         # Save return address
    
    jal clear_pill # clearing the pill

    lw   $t3, PILL_ROTATION
    addi $t3, $t3, -1        # Rotate counter-clockwise
    andi $t3, $t3, 3         # Wrap to 0-3
    lw   $t4, PILL_X
    lw   $t5, PILL_Y

    # Save values to stack (preserve across jal)
    sw   $t5, 4($sp)         # Original Y
    sw   $t5, 8($sp)         # New Y
    sw   $t4, 12($sp)        # X
    sw   $t3, 16($sp)        # Rotation

    # Check collision with new rotation
    move $a0, $t4            # X
    move $a1, $t5            # Y
    move $a2, $t3            # Proposed rotation
    jal  check_collision
    
    # Restore values from stack
    lw   $t5, 4($sp)         # Original Y
    lw   $t5, 8($sp)         # New Y
    lw   $t4, 12($sp)        # X
    lw   $t3, 16($sp)        # Rotation

    # Handle no collision result
    beqz $v0, rotate_valid
    j rotate_exit

rotate_valid:
    sw   $t3, PILL_ROTATION  # Update rotation if valid
    
rotate_exit:
    lw   $ra, 0($sp)         # Restore return address
    addi $sp, $sp, 20        # Free stack space
    j    no_key              # Return to main loop

lock_pill:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    jal  save_pill_to_grid
    jal  clear_screen       # Full clear when locking
    jal  draw_bottle        # Redraw static elements
    jal  process_matches
    jal  spawn_new_pill
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

no_key:
    jr $ra                  # Return to game loop
    
# -------------------- Collision Detection --------------------
# $a0 = X, $a1 = Y, $a2 = rotation
# Returns $v0 = 1 (collision) or 0 (valid)

check_collision:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    # Determine pill parts based on rotation
    beq $a2, 0, check_vertical
    beq $a2, 1, check_horizontal
    beq $a2, 2, check_vertical_flipped
    beq $a2, 3, check_horizontal_flipped

check_vertical:
    move $s0, $a0            # Part 1: (X, Y)
    move $s1, $a1
    jal check_single_collision
    bnez $v0, collision

    addi $a1, $a1, 1         # Part 2: (X, Y+1)
    jal check_single_collision
    j done_check

check_horizontal:
    move $s0, $a0            # Part 1: (X, Y)
    move $s1, $a1
    jal check_single_collision
    bnez $v0, collision

    addi $a0, $a0, 1         # Part 2: (X+1, Y)
    jal check_single_collision
    j done_check

check_vertical_flipped:
    move $s0, $a0            # Part 1: (X, Y)
    move $s1, $a1
    jal check_single_collision
    bnez $v0, collision

    addi $a1, $a1, -1        # Part 2: (X, Y-1)
    jal check_single_collision
    j done_check

check_horizontal_flipped:
    addi $a0, $a0, -1        # Part 1: (X-1, Y)
    jal check_single_collision
    bnez $v0, collision

    addi $a0, $a0, 1         # Part 2: (X, Y)
    jal check_single_collision

done_check:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

collision:
    li $v0, 1
    j done_check

# $a0 = X, $a1 = Y
# Returns $v0 = 1 (collision) or 0 (valid)
check_single_collision:
    # Check outer walls (24 
 X 
 40)
    blt $a0, 25, invalid
    bgt $a0, 39, invalid

    # Check Y bounds (14 
 Y 
 41)
    blt $a1, 14, invalid
    bgt $a1, 41, invalid

    # Check neck walls (Y=14-16: X must be 29-35)
    li $t0, 14
    li $t1, 16
    blt $a1, $t0, check_grid
    bgt $a1, $t1, check_grid
    blt $a0, 30, invalid
    bgt $a0, 34, invalid

check_grid:
    # Check GRID for existing blocks
    la $t0, GRID
    addi $t1, $a0, -24       # Column index
    addi $t2, $a1, -14       # Row index
    bltz $t2, invalid        # Y < 14 (invalid)
    mul $t3, $t2, 17         # Row offset
    add $t3, $t3, $t1        # Grid index
    sll $t3, $t3, 2          # Byte offset
    add $t3, $t0, $t3        # Cell address
    lw $t4, 0($t3)           # Color value
    bnez $t4, invalid        # Cell occupied

    li $v0, 0
    jr $ra

invalid:
    li $v0, 1
    jr $ra
    

# -------------------- Save Pill to Grid --------------------
save_pill_to_grid:
    addi $sp, $sp, -4          # Allocate stack space
    sw   $ra, 0($sp)           # Save original $ra (return to lock_pill)

    # Save left color at (X, Y)
    lw $a0, PILL_X
    lw $a1, PILL_Y
    lw $a2, PILL_LEFT_COLOR
    jal save_unit

    # Save right color based on rotation
    lw $t0, PILL_ROTATION
    beq $t0, 0, save_vertical
    beq $t0, 1, save_horizontal
    beq $t0, 2, save_vertical_flipped
    beq $t0, 3, save_horizontal_flipped

save_vertical:
    addi $a1, $a1, 1          # Y+1
    j save_right

save_horizontal:
    addi $a0, $a0, 1          # X+1
    j save_right

save_vertical_flipped:
    addi $a1, $a1, -1         # Y-1
    j save_right

save_horizontal_flipped:
    addi $a0, $a0, -1         # X-1

save_right:
    lw $a2, PILL_RIGHT_COLOR
    jal save_unit              # Save right part
    lw $ra, 0($sp)            # Restore original $ra
    addi $sp, $sp, 4          # Free stack space
    jr $ra                    # Return to lock_pill

save_unit:
    # $a0 = X, $a1 = Y, $a2 = color
    la $t0, GRID
    addi $t1, $a0, -24        # Column index
    addi $t2, $a1, -14        # Row index
    mul $t3, $t2, 17
    add $t3, $t3, $t1
    sll $t3, $t3, 2
    add $t3, $t0, $t3
    sw $a2, 0($t3)
    jr $ra                    # Return to caller (save_right)


# ---- Perform matching blocks game logic ----

check_matches:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $s0, GRID
    la   $s1, MATCH_BUFFER
    li   $s4, 0                   # Flag for any matches found

    # Clear MATCH_BUFFER
    li   $t0, 493
    la   $t1, MATCH_BUFFER
    
clear_buffer:
    sw   $zero, 0($t1)
    addi $t1, $t1, 4
    addi $t0, $t0, -1
    bnez $t0, clear_buffer

    li   $s2, 0                   # Row counter

row_loop_check:
    li   $s3, 0                   # Column counter
    
col_loop_check:
    # Calculate grid index (row * 17 + col)
    mul  $t0, $s2, 17
    add  $t0, $t0, $s3
    sll  $t0, $t0, 2
    add  $t1, $s0, $t0            # GRID address
    lw   $t2, 0($t1)              # Current color
    beqz $t2, next_col_check       # Skip if empty

    # Check horizontal group
    move $a0, $s3
    move $a1, $s2
    jal  check_horizontal_group

    # Check vertical group
    move $a0, $s3
    move $a1, $s2
    jal  check_vertical_group

next_col_check:
    addi $s3, $s3, 1
    li   $t0, 17
    blt  $s3, $t0, col_loop_check

    addi $s2, $s2, 1
    li   $t0, 29
    blt  $s2, $t0, row_loop_check

    # Check if any matches were found
    la   $s1, MATCH_BUFFER
    li   $t0, 493
    
check_any_marked:
    lw   $t1, 0($s1)
    bnez $t1, matches_found
    addi $s1, $s1, 4
    addi $t0, $t0, -1
    bnez $t0, check_any_marked
    li   $v0, 0
    j    end_check_matches
matches_found:
    li   $v0, 1
end_check_matches:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

check_horizontal_group:
    # Check if there are 4 columns to the right
    li   $t0, 13
    bgt  $a0, $t0, end_horizontal

    # Calculate addresses for the next 3 columns
    mul  $t1, $a1, 17
    add  $t2, $t1, $a0
    sll  $t2, $t2, 2
    add  $t3, $s0, $t2       # Current cell
    lw   $t4, 0($t3)         # Current color

    addi $t5, $a0, 1         # Column +1
    add  $t6, $t1, $t5
    sll  $t6, $t6, 2
    add  $t6, $s0, $t6
    lw   $t7, 0($t6)
    bne  $t4, $t7, end_horizontal

    addi $t5, $a0, 2         # Column +2
    add  $t6, $t1, $t5
    sll  $t6, $t6, 2
    add  $t6, $s0, $t6
    lw   $t7, 0($t6)
    bne  $t4, $t7, end_horizontal

    addi $t5, $a0, 3         # Column +3
    add  $t6, $t1, $t5
    sll  $t6, $t6, 2
    add  $t6, $s0, $t6
    lw   $t7, 0($t6)
    bne  $t4, $t7, end_horizontal

    # Mark all four cells in MATCH_BUFFER
    li   $t0, 0
    
mark_horizontal:
    add  $t1, $a0, $t0
    mul  $t2, $a1, 17
    add  $t2, $t2, $t1
    sll  $t2, $t2, 2
    add  $t3, $s1, $t2       # MATCH_BUFFER address
    li   $t4, 1
    sw   $t4, 0($t3)
    addi $t0, $t0, 1
    li   $t4, 4
    blt  $t0, $t4, mark_horizontal

end_horizontal:
    jr   $ra

check_vertical_group:
    # Check if there are 4 rows below
    li   $t0, 25
    bgt  $a1, $t0, end_vertical

    # Calculate addresses for the next 3 rows
    mul  $t1, $a1, 17
    add  $t1, $t1, $a0
    sll  $t1, $t1, 2
    add  $t2, $s0, $t1       # Current cell
    lw   $t3, 0($t2)         # Current color

    addi $t4, $a1, 1         # Row +1
    mul  $t5, $t4, 17
    add  $t5, $t5, $a0
    sll  $t5, $t5, 2
    add  $t5, $s0, $t5
    lw   $t6, 0($t5)
    bne  $t3, $t6, end_vertical

    addi $t4, $a1, 2         # Row +2
    mul  $t5, $t4, 17
    add  $t5, $t5, $a0
    sll  $t5, $t5, 2
    add  $t5, $s0, $t5
    lw   $t6, 0($t5)
    bne  $t3, $t6, end_vertical

    addi $t4, $a1, 3         # Row +3
    mul  $t5, $t4, 17
    add  $t5, $t5, $a0
    sll  $t5, $t5, 2
    add  $t5, $s0, $t5
    lw   $t6, 0($t5)
    bne  $t3, $t6, end_vertical

    # Mark all four cells in MATCH_BUFFER
    li   $t0, 0
    
mark_vertical:
    add  $t1, $a1, $t0
    mul  $t2, $t1, 17
    add  $t2, $t2, $a0
    sll  $t2, $t2, 2
    add  $t3, $s1, $t2       # MATCH_BUFFER address
    li   $t4, 1
    sw   $t4, 0($t3)
    addi $t0, $t0, 1
    li   $t4, 4
    blt  $t0, $t4, mark_vertical

end_vertical:
    jr   $ra
    
    
# ---- Remove all marked blocks ----
remove_marked_blocks:
    la   $s0, GRID
    la   $s1, MATCH_BUFFER
    la   $s5, CONNECTED_BUFFER
    li   $t0, 0                   # Index counter

remove_loop:
    beq  $t0, 493, mark_connected
    lw   $t1, 0($s1)              # Check if marked
    beqz $t1, skip_remove
    # Clear block and mark connected
    sll  $t2, $t0, 2
    add  $t3, $s0, $t2            # GRID address
    sw   $zero, 0($t3)            # Clear block
    
    # Calculate row and column
    li   $t4, 17
    div  $t0, $t4                 # row = $t0/17, col = $t0%17
    mflo $t5                      # row
    mfhi $t6                      # column
    
    # Mark adjacent blocks in CONNECTED_BUFFER
    # Check left
    bgtz $t6, mark_left
    
left_done:
    # Check right
    blt  $t6, 16, mark_right
right_done:
    # Check above
    bgtz $t5, mark_above
above_done:
    # Check below
    blt  $t5, 28, mark_below
below_done:
    
skip_remove:
    addi $s1, $s1, 4
    addi $t0, $t0, 1
    j    remove_loop

mark_left:
    addi $t7, $t6, -1            # column-1
    mul  $t8, $t5, 17
    add  $t8, $t8, $t7            # index
    sll  $t9, $t8, 2
    add  $t9, $s5, $t9            # CONNECTED_BUFFER address
    li   $t4, 1
    sw   $t4, 0($t9)
    j left_done

mark_right:
    addi $t7, $t6, 1             # column+1
    mul  $t8, $t5, 17
    add  $t8, $t8, $t7
    sll  $t9, $t8, 2
    add  $t9, $s5, $t9
    li   $t4, 1
    sw   $t4, 0($t9)
    j right_done

mark_above:
    addi $t7, $t5, -1            # row-1
    mul  $t8, $t7, 17
    add  $t8, $t8, $t6
    sll  $t9, $t8, 2
    add  $t9, $s5, $t9
    li   $t4, 1
    sw   $t4, 0($t9)
    j above_done

mark_below:
    addi $t7, $t5, 1             # row+1
    mul  $t8, $t7, 17
    add  $t8, $t8, $t6
    sll  $t9, $t8, 2
    add  $t9, $s5, $t9
    li   $t4, 1
    sw   $t4, 0($t9)
    j below_done

mark_connected:
    jr   $ra
    
    
# ---- Falling blocks gravity ----
apply_gravity:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    la   $s0, CONNECTED_BUFFER   # Load connected buffer
    la   $s1, GRID               # Grid base
    li   $s2, 0                  # Index counter
    
    
gravity_loop:
    beq  $s2, 493, end_gravity   # Process all cells
    lw   $t0, 0($s0)             # Check if connected
    beqz $t0, next_cell          # Skip if not marked

    # Calculate row and column from index
    li   $t1, 17
    div  $s2, $t1                # row = index / 17, column = index % 17
    mflo $t2                     # row (0-28)
    mfhi $t3                     # column (0-16)

    # Get current cell address
    mul  $t4, $t2, 17
    add  $t4, $t4, $t3
    sll  $t4, $t4, 2
    add  $t5, $s1, $t4
    lw   $t6, 0($t5)             # Current color
    beqz $t6, next_cell          # Skip if empty

    # Find lowest empty row (stop at row 27 = Y=41)
    move $t7, $t2                # Start from current row
    
find_lowest:
    addi $t7, $t7, 1             # Next row
    bgt  $t7, 27, move_block     # Stop at row 27 (Y=41)
    
    # Check cell below
    mul  $t8, $t7, 17
    add  $t8, $t8, $t3
    sll  $t8, $t8, 2
    add  $t9, $s1, $t8
    lw   $t8, 0($t9)
    bnez $t8, move_block         # Blocked, stop here
    j    find_lowest

move_block:
    addi $t7, $t7, -1            # Last empty row
    beq  $t7, $t2, next_cell     # No movement needed

    # Move the block down
    mul  $t8, $t7, 17
    add  $t8, $t8, $t3
    sll  $t8, $t8, 2
    add  $t9, $s1, $t8
    sw   $t6, 0($t9)             # Store color
    sw   $zero, 0($t5)           # Clear original

next_cell:
    addi $s0, $s0, 4             # Next buffer entry
    addi $s2, $s2, 1             # Increment index
    j    gravity_loop

end_gravity:
    # Clear CONNECTED_BUFFER
    la   $s3, CONNECTED_BUFFER
    li   $s4, 493


gravity_col_loop:
    li   $s1, 28                  # Start from the bottom row (row 28)
    
column_row_loop:
    blt  $s1, 0, next_column      # If row < 0, move to next column

    # Calculate current cell index
    mul  $t0, $s1, 17
    add  $t0, $t0, $s0            # column $s0, row $s1
    sll  $t1, $t0, 2
    la   $t2, GRID
    add  $t2, $t2, $t1            # Address of current cell
    lw   $t3, 0($t2)              # Value of current cell

    beqz $t3, check_above          # If current cell is empty, check above

    # Current cell has a block, check below for empty space
    move $t4, $s1                  # Start checking from current row down

find_lowest_empty:
    addi $t4, $t4, 1              # Next row down
    bgt  $t4, 28, no_space        # If beyond bottom, no space

    # Calculate cell below
    mul  $t5, $t4, 17
    add  $t5, $t5, $s0
    sll  $t5, $t5, 2
    la   $t6, GRID
    add  $t6, $t6, $t5
    lw   $t7, 0($t6)              # Value of cell below

    bnez $t7, no_space            # If cell below is occupied, can't move

    j find_lowest_empty           # Continue searching

no_space:
    addi $t4, $t4, -1             # Back to last empty row
    beq  $t4, $s1, check_above    # If same as current, no movement needed

    # Move the block to the lowest empty row
    mul  $t5, $t4, 17
    add  $t5, $t5, $s0
    sll  $t5, $t5, 2
    la   $t6, GRID
    add  $t6, $t6, $t5            # Address of destination
    sw   $t3, 0($t6)              # Move block here
    sw   $zero, 0($t2)            # Clear original position

check_above:
    addi $s1, $s1, -1             # Move up a row
    j column_row_loop

next_column:
    addi $s0, $s0, 1
    li   $t0, 17
    blt  $s0, $t0, gravity_col_loop

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# Collect non-zero blocks from bottom to top
collect_loop:
    # Calculate index (row, column)
    mul  $t0, $s4, 17
    add  $t0, $t0, $s0            # column $s0
    sll  $t1, $t0, 2              # byte offset
    add  $t2, $s6, $t1            # CONNECTED_BUFFER address
    lw   $t3, 0($t2)
    beqz $t3, skip_collect        # Skip if not connected
    
    add  $t4, $s1, $t1            # GRID address
    lw   $t5, 0($t4)              # Block color
    sw   $t5, 0($s2)              # Store in TEMP_ARRAY
    addi $s2, $s2, 4
    addi $s3, $s3, 1
    sw   $zero, 0($t4)            # Clear original position


skip_collect:
    addi $s4, $s4, -1
    bgez $s4, collect_loop

    # Fill column from TEMP_ARRAY
    la   $s2, TEMP_ARRAY
    li   $s4, 28
    li   $s5, 0

fill_loop:
    mul  $t0, $s4, 17
    add  $t0, $t0, $s0
    sll  $t1, $t0, 2
    add  $t2, $s1, $t1            # GRID address
    
    blt  $s5, $s3, fill_block
    sw   $zero, 0($t2)
    j    next_fill
    
fill_block:
    lw   $t3, 0($s2)
    sw   $t3, 0($t2)
    addi $s2, $s2, 4
    addi $s5, $s5, 1

next_fill:
    addi $s4, $s4, -1
    bgez $s4, fill_loop

    # Clear CONNECTED_BUFFER for this column
    li   $s4, 28
    
clear_connected:
    mul  $t0, $s4, 17
    add  $t0, $t0, $s0
    sll  $t1, $t0, 2
    add  $t2, $s6, $t1
    sw   $zero, 0($t2)
    addi $s4, $s4, -1
    bgez $s4, clear_connected

    addi $s0, $s0, 1
    li   $t0, 17
    blt  $s0, $t0, gravity_col_loop

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
process_matches:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
process_loop:
    jal  check_matches
    beqz $v0, no_more_matches
    jal  remove_marked_blocks
    jal  apply_gravity
    j    process_loop
    
no_more_matches:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


# ---- Exit the game ----

quit_game:
    li $v0, 10                       # Exit program
    syscall
