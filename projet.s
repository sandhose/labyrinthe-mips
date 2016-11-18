# projet.s

.data
seed: .word 0xdeadbeef, 0x13371337
max_random_float: .float 2147483647
str1: .asciiz "Random number: "
TableWidth: .asciiz "Table width: "
StoredAt: .asciiz "Stored at: "
RetChar: .asciiz "\n"
.text
.globl __start

# Entry point
__start:
	li	$v0	4
	la	$a0	str1
	syscall

	li	$a0	0
	li	$a1	101
	jal	RandomBetween
	move	$a0	$v0
	li	$v0	1
	syscall


	jal	CreateTable

	j	exit

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
# Returns : Adress of the first int in the table
CreateTable:
	move	$t0	$a0
	mul	$a0	$a0	4	# taille en octets
	li	$v0	9
	syscall
	move	$t1	$v0
	beq	$a1	0	Increasing
	beq	$a1	1	Decreasing
	beq	$a1	2	Random

Increasing:
	li	$t2	0	#counter
	mul	$t3	$t0	4
	__Loop_Increasing:
		beq	$t2	$t3	__JR
		addu	$t4	$t1	$t2
		sw	$t2	0($t4)
		addu	$t2	$t2	4
		j	__Loop_Increasing

Decreasing:
	li	$t2	0	#counter
	mul	$t3	$t0	4	# max n
	__Loop_Decreasing:
		beq	$t2	$t3	__JR
		addu	$t4	$t1	$t2
		subu	$t5	$t3	$t2
		sw	$t5	0($t4)
		addu	$t2	$t2	4
		j	__Loop_Decreasing
Random:
	li	$t2	0	#counter
	mul	$t3	$t0	4	# max n
	__Loop_Random:
		beq	$t2	$t3	__JR
		addu	$t4	$t1	$t2

		move	$t6	$a0	#save a0
		li	$v0	41
		syscall


		move	$t5	$a0
		move	$a0	$t6
		move	$v0	$t1

		sw	$t5	0($t4)
		addu	$t2	$t2	4
		j	__Loop_Random

# Function PrintTable
# Parameters : $a0: width of the table (as in how many integers)
# Pre-conditions: $a0 >=0
# Returns: -
PrintTable:
#Prologue:
	subu	$sp	$sp	24
	sw	$s0	20($sp)
	sw	$s1	16($sp)
	sw	$s2	12($sp)
	sw	$a0	8($sp)
	sw	$a1	4($sp)
	sw	$ra	0($sp)
#Body:
	la	$a0	TableWidth
	li	$v0	4
	syscall
	lw	$a0	8($sp)
	jal	PrintInt
	la	$a0	StoredAt
	li	$v0	4
	syscall
	lw	$a0	4($sp)
	jal	PrintInt

	lw	$a0	8($sp)
	lw	$a1	4($sp)

	li	$s0	4
	mul	$s2	$a0	$s0 #$a0: Bytes needed to store the table
	li	$s1	0 #s1: offset
	__Loop_PrintTable:
		bge	$s1	$s2	Fin__Loop_PrintTable
		lw	$a1	4($sp)
		add	$t0	$a1	$s1	#Adress of the first int of the table + offset
		lw	$a0	0($t0)
		jal	PrintInt
		addi	$s1	$s1	4	#increment	offset
		j __Loop_PrintTable
Fin__Loop_PrintTable:
	la	$a0	RetChar
	li	$v0	4
	syscall
#Epilogue:
	lw	$s0	20($sp)
	lw	$s1	16($sp)
	lw	$s2	12($sp)
	lw	$a0	8($sp)
	lw	$a1	4($sp)
	lw	$ra	0($sp)
	addu	$sp	$sp	24
	jr	$ra

# Function PrintInt
# Parameters: $a0: Int to print
# Pre-conditions:
# Returns:
PrintInt:
#Prologue:
	subu	$sp	$sp	8
	sw	$a0	4($sp)
	sw	$ra	0($sp)

#Body:
	li	$v0	1
	syscall

	la	$a0	RetChar
	li	$v0	4
	syscall

#Epilogue:
	lw	$a0	4($sp)
	lw	$ra	0($sp)
	addu	$sp	$sp	8
	jr	$ra

__JR:
	jr	$ra

exit:
	li	$v0	10
	syscall
