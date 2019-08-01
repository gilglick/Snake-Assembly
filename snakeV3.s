.data
	mapStartAddress: .space 4096
	headAddress: .space 4
	tailAddress: .space 4
.text

  ################################################################
 #			Main					#
################################################################
######		$s0 = color of snake			#######
######		$s1 = color of wall		       #######
######		$s2 = color of background	      #######
######		$s3 = color of Game Over	     #######
######		$s4 = current move	 	    #######
######		$s6 = food time counter		   #######
######		$s7 = random seed		  #######
######		$t9 = Boolean for managing tasks #######

main:		
		li $s0, 0x00FF0000			# define the color of the snake
		li $s1, 0x00708090			# define the color of the wall
		li $s2, 0x00FFFFFF			# define the color of the background
		li $s3, 0x00000000			# define the color of the background
		move $s4, $0				# reset current move
		li $s6, 10			 	# intialize food time counter
		li $t9, 0			 	# intialize task managment Boolean
		
		jal baseSquare				# arrange the map for start
		li $t0, 1				# set $t0 to '1'				
		sw $t0, 0xffff0000			# set the Receiver Control register to '1' ("wait for input")
		li $t0, 112				# set $t0 to 'p'
		sw $t0, 0xffff0004			# set the Receiver Data register to 'p'	("pause")
		j input
		
randomFoodTime:	li $a0, 1				# set $a0 to '1' (i.d. of random generator)
		lw $s7, tailAddress			# set the random seed to be the tail address
		move $a1, $s7				# put random seed in $a1
		li $v0, 40				# make the random seed in $a1, to be the seed of the generator in $a0 ('1')
		syscall
		
		li $a0, 1				# set $a0 to '1' (i.d. of random generator)
		li $a1, 40				# set $a1 to '20' (the upper bound for the random numbers)
		li $v0, 42				# generate a random number
		syscall
		move $s6, $a0				# set the food time counter to be the randomize number	
				 		 		 	 		 		 	 		 		 		 		 		 	 		 		 	 		 		 		 		 		 	 		 		 	 		 		 
input:		move $a3, $s4				# old move for readMoves procedure
		jal readMoves
		move $s4, $a3				# keep current move
		beq $a2, 1, endOfProgram		# if $a2 = 1 --> quit
		beq $a2, 2, main			# if $a2 = 2 --> reset
		beq $a2, 3, change			# if $a2 = 3 --> change
		beq $t9, 0, delay			# if management Boolean is true, go to delay
		beq $t9, 1, change			# if it is false, go to change (in the currenct direction)
		
delay:		li $a0, 50				# set $a0 to 50 nsec
		li $v0, 32				# generate delay in length specified
		syscall
		li $t9, 1				# set management Boolean to false
		j input					# continue in currenct move
						
change:		move $a0, $s0				# current color of the snake for updateMoves procedure
		move $a1, $s4				# current move for updateMoves procedure
		jal updateMoves			
		beq $a2, 1, gameOverBlock		# if $a2 = 1 --> game over
		move $s0, $a0				# update the color of the snake
		addi, $s6, $s6, -1			# food time counter --
		li $t9, 0				# set management Boolean to true
		ble $s6, $0, food			# if food time counter has reached zero, it's dinner time
		beq $a2, 0, input			# if $a2 = 0 --> continue the game (check for input)

food:		jal foodGenerator
		beq $a2, 1, noFood			# if the color generated was not good, go to noFood	
		j randomFoodTime			# if there was some food generated, get a new time counter for food
		
noFood:		addi $s6, $0, 1				# set the food time counter to 1, so we'll try to prepare some food next move
		j input
		
endOfProgram:	li $v0, 10
		syscall

  ################################################################
 #			Base Square				#
################################################################
######	temp:	$t1 = address pointer			#######
######		$t2 = counter for wall		       #######
######		$t3 = the end of the map 	      #######
######		$t5 = first line		     #######
######		$t6 = last line			    #######
######		$t7 = 31 decimal		   #######

baseSquare:		
		la $t1, mapStartAddress			# Start address of the map
		la $t3, headAddress			# the end of the map and start of the head
		move $t2, $0				# intialize wall counter
		move $t5, $t1				# first line start
		addi $t5, $t5, 124			# first line end
		addi $t6, $t5, 3836			# last line start
		addi $t7, $0, 31			# 31 decimal
		
baseSquareLoop:	ble $t1, $t5, wall			# first line ? wall!
		bgt $t1, $t6, wall			# last line ? wall!
		beq $t2, $0, wall			# start of a line? wall!
		beq $t2, $t7, wall			# end of a line? wall!
		
black:		sw $s2, ($t1)				# color the background
		addi $t1, $t1, 4			# map pointer ++
		addi $t2, $t2, 1			# wall counter ++
		j baseSquareLoop
			
wall:		sw $s1, ($t1)				# color the wall
		addi $t1, $t1, 4			# map pointer ++ 
		
		bne $t2, $t7, noReset			# if wall counter != 31 --> no reset
		addi $t2, $0, -1			# if it is, reset the wall counter
		
noReset:	addi $t2, $t2, 1			# wall counter ++
		bne $t1, $t3, baseSquareLoop		# if it is not the end of the map
		
		li $t1, 0x1001083c			# head address
		sw $s0, ($t1)				# color the head
		sw $t1, headAddress			# keep head address
		
		li $t1, 0x100108bc			# tail address
		li $t3, 0x01000000			# the next block is up
		add $t3, $t3, $s0 			# combine tail 
		sw $t3, ($t1)				# color the tail
		sw $t1, tailAddress			# keep tail address
		jr $ra
		
		
  ########################################################################
 #			Read Moves					#
########################################################################
######	temp:	$t0 = Receiver Control register			#######
######		$t1 = Receiver Data register	      	       #######
######		$t2 = address of the head	     	      #######
######	input:	$a3 = last move		           	     #######
######	output:	$a2 = if there was no change - 0     	    #######
######		      for quitting - 1		    	   #######
######		      for reset - 2		   	  #######
######		      if there was a change - 3   	 #######
######		$a3 = current move		        #######

readMoves:	
		move $a2, $0				# reset output	($a2)
		
		lw $t0, 0xffff0000			# read Receiver Control register
		bne $t0, 1, endOfReadMoves		# if there is no control input, end the procedure
		
pauseLoop:	lw $t1, 0xffff0004			# if there is a data input, load it to $t1
		beq $t1, 105, upReadMoves		# if we got "i" go up
		beq $t1, 107, downReadMoves		# if we got "k" go down
		beq $t1, 106, leftReadMoves		# if we got "j" go left
		beq $t1, 108, rightReadMoves		# if we got "l" go right
		beq $t1, 113, quitReadMoves		# if we got "q", quit
		beq $t1, 114, resetReadMoves		# if we got "r", reset the game
		beq $t1, 112, pauseSleep		# if we got "p", pause the game
		j endOfReadMoves			# for all other input end the procedure

pauseSleep:	li $a0, 100				# set $a0 to 100 nsec
		li $v0, 32				# generate delay in length specified
		syscall
		j pauseLoop				# check input again
		
upReadMoves:	beq $a3, 2, endOfReadMoves		# if the old move is down, end the procedure
		li $a3, 1				# store up as current move
		j updateReadMoves

downReadMoves:	beq $a3, 1, endOfReadMoves		# if the old move is up, end the procedure
		li $a3, 2				# store down as current move
		j updateReadMoves

leftReadMoves:	beq $a3, 4, endOfReadMoves		# if the old move is right, end the procedure
		li $a3, 3				# store left as current move
		j updateReadMoves
		
rightReadMoves:	beq $a3, 3, endOfReadMoves		# if the old move is left, end the procedure
		li $a3, 4				# store right as current move
		
updateReadMoves:addi $a2, $0, 3				# indicate that there was a change
		j endOfReadMoves

resetReadMoves:	addi $a2, $0, 2				# indicate "reset"
		j endOfReadMoves
		
quitReadMoves:	addi $a2, $0, 1				# indicate "quit"

endOfReadMoves:	jr $ra
		

  #######################################################################
 #			Update Moves				       #
#######################################################################
######	temp:	$t0 = previous color of new head	       #######
######		$t1 = address of the tail	       	      #######
######		$t2 = new head address	      	     	     #######
######		$t3 = color of tail		     	    #######
######		$t4 = direction to new head from old head  #######
######		$t5 = old head address	  		  #######
######		$t6 = color of old head	                 #######
######	input:	$a0 = old color of snake		#######
######		$a1 = current move		       #######
######	output:	$a0 = new color of snake	      #######
######		$a2 = if everything is allright - 0  #######
######		      if game over - 1		    #######


updateMoves:
		move $a2, $0				# reset output ($a2)
		
		lw $t5, headAddress			# read old address of the head
		
		beq $a1, 1, upUpdateMoves		# if the current move is up, update up
		beq $a1, 2, downUpdateMoves		# if the current move is down, update down
		beq $a1, 3, leftUpdateMoves		# if the current move is left, update left
		beq $a1, 4, rightUpdateMoves		# if the current move is right, update right
		j endUpdateMoves
		
upUpdateMoves:	add $t2, $t5, -128			# new address of head
		j updateUpdateMoves
		
downUpdateMoves:add $t2, $t5, 128			# new address of head
		j updateUpdateMoves
		
leftUpdateMoves:add $t2, $t5, -4			# new address of head
		j updateUpdateMoves
		
rightUpdateMoves:add $t2, $t5, 4			# new address of head
		
updateUpdateMoves:
		sw $t2, headAddress			# update address of head

		lw $t6, ($t5)				# load color of old address of head
		andi $t6, 0x00FFFFFF			# take only the color
		sll $t4, $a1, 24			# take the direction to the last 8 bits of a number
		add $t4, $t4, $t6			# connect it with the color of old snake head	
		sw $t4, ($t5)				# store the color + details in old head address
					
		
		lw $t1, tailAddress			# read address of the tail
		lw $t3, ($t1)				# color of tail
		
		lw $t0, ($t2)				# color of new address of head
		andi $t0, $t0, 0xFF000000		# take the last 8 bits to check if it is part of the body
		bne $t0, $0, gameOverUpdateMoves	# if we hit ourself, game over
		
		lw $t0, ($t2)				# color of new address of head
		beq $t0, $s2, justBackgroud		# is it a backgroud tile ?
		beq $t0, $s1, gameOverUpdateMoves	# if we hit a wall, game over
		
		sw $a0 ($t2)				# if it is a food pill, color the head
		move $a0, $t0				# save the new color of the snake
		j endUpdateMoves
		
justBackgroud:	sw $a0 ($t2)				# color the head			
		andi $t3, 0xFF000000			# take the last 2 bits of the tail to see the next block
		srl $t3, $t3, 24			# make it a number
		sw $s2, ($t1)				# color the tail (as a background)
		
		beq $t3, 1, upUpdateTail		# if the next block is up, go up
		beq $t3, 2, downUpdateTail		# if the next block is down, go down
		beq $t3, 3, leftUpdateTail		# if the next block is left, go left
		beq $t3, 4, rightUpdateTail		# if the next block is right, go right

upUpdateTail:	add $t1, $t1, -128			# get the new address of the tail
		j updateUpdateTail

downUpdateTail:add $t1, $t1, 128			# get the new address of the tail
		j updateUpdateTail
		
leftUpdateTail:add $t1, $t1, -4				# get the new address of the tail
		j updateUpdateTail
		
rightUpdateTail:add $t1, $t1, 4				# get the new address of the tail

updateUpdateTail:
		sw $t1, tailAddress			# update the address of the tail
		j endUpdateMoves
		
gameOverUpdateMoves:	
		li $a2, 1				# game over	
	
endUpdateMoves:	jr $ra

		
  #######################################################################
 #			Food Generator				       #
#######################################################################
######	temp:	$t0 = address for food pill		       #######
######		$t1 = address the start of the map            #######
######		$t2 = old color of address of food pill	     #######
######	output:	$a2 = if everything is allright - 0         #######
######		      if there is no food - 1		   #######

foodGenerator:
		move $a2, $0				# reset output ($a2)
	
		li $a0, 1				# load random generator number 1
		li $a1, 1024				# set upper bound to 1024
		li $v0, 42				# generate random number (1-1024)
		syscall
		
		sll $t0, $a0, 2				# multiply by 4 and save in $t0 (1-4096)				
		la $t1, mapStartAddress			# load the address of the start of the map
		add $t0, $t0, $t1			# connect it with the randomize number
		lw $t2, ($t0)				# check the content of the address
		beq $t2, $s2, putFoodGenerator		# if the content is a background, put some food
		addi $a2, $a2, 1			# if not, indicate that there is no food
		j endFoodGenerator
	
putFoodGenerator:
		li $a0, 1				# load random generator number 1			
		li $a1, 0x00FFFFFF			# set upper bound to 0x00FFFFFF (colors)
		li $v0, 42				# get a random color
		syscall
		
		beq $a0, $s0, putFoodGenerator		# if the color equals the snake color, try again
		beq $a0, $s1, putFoodGenerator		# if the color equals the walls, try again
		beq $a0, $s2, putFoodGenerator		# if the color equals the background, try again
		sw $a0, ($t0)				# put the food
		
endFoodGenerator:
		jr $ra



  ################################################################
 #			Game Over Block				#
################################################################
######	temp:	$t0 = loop counter 			#######
######		$t1 = address pointer	 	       #######
######		$t2 = color of current block	      #######
######		$t3 = Boolean for ending the loop    #######
######		$t4 = background color		    #######
######		$t5 = nested loop counter	   #######
######		$t6 = movement of current block	  #######
######		$t7 = space between blocks	 #######
gameOverBlock:
		move $t0, $0				# intialize loop counter
		move $t3, $0				# Boolean for ending = false
		move $t4, $s2				# load background color
		li $t7, 4				# space between blocks in first row is 4
		li $t6, 4				# movement in first row is right
		sll $t6, $t6, 24			# put movement in last 8 bits
		la $t1, mapStartAddress			# intialize address pointer
		addi $t1, $t1, 1160			# intialize address pointer
		li $a0, 1				# load random generator number 1			
		li $a1, 0x00FFFFFF			# set upper bound to 0x00FFFFFF (colors)
		li $v0, 42				# get a random int
fullLineLoop:	
		syscall					# get a random color
		move $t2, $a0				# move the random color into temp ($t2)
		add $t2, $t2, $t6			# connect it with the movement
		sw $t2, ($t1)				# store the block in current address
		add $t0, $t0, 1				# loop counter ++
		add $t1, $t1, $t7			# take the next address
		bne $t0, 27, fullLineLoop		# if we are not at the end of the row, do loop again
		
		subi $t6, $t6, 0x02000000		# subtract 2 from movement (to go from right to down and from left to up)
		syscall					# generate a random color
		move $t2, $a0				# put the random color in temp ($t2)
		add $t2, $t2, $t6			# connect it with the movement
		sw $t2, ($t1)				# store the block in current address
		
		beq $t3, 1, writeGameOver		# if Boolean for ending is true, end the procedure 
		
		addi $t6, $0, 1				# define movement as up
		sll $t6, $t6, 24			# put movement in last 8 bits
		addi $t1, $t1, 20			# go to next address
		move $t0, $0				# reset loop counter			
		
notFullLoop:	syscall					# get a random color
		move $t2, $a0				# move the random color into temp ($t2)
		add $t2, $t2, $t6			# connect it with the movement
		sw $t2, ($t1)				# store the block in current address
		move $t5, $0				# intialize nested loop counter
			
backgroundLoop:
		addi $t5, $t5, 1			# nested loop counter ++
		addi $t1, $t1, 4			# next address
		sw $t4, ($t1)				# put background color in current address	
		bne $t5, 27, backgroundLoop		# if we are not at the end of the row, do loop again
		
		addi $t6, $0, 2				# define movement as down
		sll $t6, $t6, 24			# put movement in last 8 bits
		syscall					# get a random color			
		move $t2, $a0				# move the random color into temp ($t2)
		add $t2, $t2, $t6			# connect it with the movement
		sw $t2, ($t1)				# store the block in current address
		
		addi $t1, $t1, 20			# go to next address
		addi $t0, $t0, 1			# loop counter ++
		addi $t6, $0, 1				# define movement as up 		
		sll $t6, $t6, 24			# put movement in last 8 bits		
		bne $t0, 13, notFullLoop		# if we are not at the last row, do loop again
		
		addi $t1, $t1, 108			# if we are at the last row, go to last bit
		addi $t6, $0, 3				# define movement as left
		sll $t6, $t6, 24			# put movement in last 8 bits
		move $t0, $0				# reset loop counter
		li $t7, -4				# space between blocks in last row is -4 
		addi $t3, $t3, 1			# set Boolean for ending as true
		j fullLineLoop

		
  ################################################################
 #			Write Game Over				#
################################################################
######	temp:	$t1 = address pointer			#######
######		$t2 = color of "Game Over"             #######

writeGameOver:
		la $t1, mapStartAddress			# intialize the address pointer
		move $t2, $s3				# load the color of "Game Over"
		
writeGameLine1:	
		# G
		addi $t1, $t1, 1424
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# A
		addi $t1, $t1, 16
		sw $t2, ($t1)
		
		# M
		addi $t1, $t1, 24
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 16
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
writeGameLine2:	
		# G
		addi $t1, $t1, 40
		sw $t2, ($t1)
		
		# A
		addi $t1, $t1, 24
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# M
		addi $t1, $t1, 16
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
writeGameLine3:	
		# G
		addi $t1, $t1, 52
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# A
		addi $t1, $t1, 12
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# M
		addi $t1, $t1, 16
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 12
		sw $t2, ($t1)	
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
writeGameLine4:
		# G	
		addi $t1, $t1, 40
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
		# A
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# M
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
writeGameLine5:	
		# G
		addi $t1, $t1, 52
		sw $t2, ($t1)
		addi $t1, $t1, 4		
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# A
		addi $t1, $t1, 8		
		sw $t2, ($t1)
		addi $t1, $t1, 16
		sw $t2, ($t1)
		
		# M
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 24
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 4		
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
WriteOverLine1:
		# O
		addi $t1, $t1, 176
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
	
		# V
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 16
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# R
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
writeOverLine2:	
		# O
		addi $t1, $t1, 56
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
		# V
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 16
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# R
		addi $t1, $t1, 20
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
writeOverLine3:	
		# O
		addi $t1, $t1, 52
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
		# V
		addi $t1, $t1, 12
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 12
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# R
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
writeOverLine4:	
		# O
		addi $t1, $t1, 56
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
		# V
		addi $t1, $t1, 12
		sw $t2, ($t1)
		addi $t1, $t1, 8
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 12
		sw $t2, ($t1)	
		
		# R	
		addi $t1, $t1, 20
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)
		
writeOverLine5:	
		# O
		addi $t1, $t1, 52
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# V
		addi $t1, $t1, 16
		sw $t2, ($t1)
		
		# E
		addi $t1, $t1, 16
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		addi $t1, $t1, 4
		sw $t2, ($t1)
		
		# R
		addi $t1, $t1, 8
		sw $t2, ($t1)
		addi $t1, $t1, 12
		sw $t2, ($t1)

	 	# j endOfProgram

  ########################################################################
 #			Game Over Move					#
########################################################################
######	temp:	$t1 = address pointer  				#######
######		$t2 = color and movement of current block      #######
######		$t3 = only color of current block	      #######
######		$t4 = only movement of current block	     #######
######		$t4 = only movement of current block	    #######


gameOverMove:				
		la $t1, mapStartAddress			# intiallize address pointer		
		addi $t1, $t1, 1160			# intiallize address pointer
		lw $t2, ($t1)				# load the first block
		andi $t3, $t2, 0x00FFFFFF		# take only the color
		andi $t4, $t2, 0xFF000000		# take only the movement
		syscall					# randomize a color
		add $t2, $a0, $t4			# connect the movement and the new color
		sw $t2, ($t1)				# store the them in the current address
		srl $t4, $t4, 24			# make the movement a number
		
gameOverMoveLoop:							
		beq $t4, 4, gameOverMoveRight		# if it is right, move right	
		beq $t4, 2, gameOverMoveDown		# if it is down, move down
		beq $t4, 3, gameOverMoveLeft		# if it is left, move left
		beq $t4, 1, gameOverMoveUp		# if it is up, move up
		
gameOverMoveRight:
		addi $t1, $t1, 4			# move the address right
		j gameOverMoveColor
		
gameOverMoveDown:
		addi $t1, $t1, 128			# move the address down
		j gameOverMoveColor
		
gameOverMoveLeft:
		addi $t1, $t1, -4			# move the address left		
		j gameOverMoveColor
		
gameOverMoveUp:
		addi $t1, $t1, -128		 	# move the address up
		
gameOverMoveColor:
		lw $t2, ($t1)				# load the new block
		andi $t4, $t2, 0xFF000000		# take only the movement and put in temp ($t4)	
		add $t3, $t3, $t4			# connect it with the color of the previous block
		sw $t3, ($t1)				# stroe it in the current block
		srl $t4, $t4, 24			# make the movement a number
		andi $t3, $t2, 0x00FFFFFF		# put the color of the current block in temp ($t3)
	
		j gameOverMoveLoop

