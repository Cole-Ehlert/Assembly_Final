%include "/usr/local/share/csc314/asm_io.inc"

; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHAR '#'
%define PLAYER_CHAR 'O'

; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH  40

; the player starting position.
; top left is considered (0,0)
%define STARTX 10
%define STARTY 10

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'


segment .data

	; used to fopen() the board file defined above
	board_file			db BOARD_FILE,0

	; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; ANSI escape sequence to clear/refresh the screen
	clear_screen_code	db	27,"[2J",27,"[H",0

	; things the program will print
	help_str			db 13,10,"Controls: ", \
							UPCHAR,"=UP / ", \
							LEFTCHAR,"=LEFT / ", \
							DOWNCHAR,"=DOWN / ", \
							RIGHTCHAR,"=RIGHT / ", \
							EXITCHAR,"=EXIT", \
							13,10,10,0


segment .bss

	; this array stores the current rendered gameboard (HxW)
	board	resb	(HEIGHT * WIDTH)

	; these variables store the current player position
	xpos	resd	1
	ypos	resd	1

	; this array is a list to store the x and y positions for the snake on the board
	snake	resd	(HEIGHT * WIDTH * 2)

	; this variable will hold the current length of the snake
	snake_len resd 	1

	; these variables will store the direction of movement
	xmov	resd	1
	ymov	resd	1

segment .text

	global	asm_main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render

	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose

asm_main:
	push	ebp
	mov		ebp, esp

	; put the terminal in raw mode so the game works nicely
	call	raw_mode_on

	; read the game board file into the global variable
	call	init_board


	; initialize the head of the snake
	mov 	DWORD [snake], STARTX
	mov 	DWORD [snake+4], STARTY

	; initialize the other segments of the snake
	mov		DWORD [snake+8], (STARTX-1)
	mov 	DWORD [snake+12], STARTY

	mov 	DWORD [snake+16], (STARTX-2)
	mov 	DWORD [snake+20], STARTY

	mov 	DWORD [snake_len], 3

	; initialize the snake movement to the right
	mov		DWORD [xmov], 1
	mov		DWORD [ymov], 0



	; the game happens in this loop
	; the steps are...
	;   1. render (draw) the current board
	;   2. get a character from the user
	;	3. store current xpos,ypos in esi,edi
	;	4. update xpos,ypos based on character from user
	;	5. check what's in the buffer (board) at new xpos,ypos
	;	6. if it's a wall, reset xpos,ypos to saved esi,edi
	;	7. otherwise, just continue! (xpos,ypos are ok)
	game_loop:

		; draw the game board
		call	render

		; get an action from the user
		call	getchar

		; choose what to do
		cmp		eax, EXITCHAR
		je		game_loop_end
		cmp		eax, UPCHAR
		je 		move_up
		cmp		eax, LEFTCHAR
		je		move_left
		cmp		eax, DOWNCHAR
		je		move_down
		cmp		eax, RIGHTCHAR
		je		move_right
		jmp		input_end			; or just do nothing

		move_up:
			mov		DWORD [xmov], 0
			mov		DWORD [ymov], -1
			jmp		input_end
		move_left:
			mov		DWORD [xmov], -1
			mov		DWORD [ymov], 0
			jmp		input_end
		move_down:
			mov		DWORD [xmov], 0
			mov		DWORD [ymov], 1
			jmp		input_end
		move_right:
			mov		DWORD [xmov], 1
			mov		DWORD [ymov], 0
		input_end:
		call move_snake

		; (W * y) + x = pos

;;;;;;;;;;;;;; doesnt work with array need to rewrite with array in mind ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; compare the current position to the wall character
		mov		eax, WIDTH
		mul		DWORD [snake+4]
		add		eax, DWORD [snake]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		valid_move
			; opps, that was an invalid move, reset
		jmp game_loop_end
		valid_move:


	jmp		game_loop
	game_loop_end:

	; restore old terminal functionality
	call raw_mode_off

	mov		eax, 0
	mov		esp, ebp
	pop		ebp
	ret

raw_mode_on:

	push	ebp
	mov		ebp, esp

	push	raw_mode_on_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

raw_mode_off:

	push	ebp
	mov		ebp, esp

	push	raw_mode_off_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; this function will move the snake having the tail folling the head
move_snake:
	mov 	ecx, [snake_len]		; ecx is the loop index
	move_loop_start:
		cmp		ecx, 1
		je		move_loop_end

		dec 	ecx

		; move the x and y positions of each segment to the one in front of it
		mov		edx, DWORD [snake + ecx*8 - 8]
		mov 	DWORD [snake + ecx*8], edx
		mov		edx, DWORD [snake + ecx*8 -4]
		mov 	DWORD [snake + ecx*8 + 4], edx

		jmp 	move_loop_start

	move_loop_end:

	; add the direction of movement to the head segment
	mov 	eax, DWORD [snake]
	add 	eax, [xmov]
	mov 	DWORD [snake], eax
	mov 	eax, DWORD [snake+4]
	add 	eax, [ymov]
	mov 	DWORD [snake+4], eax

	ret

init_board:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	board_file
	call	fopen
	add		esp, 8
	mov		DWORD [ebp - 4], eax

	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp - 8], 0
	read_loop:
	cmp		DWORD [ebp - 8], HEIGHT
	je		read_loop_end

		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp - 8]
		lea		ebx, [board + eax]

		; read the bytes into the buffer
		push	DWORD [ebp - 4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp - 4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp - 8]
	jmp		read_loop
	read_loop_end:

	; close the open file handle
	push	DWORD [ebp - 4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

render:

	push	ebp
	mov		ebp, esp

	; two ints, for two loop counters
	; ebp-4, ebp-8
	sub		esp, 8

	; clear the screen
	push	clear_screen_code
	call	printf
	add		esp, 4

	; print the help information
	push	help_str
	call	printf
	add		esp, 4

	; outside loop by height
	; i.e. for(c=0; c<height; c++)
	mov		DWORD [ebp - 4], 0
	y_loop_start:
	cmp		DWORD [ebp - 4], HEIGHT
	je		y_loop_end

		; inside loop by width
		; i.e. for(c=0; c<width; c++)
		mov		DWORD [ebp - 8], 0
		x_loop_start:
		cmp		DWORD [ebp - 8], WIDTH
		je 		x_loop_end

			; check if (xpos,ypos)=(x,y) for every segment in snake array
			mov ecx, [snake_len]		; ecx will be the loop counter equal to snake length
			snake_loop_start:
				cmp 	ecx, 0							; if counter = 0 then jump to print_board
				jz 		print_board

				dec 	ecx								; decriment ecx

				mov 	ebx, DWORD [snake + ecx*8]
				cmp 	ebx, DWORD [ebp - 8]			; compare snake(xpos) and x
				jne 	snake_loop_start

				mov 	eax, DWORD [snake + ecx*8 + 4]
				cmp 	eax, DWORD [ebp - 4]			; compare snake(ypos) and y
				jne 	snake_loop_start

				; if both were equal, print the player
				push	PLAYER_CHAR
				call	putchar
				add		esp, 4
				jmp 	print_end


			print_board:
				; otherwise print whatever's in the buffer
				mov		eax, DWORD [ebp - 4]
				mov		ebx, WIDTH
				mul		ebx
				add		eax, DWORD [ebp - 8]
				mov		ebx, 0
				mov		bl, BYTE [board + eax]
				push	ebx
				call	putchar
				add		esp, 4
			print_end:

		inc		DWORD [ebp - 8]
		jmp		x_loop_start
		x_loop_end:

		; write a carriage return (necessary when in raw mode)
		push	0x0d
		call 	putchar
		add		esp, 4

		; write a newline
		push	0x0a
		call	putchar
		add		esp, 4

	inc		DWORD [ebp - 4]
	jmp		y_loop_start
	y_loop_end:

	mov		esp, ebp
	pop		ebp
	ret
