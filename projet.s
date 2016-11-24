# projet.s

.data
seed:
	.word 0xdeadbeef, 0x13371337
max_random_float:
	.float 2147483647.0
Buffer:
	.space 255
Size:
	.align 2
	.space 1
Address:
	.align 2
	.space 1
StrSolvedSuffix:
	.asciiz ".resolu"
StrRandomNumber:
	.asciiz "Random number: "
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
	.asciiz "Labyrinth size must be at least 3\n"
StrAskFilename:
	.asciiz "File name? "
StrMode:
	.asciiz "Mode: "
StrSize:
	.asciiz " ; Size: "
StrOpenError:
	.asciiz "Can't open file\n"
StrSpace:
	.asciiz " "
NewLine:
	.asciiz "\n"

.text
.globl __start

# Entry point
__start:
	#get os time in $v0
	li	$v0	30
	syscall
	li	$a0	0

	#set seed to os time
	move	$a1	$v0
	li	$v0	40
	#li	$a0	0 #redundant
	syscall

	jal	MainMenu
	move	$s0	$v0	# s0: Choice

	beq	$v0	1	GenerateMode
	beq	$v0	2	SolveMode

GenerateMode:
	jal	AskSize
	move	$s0	$v0

	jal	AskFilename
	move	$s1	$v0

	# Display some stuff (mode + size)

	# Print "Mode: N"
	li	$v0	4
	la	$a0	StrMode
	syscall
	li	$v0	1
	move	$a0	$s0
	syscall

	# Print "; Size: N"
	li	$v0	4
	la	$a0	StrSize
	syscall
	li	$v0	1
	move	$a0	$s0
	syscall

	# Print "\n"
	li	$v0	4
	la	$a0	NewLine
	syscall

	# Allocate memory
	move	$a0	$s0
	sw	$a0	Size
	li	$a1	0
	jal	CreateTable
	sw	$v0	Address

	# Parameters :	$a0: Adress of the first integer in the table
	#		$a1: Table width
	# 		$a2: t[x]
	#		$a3: y
	li	$a0	0
	li	$a1	2
	li	$a2	2
	jal	SetBox

	jal	GenerateExits

	# Print memory
	jal	PrintTable

	j	exit

SolveMode:
	jal	OpenSolveFDs
	move	$a0	$v0

	jal	ParseFile

	j	exit

# Prints the menu
# Returns : User's choice (1 or 2)
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

# Asks user for the size of the labyrinth. Size must be > 2
# Returns : $v0: Int, user's choice
AskSize:
	# Print "Labyrinth size? "
	li	$v0	4
	la	$a0	StrAskSize # Ask labyrinth size
	syscall
	# Read Integer
	li	$v0	5
	syscall

	bgt	$v0	2	__JR

	# Labyrinth size must be > 2, loop until the choice is valid
	li	$v0	4
	la	$a0	StrSizeInvalid
	syscall

	j	AskSize

# Ask the user for a filename
# @returns	$v0	The address containing the null-terminated string
# 		$v1	The length of the string
AskFilename:
# Prologue
	subu	$sp	$sp	12
	sw	$ra	($sp)
	sw	$s0	4($sp)
	sw	$s1	8($sp)

# Body
	li	$v0	4
	la	$a0	StrAskFilename
	syscall

	li	$v0	8
	la	$a0	Buffer
	li	$a1	255
	syscall
	move	$s0	$a0	# Save filename address somewhere

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

	move	$v0	$s0	# Return filename address and its length
	move	$v1	$s1
# Epilogue
	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	addu	$sp	$sp	12
	jr	$ra

# Adds the resolved suffix to a given ($a0) string of a given ($a1) length
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

OpenSolveFDs:
# Prologue
	subu	$sp	$sp	16
	sw	$ra	($sp)
	sw	$s0	4($sp)
	sw	$s1	8($sp)
	sw	$s1	12($sp)

# Body
	__OpenSolveFDs:
	jal	AskFilename
	move	$s0	$v0	# Store the address of the filename
	move	$s1	$v1	# Store the length of this filename

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
	jr	$ra

	__OpenError:
		li	$v0	4
		la	$a0	StrOpenError
		syscall
		j	__OpenSolveFDs


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
# @returns	$v0	The int read
ParseInt:
	li	$t0	0	# Value
	li	$t1	0	# Bytes read

	# $a0 is the file descriptor already passed in arguments
	la	$a1	Buffer	# Buffer
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
# @returns	$v0	labyrinth size
# @returns	$v1	labyrinth address
ParseFile:
	subu	$sp	$sp	24
	sw	$ra	($sp)
	sw	$s0	4($sp)	# $s0: file descriptor
	sw	$s1	8($sp)	# $s1: table size
	sw	$s2	12($sp)	# $s2: max offset ($s1 * $s1 * 4)
	sw	$s3	16($sp)	# $s3: table address
	sw	$s4	20($sp)	# $s4: current offset
	move	$s0	$a0

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
		jal	ParseInt
		addu	$t0	$s3	$s4
		sw	$v0	($t0)
		addi	$s4	$s4	4
		blt	$s4	$s2	__Loop_ParseFile

	move	$v0	$s1
	move	$v1	$s3

	lw	$ra	($sp)
	lw	$s0	4($sp)
	lw	$s1	8($sp)
	lw	$s2	12($sp)
	lw	$s3	16($sp)
	lw	$s4	20($sp)
	addu	$sp	$sp	24
	jr	$ra


# Function CreateTable
# Pre-conditions: $a0 >=0
# Parameters :	$a0: Table width (as in how many integers)
# Returns : Adress of the first int in the table in $v0
CreateTable:
	mul	$a0	$a0	$a0
	move	$t0	$a0		# $t0: width*width
	mul	$a0	$a0	4	# $a0: width squared and in bytes
	li	$v0	9		# malloc of size 4*n*n
	syscall
				# v0: address
	li	$t2	0	# t2: offset
	li	$t3	15 	# t3: constant to store
	__Loop_Increasing:
		beq	$t2	$a0	__JR
		addu	$t4	$v0	$t2	# t4: adress + offset
		sw	$t3	0($t4)
		addu	$t2	$t2	4
		j	__Loop_Increasing



# Function SetBox
# Pre-conditions:
# Parameters :	$a0: int
#		$a1: x
#		$a2: y
# Returns : -
SetBox:
	lw	$t0	Address
	lw	$t1	Size
	mul	$t3	$a2	$t1	#t3: offset = line number * table width (to select the nth line)
	add	$t3	$t3	$a1	#t3: add to that the column number (nth line + nth column)
	mul	$t3	$t3	4 	#t3: convert to bytes
	add	$t4	$t0	$t3	#t4: address + offset
	sw	$a0	0($t4)
	jr	$ra



# Function GenerateExits
# Pre-conditions:
# Parameters :
# Returns : -
GenerateExits:
	lw	$t0	Address
	lw	$t1	Size

	li	$a0	0
	li	$a1	1
	jal	RandomBetween
	mul	$t2	$v0	5	#t2 = rand(0,1) * 5
					#either 0 or 5

	subu	$a1	$t1	1
	jal	RandomBetween
	move	$t2	$v0



# Function PrintTable
# Parameters : 	$a0: adress of the first integer in the table
# 		$a1: width of the table (as in how many integers)
# Pre-conditions: $a0 >=0
# Returns: -
PrintTable:
# Prologue:
	subu	$sp	$sp	4
	sw	$ra	0($sp)
# Body:
	# mul	$a1 	$a1	$a1
	lw	$t0	Address
	lw	$t1	Size
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
	li	$t3	0 	# $t3: offset (in bytes, so, from 0 to 4*width*width). As opposed to $t2 and $t4 it is never reset
	li	$t4	0	# $t4
	__Loop_PrintTable:
		bge	$t2	$t1	__Fin_Loop_PrintTable
		li	$t5	0	# $t5: char counter (from 1 to width)
		addi	$t2	$t2	1
		__Loop_PrintLine:
			bge	$t5	$t1	__Fin_Loop_PrintLine
			add	$t4	$t0	$t3	# t4: Adress of the first int of the table + offset
			# print integer in memory at adress $t4
			lw	$a0	0($t4)
			li	$v0	1
			syscall
			jal	PrintSpace

			addi	$t3	$t3	4	# increment offset
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
#Prologue
	subu	$sp	$sp	4
	sw	$a0	0($sp)
#Body
	#the syscall takes for granted that we generate between 0 and n
	#we want an int between n and m
	#procedure: 	max = max - min
	#		number = syscall(max)
	#		number = number + min
	addi	$a1	$a1	1
	move	$t0	$a0		#t0: minimum
	sub	$a0	$a1	$a0	#a0: maximum-min
	li	$v0	42
	syscall

	add	$v0	$a0	$t0

#Epilogue
	lw	$a0	0($sp)
	addu	$sp	$sp	4
	jr	$ra



# Function random_generator
# Returns a random integer between 0 and 2^32-1
# Parameters :
# Returns : $v0: Random int
random_generator:
	li	$v0	41
	jr	$ra

__JR:
	jr	$ra



exit:
	li	$v0	10
	syscall

# vim: sw=8 ts=8 noet
