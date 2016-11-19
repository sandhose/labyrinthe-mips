# projet.s

.data
seed:
	.word 0xdeadbeef, 0x13371337
max_random_float:
	.float 2147483647
str1:
	.asciiz "Random number: "
TableWidth:
	.asciiz "Table width: "
StoredAt:
	.asciiz "Stored at: "
NewLine:
	.asciiz "\n"
Menu:
	.asciiz "Mode:\n  1. Generate\n  2. Solve\nChoice? "
MenuInvalid:
	.asciiz "Invalid choice.\n"

.text
.globl __start

# Entry point
__start:
	jal	MainMenu

	move	$a0	$v0
	li	$v0	1
	syscall

	li	$a0	32
	li	$a1	0
	jal	CreateTable

	move	$a0	$v0
	li	$a1	32
	jal	PrintTable

	j	exit

MainMenu:
	li	$v0	4
	la	$a0	Menu	# Show menu
	syscall

	li	$v0	5
	syscall

	beq	$v0	1	__JR
	beq	$v0	2	__JR

	li	$v0	4
	la	$a0	MenuInvalid
	syscall
	j	MainMenu

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
	la	$a0	TableWidth
	li	$v0	4
	syscall
	move	$a0	$t1
	jal	PrintInt

	#printing "stored at X"
	la	$a0	StoredAt
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
