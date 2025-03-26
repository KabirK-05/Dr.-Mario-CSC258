################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       TODO
# - Unit height in pixels:      TODO
# - Display width in pixels:    TODO
# - Display height in pixels:   TODO
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

RED: .word 0xff0000
GREEN: .word 0x00ff00
BLUE: .word 0x0000ff

BOTTLE_OUTLINE_COLOR: .word 0xD3D3D3

INP_KBRD: .word 0xffff0004

##############################################################################
# Mutable Data
##############################################################################
COLUMN: .space 160
##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
DRAW_BOTTLE:
  # Draw the neck of the bottle
  addi $a0, $zero, 104
  addi $a1, $zero, 1792
  addi $a2, $zero, 2
  addi $a3, $zero, 256
  jal DRAW_LINE

  addi $a0, $zero, 120
  addi $a1, $zero, 1792
  addi $a2, $zero, 2
  addi $a3, $zero, 256
  jal DRAW_LINE
  ##############################
  # Draw the top of the bottle

  addi $a0, $zero, 68
  addi $a1, $zero, 2304
  addi $a2, $zero, 10
  addi $a3, $zero, 4
  jal DRAW_LINE

  addi $a0, $zero, 120
  addi $a1, $zero, 2304
  addi $a2, $zero, 10
  addi $a3, $zero, 4
  jal DRAW_LINE
  ##############################
  # Draw the sides of the bottle

  addi $a0, $zero, 160
  addi $a1, $zero, 2304
  addi $a2, $zero, 40
  addi $a3, $zero, 256
  jal DRAW_LINE

  addi $a0, $zero, 64
  addi $a1, $zero, 2304
  addi $a2, $zero, 40
  addi $a3, $zero, 256
  jal DRAW_LINE
  ##############################
  #Draw bottom of the bottle

  addi $a0, $zero, 64
  addi $a1, $zero, 12544
  addi $a2, $zero, 25
  addi $a3, $zero, 4
  jal DRAW_LINE

  jal DRAW_CAPSULE
  
  j game_loop





# Function draws line on bitmap.
# - $a0 corresponds to the x offset
# - $a1 corresponds to the y offset
# - $a2 corresponds to the length of the line
# - $a3 checks if the line is vertical or horizontal.
DRAW_LINE:
  # Get position of the starting point of the line
  lw $t8, ADDR_DSPL                                # $t0 contains start address
  lw $t9, BOTTLE_OUTLINE_COLOR                     # Get bottle color
  add $t8, $t8, $a0                              # Add x offset to position
  add $t8, $t8, $a1                                # Add y offset to position
  
  add $t0, $zero, $zero                            # Initiliaze counter index i=0
DL_loop:
  bge $t0, $a2, DL_end                             # if i < length, then paint, else branch
  sw $t9, 0($t8)                                   # Paint bit color border
  add $t8, $t8, $a3                                # Add 256 if vertical and 4 if horizontal
  addi $t0, $t0, 1                                 # i++
  j DL_loop
DL_end:
  jr $ra

# Function draws a random colored capsule (half-colored).
DRAW_CAPSULE:
  addi $sp, $sp, -4   # Make space on the stack
  sw $ra, 0($sp)      # Save return address
  
  lw $t8, ADDR_DSPL # Load addres into $t8
  # Position at neck
  add $t8, $t8, 112   # position x-axis
  add $t8, $t8, 1792  # position y-axis
  # Generate random number to randomize color selection
  # Random color 1
  jal GENREATE_RANDOM_COLOR
  sw $v0, 0($t8)   # paint first half of the capsule with random color
  add $s2, $zero, $v0   # Get color of upper half

  add $t8, $t8, 256   # Go a level under (y-axis)
  # Random Color 2
  jal GENREATE_RANDOM_COLOR
  sw $v0, 0($t8)   # paint second half of the capsule with random color
  add $s3, $zero, $v0   # Get color of lower half

  add $s1, $zero, $t8       # Save the position of the bottom half of the capsule
  addi $s0, $s1, -256       # Save the position of the upper half of the capsule

  lw $ra, 0($sp)      # Restore return address
  addi $sp, $sp, 4    # Free stack space
  jr $ra              # Return to caller
  
  

# Generate random color through randomized number.
GENREATE_RANDOM_COLOR:
  li $v0, 42
  li $a0, 0
  li $a1, 3 # choose a number between 0 and 2 (included)
  syscall  # Return value is now in $a0
  addi $t0, $zero, 0
  addi $t1, $zero, 1
  addi $t2, $zero, 2
  beq $a0, $t0, gen_red # If 0, return red
  beq $a0, $t1, gen_green # If 1, return green
  beq $a0, $t2, gen_blue # If 2, return blue
gen_red:
  lw $v0, RED
  j GRC_end
gen_green:
  lw $v0, GREEN
  j GRC_end
gen_blue:
  lw $v0, BLUE
GRC_end:
  jr $ra

check_orientation:
    # Check if $s0 on top of $s1
    addi $t1, $s0, 256
    beq $t1, $s1, condo1
    # check if $s0 to the right of $s1
    addi $t1, $s0, -4
    beq $t1, $s1, condo2
    # Check if $s0 below $s1
    addi $t1, $s0, -256
    beq $t1, $s1, condo3
    # Check if $s0 to the left of $s1
    add $t1, $s0, 4
    beq $t1, $s1, condo4
  condo1:
    addi $v0, $zero, 0
    jr $ra
  condo2:
    addi $v0, $zero, 1
    jr $ra 
  condo3:
    addi $v0, $zero, 2
    jr $ra 
  condo4:
    addi $v0, $zero, 3
    jr $ra

# Makes any existing pill fall down if the pill that supported it dissapears.
# $a2: first block of the vertical column
# $a3: -4 for left, 4 for right, 256 for down and -256 for up
apply_gravity:
  la $t9, COLUMN   # Get column array
  addi $a2, $a2, 4
  lw $t7, 0($a2)    # Get color
  loop_grav:
    beq $t7, 0, move_down
    
  move_down:
    
  

# - $a2: starting position
# - $a3: -4 for left, 4 for right, 256 for down and -256 for up
check_line:
  add $t3, $zero, $a2    # copy address of $a2
  lw $t4, 0($a2)  # Get color of $a2
  add $t5, $zero, $zero   # i = 0
  loop:
    bge $t5, 4, remove
    lw $t6, 0($t3)   # Get color of i-th square
    bne $t4, $t6, cl_fail
    add $t3, $t3, $a3  # move to next square
    addi $t5, $t5, 1
    j loop
  
  remove:
    addi $t8, $zero, 0
    add $t3, $zero, $a2    # copy address of $a2
    add $t5, $zero, $zero   # i = 0
  remove_loop:
    bge $t5, 4, cl_pass
    sw $t8, 0($t3)   # paint i-th square black
    add $t3, $t3, $a3  # move to next square
    addi $t5, $t5, 1
    j remove_loop
  cl_pass:
    addi $v1, $zero, 1
    jr $ra
  cl_fail:
    addi $v1, $zero, 0
    jr $ra
  

# Function that checks if there is a connect 4, and removes the blocks. The blocks that were above the removed ones will fall down.
# The arguments are:
# - $a0: position of $s0 inserted block
# - $a1: position of $s1 inserted blovck
check_connect4:
  addi $sp, $sp, -4   # Make space on the stack
  sw $ra, 0($sp)      # Save return address
  
  add $a2, $zero, $a0

  addi $a3, $zero, -4
  jal check_line
  addi $a3, $zero, 4
  jal check_line
  addi $a3, $zero, -256
  jal check_line
  addi $a3, $zero, 256
  jal check_line

  add $a2, $zero, $a1
  
  addi $a3, $zero, -4
  jal check_line
  addi $a3, $zero, 4
  jal check_line
  addi $a3, $zero, -256
  jal check_line
  addi $a3, $zero, 256
  jal check_line

  lw $ra, 0($sp)      # Restore return address
  addi $sp, $sp, 4    # Free stack space
  jr $ra              # Return to callers
  
default:
  addi $s5, $zero, 150
  j check_down

game_loop:
    # 1a. Check if key has beqen pressed
    lw $t8 , ADDR_KBRD  # $t0 = base address for keyboard 
    lw $t0 , 0($t8)   # Load first word from keyboard
    addi $t9, $zero, 1
    bne $t0, $t9, default   # If first word 1, key is pressed, then proceed, else branch back to game_loop

    
    lw $t1, 4($t8)   # Load second word from keyboard
    beq $t1, 0x71, respond_to_q   # Check if q is pressed. If so, branch to respond_to_q
    beq $t1, 0x73, check_down_spec
    beq $t1, 0x64, check_right
    beq $t1, 0x61, check_left
    beq $t1, 0x77, check_rotate
    j game_loop
    
    # 2a. Check for collisions
  check_down_spec:
    addi $s5, $zero, 50
  check_down:
    jal check_orientation
    beq $v0, 0, condd1
    beq $v0, 1, condd2
    beq $v0, 2, condd3
    beq $v0, 3, condd2
    condd1:
      addi $t7, $s1, 256
      lw $t8, 0($t7)
      beq $t8, 0, respond_to_s
      j draw_cap
        
    condd2:
      addi $t6, $s0, 256
      addi $t7, $s1, 256
      lw $t8, 0($t6)
      lw $t9, 0($t7)
      bne $t8, 0, draw_cap
      bne $t9, 0, draw_cap
      j respond_to_s
    condd3:
      addi $t7, $s0, 256
      lw $t8, 0($t7)
      beq $t8, 0, respond_to_s 
      j draw_cap

  check_right:
    addi $s5, $zero, 150
    jal check_orientation
    beq $v0, 0, condr1
    beq $v0, 1, condr2
    beq $v0, 2, condr1
    beq $v0, 3, condr3
    condr1:
      addi $t6, $s0, 4
      addi $t7, $s1, 4
      lw $t8, 0($t6)
      lw $t9, 0($t7)
      bne $t8, 0, game_loop
      bne $t9, 0, game_loop
      j respond_to_d
    condr2:
      addi $t7, $s0, 4
      lw $t8, 0($t7)
      beq $t8, 0, respond_to_d
      j game_loop
    condr3:
      addi $t7, $s1, 4
      lw $t8, 0($t7)
      beq $t8, 0, respond_to_d
      j game_loop
    check_left:
      addi $s5, $zero, 150
      jal check_orientation
      beq $v0, 0, condl1
      beq $v0, 1, condl2
      beq $v0, 2, condl1
      beq $v0, 3, condl3
      condl1:
        addi $t6, $s0, -4
        addi $t7, $s1, -4
        lw $t8, 0($t6)
        lw $t9, 0($t7)
        bne $t8, 0, game_loop
        bne $t9, 0, game_loop
        j respond_to_a
      condl2:
        addi $t7, $s1, -4
        lw $t8, 0($t7)
        beq $t8, 0, respond_to_a
        j game_loop
      condl3:
        addi $t7, $s0, -4
        lw $t8, 0($t7)
        beq $t8, 0, respond_to_a
        j game_loop
    check_rotate:
      addi $s5, $zero, 150
      jal check_orientation
      beq $v0, 0, condrt1
      beq $v0, 1, condrt2
      beq $v0, 2, condrt3
      beq $v0, 3, condrt4
      condrt1:
        addi $t6, $s1, 4
        addi $t7, $s0, 4
        lw $t8, 0($t6)
        lw $t9, 0($t7)
        bne $t8, 0, game_loop
        bne $t9, 0,  game_loop
        j respond_to_w
      condrt2:
        addi $t6, $s1, -256
        addi $t7, $t6, 4
        lw $t8, 0($t6)
        lw $t9, 0($t7)
        bne $t8, 0, game_loop
        bne $t9, 0,  game_loop
        j respond_to_w
      condrt3:
        addi $t7, $s0, 4
        lw $t8, 0($t7)
        beq $t8, 0, respond_to_w
        j game_loop
      condrt4:
        addi $t6, $s0, -256
        addi $t7, $t6, 4
        lw $t8, 0($t6)
        lw $t9, 0($t7)
        bne $t8, 0, game_loop
        bne $t9, 0,  game_loop
        j respond_to_w

draw_cap:
  add $a0, $zero, $s0
  add $a1, $zero, $s1
  jal check_connect4
  jal DRAW_CAPSULE
  j game_loop

	# 2b. Update locations (capsules)
# Following will contain code to control the capsule
respond_to_q:
  li $v0, 10 # terminate the program gracefully 
  syscall

respond_to_s:
    # Make each half go down by one unit   
    addi $t0, $zero, 0
    sw $t0, 0($s0)
    sw $t0, 0($s1)
    addi $s0, $s0, 256
    addi $s1, $s1, 256
    j draw_screen

respond_to_d:
    addi $t0, $zero, 0
    sw $t0, 0($s0)
    sw $t0, 0($s1)
    addi $s0, $s0, 4
    addi $s1, $s1, 4
    j draw_screen

respond_to_a:
    addi $t0, $zero, 0
    sw $t0, 0($s0)
    sw $t0, 0($s1)
    addi $s0, $s0, -4
    addi $s1, $s1, -4
    j draw_screen

respond_to_w:
    addi $t0, $zero, 0
    sw $t0, 0($s0)
    sw $t0, 0($s1)

    jal check_orientation
    beq $v0, 0, cond1
    beq $v0, 1, cond2
    beq $v0, 2, cond3
    beq $v0, 3, cond4
    cond1:
      addi $s0, $s1, 4
      j draw_screen
    cond2:
      addi $s1, $s1, -256
      addi $s0, $s0, -4
      j draw_screen
    cond3:
      addi $s1, $s0, 4
      j draw_screen
    cond4:
      addi $s0, $s0, -256
      addi $s1, $s1, -4
      j draw_screen
   
	# 3. Draw the screens
draw_screen:
    sw $s2, 0($s0)
    sw $s3, 0($s1)
	# 4. Sleep
sleep:
    li $v0, 32
    add $a0, $zero, $s5
    syscall

    j game_loop