# projet.s

.data
StrSolvedSuffix:
	.asciiz ".resolu"
StrTableWidth:
	.asciiz "Table width: "
StrStoredAt:
	.asciiz "Stored at: "
StrMenu:
	.asciiz "Mode:\n  1. Generate\n  2. Solve\nChoice? "
StrMenuInvalid:
	.asciiz "Invalid choice.\n"
StrAskSize:
	.asciiz "Labyrinth size? "
StrSizeInvalid:
	.asciiz "Labyrinth size must be at least 2\n"
StrAskFilename:
	.asciiz "File name? "
StrOpenError:
	.asciiz "Can't open file\n"
StrSpace:
	.asciiz " "
NewLine:
	.asciiz "\n"

.text
.globl __start

# Entry point
# It initializes the RNG, ask for the mode, and jumps to the correct mode
__start:
	# Start by seeding MARS' RNG...
	# ...by getting OS' time...
	li	$v0	30
	syscall
	li	$a0	0

	# ...and using it as seed
	move	$a1	$v0
	li	$v0	40
	# li	$a0	0 # redundant
	syscall

	# Let's ask the user for the mode...
	jal	MainMenu
	# ...and jump to the correct one
	beq	$v0	1	GenerateMode
	beq	$v0	2	SolveMode

# Generate mode
# It:
#  - Asks for the table size
#  - Opens the save file descriptor
#  - Create the table in memory
#  - Generate the entrance and exit
#  - ???
#  - Print the table to the console
#  - Saves the labyrinth in the previously opened file descriptor
GenerateMode:
	# Ask the table size
	jal	AskSize
	move	$s1	$v0	# Save the table size in $s1

	# Ask the file name & open the filedescriptor
	jal	OpenGenerateFD
	move	$s2	$v0

	# Allocate memory
	move	$a0	$s1
	jal	CreateTable
	move	$s0	$v0	# Save the table address in $s0


	# Generate the exits of the labyrinth
	# GenerateExits needs the table size & address
	move	$a0	$s0
	move	$a1	$s1
	jal	GenerateExits
	# x and y coordinates of the entrance
	move	$s3	$v0
	move	$s4	$v1

	# Print memory
	move	$a0	$s0
	move	$a1	$s1
	jal	PrintTable

	move	$a0	$s0
	move	$a1	$s1
	move	$a2	$s3
	move	$a3	$s4
	jal	GenerateLabyrinth

	# Clean the viewed flag
	move	$a0	$s0
	move	$a1	$s1
	li	$a2	7
	jal	CleanFlag

	# Print memory
	move	$a0	$s0
	move	$a1	$s1
	jal	PrintTable

	# Save the labyrinth in the file
	move	$a0	$s0	# Table address
	move	$a1	$s1	# Table size
	move	$a2	$s2	# File descriptor
	jal	SaveFile

	# ...and we're done!
	j	exit

# Generate mode
# It:
#  - Asks for the table size
#  - Opens the save file descriptor
#  - Create the table in memory
#  - Generate the entrance and exit
#  - ???
#  - Print the table to the console
#  - Saves the labyrinth in the previously opened file descriptor
SolveMode:
	jal	OpenSolveFDs
	move	$s2	$v0	# Read file descriptor
	move	$s3	$v1	# Write file descriptor

	move	$a0	$s2	# Parse file argument: the file descriptor
	jal	ParseFile
	move	$s0	$v0	# Table address
	move	$s1	$v1	# Table size

	move	$a0	$s0
	move	$a1	$s1
	jal	FindEntrance

	move	$a0	$s0
	move	$a1	$s1
	move	$a2	$v0
	move	$a3	$v1
	jal	SolveLabyrinth

	# Clean the viewed flag
	move	$a0	$s0
	move	$a1	$s1
	li	$a2	7
	jal	CleanFlag


	move	$a0	$s0
	move	$a1	$s1
	jal	PrintTable

	move	$a0	$s0	# Table address
	move	$a1	$s1	# Table size
	move	$a2	$s3	# File descriptor
	jal	SaveFile

	j	exit

# Prints the menu
# @return	$v0	The user's choice (1 or 2)
MainMenu:
	# Print "Mode:\n  1. Generate\n  2. Solve\nChoice? "
	li	$v0	4
	la	$a0	StrMenu	# Show menu
	syscall
	# Read int
	li	$v0	5
	syscall

	# Verification
	beq	$v0	1	__JR
	beq	$v0	2	__JR

	# Loop until the choice is valid
	li	$v0	4
	la	$a0	StrMenuInvalid
	syscall
	j	MainMenu

# Asks user for the size of the labyrinth. Size must be > 1
# @return	$v0	The size of the labyrinth
AskSize:
	# Print "Labyrinth size? "
	li	$v0	4
	la	$a0	StrAskSize # Ask labyrinth size
	syscall
	# Read Integer
	li	$v0	5
	syscall

	bgt	$v0	1	__JR

	# Labyrinth size must be > 1, loop until the choice is valid
	li	$v0	4
	la	$a0	StrSizeInvalid
	syscall

	j	AskSize

# Ask the user for a filename
# @param	$a0	The address containing the null-terminated string
# @return	$v0	The length of the string
AskFilename:
# Prologue
	subu	$sp	$sp	12
	sw	$ra	($sp)
	sw	$s0	4($sp)
	sw	$s1	8($sp)

	move	$s0	$a0	# Here comes the buffer!

# Body
	li	$v0	4
	la	$a0	StrAskFilename
	syscall

	li	$v0	8
	move	$a0	$s0
	li	$a1	255
	syscall

	jal	StringLength
	move	$s1	$v0	# Save filename length somewhere

	# Let's check last byte if it is a newline (\n), and replace it with a null terminator (\0)
	addu	$t0	$s0	$s1	# The address of the end of the string
	lb	$t1	-1($t0)	# Save last string byte
	lb	$t2	NewLine
	bne	$t1	$t2	__NoNewLine	# Check if last byte is a newline
	sb	$zero	-1($t0)
	subu	$s1	$s1	1	# String length is now one less
	__NoNewLine:

	move	$v0	$s1	# Return the filename's length
# Epilogue
	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	addu	$sp	$sp	12
	jr	$ra

# Adds the resolved suffix to a given string of a given length
# @param	$a0	The address of the string to modify
# @param	$a1	The length of that string
AddSolvedSuffix:
	la	$t1	StrSolvedSuffix
	addu	$t2	$a0	$a1

	__Loop_AddSolvedSuffix:
		lb	$t3	($t1)
		sb	$t3	($t2)
		addi	$t1	$t1	1
		addi	$t2	$t2	1
		bne	$t3	0	__Loop_AddSolvedSuffix

	jr	$ra

# Open the file descriptors needed for solve mode
# @return	$v0	The file descriptor used to read the labyrinth
# @return	$v1	The file descriptor used to save the solved labyrinth
OpenSolveFDs:
# Prologue
	subu	$sp	$sp	16
	sw	$ra	($sp)
	sw	$s0	4($sp)
	sw	$s1	8($sp)
	sw	$s1	12($sp)

	# Allocate filename buffer
	li	$v0	9
	li	$a0	255
	syscall
	move	$s0	$v0	# Store the address of the buffer

# Body
	__OpenSolveFDs:
	move	$a0	$s0
	jal	AskFilename
	move	$s1	$v0	# Store the length of this filename

	li	$v0	13
	move	$a0	$s0
	li	$a1	0	# Open for reading
	li	$a2	0
	syscall

	bltz	$v0	__OpenError	# Error while reading file
	move	$s2	$v0	# Save file descriptor for later

	move	$a0	$s0
	move	$a1	$s1
	jal	AddSolvedSuffix

	li	$v0	13
	move	$a0	$s0
	li	$a1	1
	li	$a2	0
	syscall

	bltz	$v0	__OpenError	# Error while writing file
	move	$v1	$v0
	move	$v0	$s2

# Epilogue
	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	addu	$sp	$sp	16
	jr	$ra

	__OpenError:
		li	$v0	4
		la	$a0	StrOpenError
		syscall
		j	__OpenSolveFDs

# Open the file descriptor needed for generate mode
# @return	$v0	The just opened file descriptor in write mode
OpenGenerateFD:
# Prologue
	subu	$sp	$sp	8
	sw	$ra	($sp)
	sw	$s0	4($sp)

	# Allocate filename buffer
	li	$v0	9
	li	$a0	255
	syscall
	move	$s0	$v0	# Store the address of the buffer

# Body
	__OpenGenerateFD:
	move	$a0	$s0
	jal	AskFilename

	move	$a0	$s0	# Pass the string as syscall argument
	li	$v0	13
	li	$a1	1	# Open for writing
	li	$a2	0
	syscall

	bltz	$v0	__OpenError2	# Error while reading file

# Epilogue
	lw	$ra	($sp)
	lw	$s0	4($s0)
	addu	$sp	$sp	8
	jr	$ra

	__OpenError2:
		li	$v0	4
		la	$a0	StrOpenError
		syscall
		j	__OpenGenerateFD

# Get a string length (chars before null terminator)
# @param	$a0	String address
# @return	$v0	The length of the string
StringLength:
	li	$v0	0	# Counter
	__StringLength:
		lb	$t0	0($a0)
		beqz	$t0	__JR	# Here's the null terminator
		addi	$v0	$v0	1
		addi	$a0	$a0	1
		j	__StringLength

# Parse the next int in a file
# @param	$a0	The file descriptor
# @param	$a1	The buffer to use to read a char
# @return	$v0	The int read
ParseInt:
	li	$t0	0	# Value
	li	$t1	0	# Bytes read

	# $a0 is the file descriptor already passed in arguments
	# $a1 is the buffer already passed in arguments
	li	$a2	1

	__Loop_ParseInt:
		# Read one char
		li	$v0	14
		syscall
		blt	$v0	1	__End_ParseInt	# Check if exactly 1 char was read

		lbu	$t2	($a1)	# Read from the buffer
		bltu	$t2	48	__CheckEnd_ParseInt
		bgtu	$t2	57	__CheckEnd_ParseInt
		addu	$t1	$t1	1	# Add read char to the byte read count

		subu	$t2	$t2	48
		mulu	$t0	$t0	10
		addu	$t0	$t0	$t2
		j	__Loop_ParseInt

	__CheckEnd_ParseInt:
	beqz	$t1	__Loop_ParseInt	# Check if a byte was read, return in loop if not

	__End_ParseInt:
	move	$v0	$t0
	jr	$ra

# Parse a labyrinth file
# @param	$a0	file descriptor
# @return	$v0	labyrinth address
# @return	$v1	labyrinth size
ParseFile:
	subu	$sp	$sp	28
	sw	$ra	($sp)
	sw	$s0	4($sp)	# $s0: file descriptor
	sw	$s1	8($sp)	# $s1: table size
	sw	$s2	12($sp)	# $s2: max offset ($s1 * $s1 * 4)
	sw	$s3	16($sp)	# $s3: table address
	sw	$s4	20($sp)	# $s4: current offset
	sw	$s5	24($sp) # $s5: the buffer used when reading chars
	move	$s0	$a0

	# Allocate a one byte buffer for reading chars
	li	$v0	9
	li	$a0	1
	syscall
	move	$s5	$v0

	move	$a0	$s0
	move	$a1	$s5
	jal	ParseInt
	move	$s1	$v0	# Save table size
	mulu	$s2	$s1	$s1
	mulu	$s2	$s2	4	# Max offset

	move	$a0	$s1
	jal	CreateTable
	move	$s3	$v0	# Save table

	li	$s4	0
	__Loop_ParseFile:
		move	$a0	$s0
		move	$a1	$s5
		jal	ParseInt
		addu	$t0	$s3	$s4
		sb	$v0	($t0)
		addi	$s4	$s4	1
		blt	$s4	$s2	__Loop_ParseFile

	# Close filedecriptor
	li	$v0	16
	move	$a0	$s0
	syscall

	move	$v0	$s3	# return labyrinth address
	move	$v1	$s1	# return labyrinth size

	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	lw	$s5	24($sp)
	addu	$sp	$sp	28
	jr	$ra

# Save a given int ($a0) to the head of a buffer ($a1) with leading zero and trailing space
# @param	$a0	The int to save
# @param	$a1	The address where to save the chars
SaveNumberToAscii:
	li	$t1	10
	div	$a0	$t1
	mflo	$t0
	mfhi	$t1
	addu	$t0	$t0	48
	addu	$t1	$t1	48
	sb	$t0	($a1)
	sb	$t1	1($a1)
	li	$t0	32	# acii(32) = Space
	sb	$t0	2($a1)
	jr	$ra

# Save a labyrinth to a file descriptor
# @param	$a0	Table address
# @param	$a1	Table size
# @param	$a2	Save file descriptor
SaveFile:
	subu	$sp	$sp	32
	sw	$ra	($sp)
	sw	$s0	4($sp)	# $s0: table address
	sw	$s1	8($sp)	# $s1: table width
	sw	$s2	12($sp)	# $s2: file descriptor
	sw	$s3	16($sp)	# $s3: current line
	sw	$s4	20($sp)	# $s4: current cell
	sw	$s5	24($sp)	# $s5: current buffer pointer
	sw	$s6	28($sp) # $s6: initial buffer pointer (heap allocated)

	move	$s0	$a0
	move	$s1	$a1
	move	$s2	$a2
	li	$s3	0

	# Calculate space needed (table width^2 * 3 + 4) for the buffer
	# The buffer is heap allocated
	mulu	$a0	$s1	$s1
	mulu	$a0	$a0	3
	addu	$a0	$a0	3
	li	$v0	9
	syscall
	move	$s5	$v0	# Save the buffer address
	move	$s6	$v0

	move	$a0	$s1
	move	$a1	$s5
	jal	SaveNumberToAscii
	addi	$s5	$s5	3
	lb	$t0	NewLine
	sb	$t0	-1($s5)	# Replace last char (a space) in buffer with \n

	__LoopLine_SaveFile:
		li	$s4	0
		__LoopCell_SaveFile:
			lb	$a0	($s0)
			move	$a1	$s5
			jal	SaveNumberToAscii
			addi	$s0	$s0	1	# Move table one byte
			addi	$s5	$s5	3	# Move buffer 3 chars
			addi	$s4	$s4	1	# current cell++
			bne	$s4	$s1	__LoopCell_SaveFile

		lb	$t0	NewLine
		sb	$t0	-1($s5)	# Replace last char (a space) in buffer with \n
		addi	$s3	$s3	1	# current line++
		bne	$s3	$s1	__LoopLine_SaveFile

	li	$v0	15
	move	$a0	$s2
	move	$a1	$s6
	subu	$a2	$s5	$s6	# Calculate buffer size
	syscall

	# Close filedecriptor
	li	$v0	16
	move	$a0	$s2
	syscall

	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	lw	$s5	24($sp)
	lw	$s6	28($sp)
	addu	$sp	$sp	32
	jr	$ra

# Create a table for a given size
# @param	$a0	Table size (must be > 0)
# @return	$v0	The table address
CreateTable:
	mul	$a0	$a0	$a0
	li	$v0	9	# malloc of size n*n
	syscall
				# v0: address
	li	$t2	0	# t2: offset
	li	$t3	15 	# t3: constant to store
	__Loop_Increasing:
		beq	$t2	$a0	__JR
		addu	$t4	$v0	$t2	# t4: address + offset
		sb	$t3	0($t4)
		addu	$t2	$t2	1
		j	__Loop_Increasing

# Compute the address of a cell
# @param	$a0	Table address
# @param	$a1	Table size
# @param	$a2	x coordinate
# @param	$a3	y coordinate
# @return	$v0	The cell address
CalcAddress:
	mul	$v0	$a1	$a3
	add	$v0	$v0	$a2
	add	$v0	$v0	$a0
	jr	$ra

# Get a flag of a cell
# @param	$a0	Address of the cell
# @param	$a1	Flag to get
# @return	$v0	= 0 -> flag unset ; > 0 -> flag set
GetFlag:
	lbu	$t0	($a0)
	li	$v0	1
	sllv	$v0	$v0	$a1	# $v1: 1 << $a1
	and	$v0	$v0	$t0
	jr	$ra

# Set a flag of a cell
# @param	$a0	Address of the cell
# @param	$a1	Flag to set (0 = least significant byte)
SetFlag:
	lbu	$t0	($a0)		# load current value in $t0
	li	$t1	1
	sllv	$t1	$t1	$a1	# $t1: 1 << N (N = flag to set)
	or	$t0	$t0	$t1	# turn on the flag...
	sb	$t0	($a0)		# ...and save it
	jr	$ra

# Unset a flag of a cell
# @param	$a0	Address of the cell
# @param	$a1	Flag to set (0 = least significant byte)
UnsetFlag:
	lbu	$t0	($a0)		# load current value in $t1
	li	$t1	1
	sllv	$t1	$t1	$a1	# $t2: 1 << N (N = flag to unset)
	not	$t1	$t1		# invert $t2 to unset the flag...
	and	$t0	$t0	$t1	# ...with an and...
	sb	$t0	($a0)		# ...and save it
	jr	$ra

# Clean a given flag from the grid
# @param	$a0	Table address
# @param	$a1	Table size
# @param	$a2	Flag to clear
CleanFlag:
	subu	$sp	$sp	8
	sw	$ra	($sp)
	sw	$s0	4($sp)

	mul	$s0	$a1	$a1
	addu	$s0	$s0	$a0	# Max address (= $a0 + $a1^2)
	move	$a1	$a2

	__CleanFlag_Loop:
		jal	UnsetFlag
		addu	$a0	$a0	1
		bne	$a0	$s0	__CleanFlag_Loop

	lw	$ra	($sp)
	lw	$s0	4($sp)
	addu	$sp	$sp	8

# Move in a direction
# @param	$a0	X coordinate
# @param	$a1	Y coordinate
# @param	$a2	Direction (UP, RIGHT, DOWN, LEFT)
# @return	$v0	Moved X coordinate
# @return	$v1	Moved Y coordinate
MoveCell:
	__MC_Up:
	bne	$a2	0	__MC_Right
	move	$v0	$a0
	subi	$v1	$a1	1
	jr	$ra

	__MC_Right:
	bne	$a2	1	__MC_Down
	addi	$v0	$a0	1
	move	$v1	$a1
	jr	$ra

	__MC_Down:
	bne	$a2	2	__MC_Left
	move	$v0	$a0
	addi	$v1	$a1	1
	jr	$ra

	__MC_Left:
	subi	$v0	$a0	1
	move	$v1	$a1
	jr	$ra

# Find the coordinates of the entrance
# @param	$a0	Table address
# @param	$a1	Table size
# @return	$v0	Entrance x
# @return	$v1	Entrance y
FindEntrance:
	subu	$sp	$sp	24
	sw	$ra	($sp)
	sw	$s0	4($sp)
	sw	$s1	8($sp)
	sw	$s2	12($sp)
	sw	$s3	16($sp)
	sw	$s4	20($sp)

	move	$s0	$a0
	move	$s1	$a1
	li	$s2	0
	mulu	$s3	$a1	$a1
	__SearchEntrance_Loop:
		beq	$s2	$s3	__SearchEntrance_EndLoop

		# Check the entrance flag
		addu	$a0	$s0	$s2
		li	$a1	4
		jal	GetFlag
		addi	$s2	$s2	1
		beqz	$v0	__SearchEntrance_Loop

	__SearchEntrance_EndLoop:
	subu	$s2	$s2	1	# We've gone one step too far
	div	$s2	$s1	# Divide the offset by the size to get the coordinates
	mfhi	$v0	# return x...
	mflo	$v1	# ...and y

	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	addu	$sp	$sp	24
	jr	$ra

# Function IsOutOfBounds
# @param	$a0	-
# @param	$a1	Size
# @param	$a2	x
# @param	$a3	y
# Returns : 	$v0	Boolean
IsOutOfBounds:
	bltz	$a2	__True
	bge	$a2	$a1	__True
	bltz	$a3	__True
	bge	$a3	$a1	__True
	j __False


# Function GenerateNextDirection
# @param	$a0	Address
# @param	$a1	Size
# @param	$a2	x coordinate
# @param	$a3	y coordinate
# @param	$t9	1 if solving mode, 0 otherwise (checks walls)
# @return 	$v0	the next direction
GenerateNextDirection:
# Prologue
	subu	$sp	$sp	36
	sw	$s0	0($sp)
	sw	$s1	4($sp)
	sw	$s2	8($sp)
	sw	$s3	12($sp)
	sw	$s4	16($sp)
	sw	$s5	20($sp)
	sw	$s6	24($sp)
	sw	$s7	28($sp)
	sw	$ra	32($sp)

# Body
	move	$s0	$a0	# s0: Original address
	move	$s1	$a1	# s1: Size
	move	$s2	$a2	# s2: Original x
	move	$s3	$a3	# s3: Original y
	li 	$s4 	0 	# s4: Counter from 0 to 3
				#     Used to generate increasingly random numbers (ie: rand(0,n); n++)
	li	$s5	-1	# s5: Returned direction
	li	$s6	0	# s6: Current direction
	move	$s7	$t9	# s7: 1 if solving mode

	# This loops through all the four directions (0..3)
	__GenerateNextBox_Loop:
		# Move the coords in the current direction
		move	$a0	$s2
		move	$a1	$s3
		move	$a2	$s6
		jal	MoveCell

		# Skip if the cell is...
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$v0
		move	$a3	$v1
		# ...out of bount...
		jal	IsOutOfBounds
		bnez	$v0	__GenerateNextBox_LoopContinue
		jal	CalcAddress
		move	$a0	$v0
		# ...or already visited
		li	$a1	7
		jal	GetFlag
		bnez	$v0	__GenerateNextBox_LoopContinue

		# Check the presence of walls in solve mode
		beqz	$s7	__GenerateNextBox_NoWalls
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$s2
		move	$a3	$s3
		jal	CalcAddress
		move	$a0	$v0
		move	$a1	$s6
		jal	GetFlag
		bnez	$v0	__GenerateNextBox_LoopContinue
		__GenerateNextBox_NoWalls:

		# Now that we checked that we can go to this cell,
		# Lets random between 0 and [the number of direction already checked]...
		li	$a0	0
		move	$a1	$s4
		jal	RandomBetween
		addi	$s4	$s4	1
		bnez	$v0	__GenerateNextBox_LoopContinue

		# ...and assign the current direction if the number is right (= 0)
		move	$s5	$s6

		__GenerateNextBox_LoopContinue:
		# current direction++, and loop
		addi	$s6	$s6	1
		bne	$s6	4	__GenerateNextBox_Loop

	# return the selected direction
	move	$v0	$s5

	# restore the arguments (usefull for chain calls)
	move	$a0	$s0
	move	$a1	$s1
	move	$a2	$s2
	move	$a3	$s3
#Epilogue
	lw	$s0	0($sp)
	lw	$s1	4($sp)
	lw	$s2	8($sp)
	lw	$s3	12($sp)
	lw	$s4	16($sp)
	lw	$s5	20($sp)
	lw	$s6	24($sp)
	lw	$s7	28($sp)
	lw	$ra	32($sp)
	addu	$sp	$sp	36
	jr	$ra

# Generate the labyrinth
# @param	$a0	Table address
# @param	$a1	Table size
# @param	$a2	Entrance X
# @param	$a3	Entrance y
GenerateLabyrinth:
	subu	$sp	$sp	32
	sw	$ra	0($sp)
	sw	$s0	4($sp)		# $s0: Table address
	sw	$s1	8($sp)		# $s1: Table size
	sw	$s2	12($sp)		# $s2: Entrance X
	sw	$s3	16($sp)		# $s3: Entrance Y
	sw	$s4	20($sp)		# $s4: Current X
	sw	$s5	24($sp)		# $s5: Current Y
	sw	$s6	28($sp)		# $s6: Temporary direction storage

	# Load all arguments
	move	$s0	$a0
	move	$s1	$a1
	move	$s2	$a2
	move	$s3	$a3
	move	$s4	$a2
	move	$s5	$a3

	# Mark the entrance as visited
	jal	CalcAddress
	move	$a0	$v0
	li	$a1	7
	jal	SetFlag

	# Main generation loop
	__Generate_Loop:
		# Stack the current cell
		subu	$sp	$sp	8
		sw	$s4	($sp)
		sw	$s5	4($sp)

		__Generate_Loop_NoStack:

		# Compute the next direction to go
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$s4
		move	$a3	$s5
		li	$t9	0
		jal	GenerateNextDirection
		move	$s6	$v0

		# If no direction is available (= -1), unstack to the previous cell
		beq	$s6	-1	__Generate_CheckUnstack

		# Destroy the wall of the current cell in the direction
		jal	CalcAddress
		move	$a0	$v0
		move	$a1	$s6
		jal	UnsetFlag	# Destroy the wall!

		# Move to the next cell
		move	$a0	$s4
		move	$a1	$s5
		move	$a2	$s6
		jal	MoveCell
		move	$s4	$v0
		move	$s5	$v1

		# And compute the opposite direction with an XOR on 0b10
		xori	$s6	$s6	2

		# Destroy the wall & mark the cell as visited
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$s4
		move	$a3	$s5
		jal	CalcAddress

		move	$a0	$v0
		move	$a1	$s6	# Destroy the second wall
		jal	UnsetFlag
		li	$a1	7	# and mark the cell as visited
		jal	SetFlag

		# ...and loop!
		j	__Generate_Loop

		__Generate_CheckUnstack:
		# Check if we can unstack (if we're not already on the entrance)
		bne	$s2	$s4	__Generate_Unstack
		bne	$s3	$s5	__Generate_Unstack
		# We're on the entrance without available cell, we finished the generation!
		j	__Generate_End

		# Unstack the previous cell
		__Generate_Unstack:
		lw	$s4	($sp)
		lw	$s5	4($sp)
		addu	$sp	$sp	8
		# ...and loop without re-stacking the cell
		j	__Generate_Loop_NoStack


	__Generate_End:
	lw	$ra	0($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	lw	$s5	24($sp)
	lw	$s6	28($sp)
	addu	$sp	$sp	32
	jr	$ra

# Solve the labyrinth
# @param	$a0	Table address
# @param	$a1	Table size
# @param	$a2	Entrance X
# @param	$a3	Entrance y
SolveLabyrinth:
	subu	$sp	$sp	32
	sw	$ra	0($sp)
	sw	$s0	4($sp)		# $s0: Table address
	sw	$s1	8($sp)		# $s1: Table size
	sw	$s2	12($sp)		# $s2: Entrance X
	sw	$s3	16($sp)		# $s3: Entrance Y
	sw	$s4	20($sp)		# $s4: Current X
	sw	$s5	24($sp)		# $s5: Current Y
	sw	$s6	28($sp)		# $s6: Temporary direction storage

	# Load all arguments
	move	$s0	$a0
	move	$s1	$a1
	move	$s2	$a2
	move	$s3	$a3
	move	$s4	$a2
	move	$s5	$a3

	# Mark the entrance as visited
	jal	CalcAddress
	move	$a0	$v0
	li	$a1	7
	jal	SetFlag

	# Main generation loop
	__Solve_Loop:
		# Stack the current cell
		subu	$sp	$sp	8
		sw	$s4	($sp)
		sw	$s5	4($sp)

		# Compute the next direction to go
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$s4
		move	$a3	$s5
		li	$t9	1
		jal	GenerateNextDirection
		move	$s6	$v0

		# If no direction is available (= -1), unstack to the previous cell
		beq	$s6	-1	__Solve_Unstack

		# Move to the next cell
		move	$a0	$s4
		move	$a1	$s5
		move	$a2	$s6
		jal	MoveCell
		move	$s4	$v0
		move	$s5	$v1

		# Compute the cell address
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$s4
		move	$a3	$s5
		jal	CalcAddress

		# Check if the cell is the exit
		move	$a0	$v0
		li	$a1	5
		jal	GetFlag
		bnez	$v0	__Solve_EndLoop

		# Mark it as seen
		li	$a1	7
		jal	SetFlag

		move	$a0	$s0
		move	$a1	$s1
		jal	PrintTable

		# ...and loop!
		j	__Solve_Loop


		# Unstack the previous cell
		__Solve_Unstack:
		lw	$s4	($sp)
		lw	$s5	4($sp)
		addu	$sp	$sp	8
		# ...and loop without re-stacking the cell
		j	__Solve_Loop



	__Solve_EndLoop:
		lw	$s4	($sp)
		lw	$s5	4($sp)
		addu	$sp	$sp	8

		# Compute the cell address
		move	$a0	$s0
		move	$a1	$s1
		move	$a2	$s4
		move	$a3	$s5
		jal	CalcAddress

		move	$a0	$v0
		li	$a1	4
		jal	GetFlag
		bnez	$v0	__Solve_End

		li	$a1	6
		jal	SetFlag

		j	__Solve_EndLoop

	__Solve_End:

	lw	$ra	0($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	lw	$s5	24($sp)
	lw	$s6	28($sp)
	addu	$sp	$sp	32
	jr	$ra

# Generates the entrance and the exit of the labyrinth
# @param	$a0	Table address
# @param	$a1	Table size
GenerateExits:
#Prologue
	subu	$sp	$sp	28
	sw	$ra	0($sp)
	sw	$s0	4($sp)		# $s0: Table address
	sw	$s1	8($sp)		# $s1: Table size
	sw	$s2	12($sp)		# $s2: Entrance column
	sw	$s3	16($sp)		# $s3: Entrance cell
	sw	$s4	20($sp)		# $s4: Exit column
	sw	$s5	24($sp)		# $s5: Exit cell

# Body
	move	$s0	$a0	# Table address
	move	$s1	$a1	# Table size

	# Assign the entrance and exit columns
	li	$a0	0
	li	$a1	1
	jal	RandomBetween
	beqz	$v0	__GenerateExits_ColumnOrder
		li	$s2	0
		subu	$s4	$s1	1
		j	__GenerateExits_ColumnOrder_End
	__GenerateExits_ColumnOrder:
		subu	$s2	$s1	1
		li	$s4	0
	__GenerateExits_ColumnOrder_End:

	# Calculate the entrance & exit cells ( = rand(0, Size - 1))
	subu	$a1	$s1	1
	jal	RandomBetween
	move	$s3	$v0
	jal	RandomBetween
	move	$s5	$v0

	# Swap coordinates randomly (to use horizontal or vertical borders)
	jal	RandomBetween
	beqz	$v0	__GenerateExits_DontSwap
		# Swap entrance
		move	$t0	$s2
		move	$s2	$s3
		move	$s3	$t0

		# Swap exit
		move	$t0	$s4
		move	$s4	$s5
		move	$s5	$t0

	__GenerateExits_DontSwap:

	move	$a0	$s0
	move	$a1	$s1
	move	$a2	$s2
	move	$a3	$s3
	jal	CalcAddress
	move	$a0	$v0
	li	$a1	4	# 4 = entrance flag
	jal	SetFlag		# set entrance

	move	$a0	$s0
	move	$a1	$s1
	move	$a2	$s4
	move	$a3	$s5
	jal	CalcAddress
	move	$a0	$v0
	li	$a1	5	# 5 = exit flag
	jal	SetFlag		# set entrance

	move	$v0	$s2	# Return entrance coordinates
	move	$v1	$s3

# Epilogue
	lw	$ra	0($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	lw	$s5	24($sp)
	addu	$sp	$sp	28
	jr	$ra



# Function PrintTable
# Parameters : 	$a0: address of the first integer in the table
# 		$a1: width of the table (as in how many integers)
# Pre-conditions: $a0 >=0
# Returns: -
PrintTable:
# Prologue:
	subu	$sp	$sp	4
	sw	$ra	0($sp)
# Body:
	# mul	$a1 	$a1	$a1
	move	$t0	$a0	# Table address
	move	$t1	$a1	# Table size
	# printing "Table width: X"
	la	$a0	StrTableWidth
	li	$v0	4
	syscall
	move	$a0	$t1
	jal	PrintInt

	# printing "stored at X"
	la	$a0	StrStoredAt
	li	$v0	4
	syscall
	move	$a0	$t0
	jal	PrintInt

	# Printing table's content
				# $t1: width
	li	$t2	0	# $t2: line counter (from 1 to width)
	li	$t3	0 	# $t3: offset (in bytes, so, from 0 to width*width). As opposed to $t2 and $t4 it is never reset
	li	$t4	0	# $t4
	__Loop_PrintTable:
		bge	$t2	$t1	__Fin_Loop_PrintTable
		li	$t5	0	# $t5: char counter (from 1 to width)
		addi	$t2	$t2	1
		__Loop_PrintLine:
			bge	$t5	$t1	__Fin_Loop_PrintLine
			add	$t4	$t0	$t3	# t4: Address of the first int of the table + offset
			# print integer in memory at address $t4
			lbu	$a0	0($t4)
			li	$v0	1
			syscall
			jal	PrintSpace

			addi	$t3	$t3	1	# increment offset
			addi	$t5	$t5	1
			j	__Loop_PrintLine
		__Fin_Loop_PrintLine:
		jal	PrintNewline
		j	__Loop_PrintTable
__Fin_Loop_PrintTable:
	# print newline
	la	$a0	NewLine
	li	$v0	4
	syscall
# Epilogue:
	lw	$ra	0($sp)
	addu	$sp	$sp	4
	jr	$ra



# Function PrintNewline
# Parameters:
# Pre-conditions:
# Returns:
PrintSpace:
# Body:
	la	$a0	StrSpace
	li	$v0	4
	syscall
# Epilogue:
	jr	$ra



# Function PrintNewline
# Parameters:
# Pre-conditions:
# Returns:
PrintNewline:
# Body:
	la	$a0	NewLine
	li	$v0	4
	syscall
# Epilogue:
	jr	$ra



# Function PrintInt
# Parameters: $a0: Int to print
# Pre-conditions:
# Returns:

PrintInt:
# Body:
	li	$v0	1
	syscall

	la	$a0	NewLine
	li	$v0	4
	syscall
# Epilogue:
	jr	$ra


# Returns a random integer included in [$a0,$a1[
# Parameters :  $a0: Minimum
# 		$a1: Maximum
# Pre-conditions : 0 <= $a0 < $a1
# Returns : $v0: Random int
RandomBetween:
# Prologue
	move	$t7	$a1
	move	$t6	$a0
# Body
	# the syscall takes for granted that we generate between 0 and n
	# we want an int between n and m
	# procedure: 	max = max - min
	# 		number = syscall(max)
	# 		number = number + min
	addi	$a1	$a1	1
	move	$t0	$a0		# t0: minimum
	sub	$a0	$a1	$a0	# a0: maximum-min
	li	$v0	42
	syscall

	add	$v0	$a0	$t0

# Epilogue
	move	$a1	$t7
	move	$a0	$t6
	jr	$ra


__JR:
	jr	$ra
__True:
	li	$v0	1
	jr	$ra
__False:
	li	$v0	0
	jr	$ra


exit:
	li	$v0	10
	syscall

# vim: sw=8 ts=8 noet
