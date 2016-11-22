# projet.s

.data
seed:
	.word 0xdeadbeef, 0x13371337
max_random_float:
	.float 2147483647.0
Filename:
	.space 255
SolveSuffix:
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
	.asciiz	"File name? "
StrMode:
	.asciiz "Mode: "
StrSize:
	.asciiz " ; Size: "
StrOpenError:
	.asciiz "Can't open file\n"
NewLine:
	.asciiz "\n"

.text
.globl __start

# Entry point
__start:
	jal	MainMenu
	move	$s0	$v0	#s0: Choice

	beq	$v0	1	GenerateMode
	beq	$v0	2	SolveMode

GenerateMode:
	jal	AskSize
	move	$s0	$v0

	jal	AskFilename
	move	$s1	$v0

	# Display some stuff (mode + size)

	#Print "Mode: N"
	li	$v0	4
	la	$a0	StrMode
	syscall
	li	$v0	1
	move	$a0	$s0
	syscall

	#Print "; Size: N"
	li	$v0	4
	la	$a0	StrSize
	syscall
	li	$v0	1
	move	$a0	$s1
	syscall

	#Print "\n"
	li	$v0	4
	la	$a0	NewLine
	syscall

	#Allocate memory
	move	$a0	$s1
	li	$a1	0
	jal	CreateTable

	#Print memory
	move	$a0	$v0
	move	$a1	$s1
	jal	PrintTable

	j	exit

SolveMode:
	jal	OpenSolveFDs
	move	$s1	$v0

	j	exit

# Prints the menu
# Returns : User's choice (1 or 2)
MainMenu:
	#Print "Mode:\n  1. Generate\n  2. Solve\nChoice? "
	li	$v0	4
	la	$a0	StrMenu	# Show menu
	syscall
	#Read int
	li	$v0	5
	syscall

	#Verification
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
	#Print "Labyrinth size? "
	li	$v0	4
	la	$a0	StrAskSize # Ask labyrinth size
	syscall
	#Read Integer
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
#		$v1	The length of the string
AskFilename:
# Prologue
	subu	$sp	$sp	8
	sw	$ra	($sp)
	sw	$s0	4($sp)

# Body
	li	$v0	4
	la	$a0	StrAskFilename
	syscall

	li	$v0	8
	la	$a0	Filename
	li	$a1	255
	syscall
	move	$s0	$a0	# Save filename address somewhere

	jal	StringLength
	move	$v1	$v0
	move	$v0	$s0

# Epilogue
	lw	$ra	($sp)
	lw	$s0	4($sp)
	addu	$sp	$sp	8
	jr	$ra

OpenSolveFDs:
# Prologue
	subu	$sp	$sp	12
	sw	$ra	($sp)
	sw	$s0	4($sp)
	sw	$s1	8($sp)

# Body
	__OpenSolveFDs:
	jal	AskFilename
	move	$s0	$v0	# Store the address of the filename
	move	$s1	$v1	# Store the length of this filename

	li	$v0	13
	move	$a0	$s0
	la	$a1	0	# Open for reading
	la	$a2	0
	syscall

	bltz	$v0	__OpenError	# Error while reading file
	move	$s0	$v0	# Save file descriptor for later

	jal	StringLength
	move	$a0	$v0
	li	$v0	1
	syscall


# Epilogue
	lw	$ra	($sp)
	lw	$s0	4($s0)
	lw	$s1	8($s1)
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


# Returns a random integer included in [$a0,$a1[
# Parameters :  $a0: Minimum
#				$a1: Maximum
# Pre-conditions : 0 <= $a0 < $a1
# Returns : $v0: Random int
RandomBetween:
# Prologue
	subu	$sp	$sp	12
	sw	$ra	($sp)
	swc1	$f0	4($sp)
	swc1	$f1	8($sp)
# Body
	jal	random_generator
	andi	$v0	$v0	0x7fffffff
	mtc1	$v0	$f0
	cvt.s.w	$f0	$f0
	lwc1	$f1	max_random_float
	div.s	$f0	$f0	$f1
	sub	$a1	$a1	$a0
	mtc1	$a1	$f1
	cvt.s.w	$f1	$f1
	mul.s	$f0	$f0	$f1
	mtc1	$a0	$f1
	cvt.s.w	$f1	$f1
	add.s	$f0	$f0	$f1
	cvt.w.s	$f0	$f0
	mfc1	$v0	$f0
# Epilogue
	lw	$ra	($sp)
	lwc1	$f0	4($sp)
	lwc1	$f1	8($sp)
	addu	$sp	$sp	12
	jr	$ra

# Function random_generator
# Returns a random integer between 0 and 2^32-1
# Parameters :
# Returns : $v0: Random int
random_generator:
# Prologue
# Body
	lw	$t0	seed
	andi	$t1	$t0	65535
	mulu	$t1	$t1	36969
	srl	$t2	$t0	16
	addu	$t0	$t1	$t2
	lw	$t1	seed+4
	andi	$t2	$t1	65535
	mulu	$t2	$t2	18000
	srl	$t3	$t1	16
	addu	$t1	$t2	$t3
	sw	$t0	seed
	sw	$t1	seed+4
	sll	$v0	$t0	16
	addu	$v0	$v0	$t1
# Epilogue
	jr	$ra

# Function CreateTable
# Pre-conditions: $a0 >=0
# Parameters :	$a0: Table width (as in how many integers)
#				$a1: 0: Sorted in ascending order,
#					 1: Sorted in descending order,
#					 2: Scrambled
# Returns : Adress of the first int in the table in $v0
CreateTable:
	move	$t0	$a0
	mul	$a0	$a0	4	#width in bytes
	li	$v0	9		#malloc of size 4*n
	syscall
	move	$t1	$v0	#t1: address
	li	$t2	0	#t2: offset
	li	$t3	15 	#t3: stored constant
	__Loop_Increasing:
		beq	$t2	$a0	__JR
		addu	$t4	$t1	$t2 #t4: adress + offset
		sw	$t3	0($t4)
		addu	$t2	$t2	4
		j	__Loop_Increasing

# Function PrintTable
# Parameters : 	$a0: adress of the first integer in the table
#		$a1: width of the table (as in how many integers)
# Pre-conditions: $a0 >=0
# Returns: -
PrintTable:
#Prologue:
	subu	$sp	$sp	4
	sw	$ra	0($sp)
#Body:
	move	$t0	$a0 #t0: adress of the first integer in the table
	move	$t1	$a1 #t1: width of the table (as in how many integers)
	#printing "Table width: X"
	la	$a0	StrTableWidth
	li	$v0	4
	syscall
	move	$a0	$t1
	jal	PrintInt

	#printing "stored at X"
	la	$a0	StrStoredAt
	li	$v0	4
	syscall
	move	$a0	$t0
	jal	PrintInt

	#Printing table's content
	li	$t2	4
	mul	$t1	$t1	$t2 	#$t1: Bytes needed to store the table
	li	$t3	0 		#$t3: offset
	#add	$t4	$t1	$t0 	#$t4: end adress of the table
	__Loop_PrintTable:
		bge	$t3	$t1	Fin__Loop_PrintTable
		add	$t4	$t0	$t3	#Adress of the first int of the table + offset
		lw	$a0	0($t4)
		jal	PrintInt
		addi	$t3	$t3	4	#increment offset
		j __Loop_PrintTable
Fin__Loop_PrintTable:
	#print newline
	la	$a0	NewLine
	li	$v0	4
	syscall
#Epilogue:
	lw	$ra	0($sp)
	addu	$sp	$sp	4
	jr	$ra

# Function PrintInt
# Parameters: $a0: Int to print
# Pre-conditions:
# Returns:
PrintInt:
#Prologue:
	subu	$sp	$sp	4
	sw	$a0	0($sp)

#Body:
	li	$v0	1
	syscall

	la	$a0	NewLine
	li	$v0	4
	syscall

#Epilogue:
	lw	$a0	0($sp)
	addu	$sp	$sp	4
	jr	$ra

__JR:
	jr	$ra

exit:
	li	$v0	10
	syscall

# vim: sw=8 ts=8 noet
