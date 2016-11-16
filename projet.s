.data
	str1: .asciiz "Hello World!"
.text
li $v0 4
la $a0 str1
syscall

