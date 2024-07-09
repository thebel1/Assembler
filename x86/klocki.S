	.intel_syntax	noprefix

	.global		main

	.equiv	NULL, 0
	.equiv	TRUE, 1
	.equiv	FALSE, 0

	.equiv	RET_OK, 0
	.equiv	RET_ERR, 1

# ASCII characters used for rendering game board. 
	.equiv	BORDER_TL, '+'
	.equiv	BORDER_TT, '-'
	.equiv	BORDER_TR, BORDER_TL
	.equiv	BORDER_LL, '|'
	.equiv	BORDER_RR, BORDER_LL
	.equiv	BORDER_BL, BORDER_TL
	.equiv	BORDER_BB, BORDER_TT
	.equiv	BORDER_BR, BORDER_BL
	.equiv	BORDER_GAP, ' '

	.equiv	BOARD_WIDTH, 4
	.equiv	BOARD_HEIGHT, 5
	.equiv	BOARD_SIZE, BOARD_WIDTH * BOARD_HEIGHT
	.equiv	BOARD_SIZE_MULT_W, 10 # resize board
	.equiv	BOARD_SIZE_MULT_H, 5

	.equiv	TILE_STATE_INVALID, -1
	.equiv	TILE_STATE_EMPTY, 1<<0
# Vertical tiles.
	.equiv	TILE_STATE_V1, 1<<1
	.equiv	TILE_STATE_V2, 1<<2
	.equiv	TILE_STATE_V3, 1<<3
	.equiv	TILE_STATE_V4, 1<<4
# Horizontal tiles.
	.equiv	TILE_STATE_HH, 1<<5
# Small tiles.
	.equiv	TILE_STATE_S1, 1<<6
	.equiv	TILE_STATE_S2, 1<<7
	.equiv	TILE_STATE_S3, 1<<8
	.equiv	TILE_STATE_S4, 1<<9
# Large tile.
	.equiv	TILE_STATE_LL, 1<<10

	.equiv	TILE_STATE_MIN, TILE_STATE_V1
	.equiv	TILE_STATE_MAX, TILE_STATE_LL
	.equiv	TILE_STATE_COUNT, 11

# There are 20 tiles, 18 of which are occupied at any time,
# yielding 19 states, which fits into a 4-byte integer.
# NOTE: TILE_STATE_SIZE must agree with the X PTR [] size below. 
	.equiv	TILE_STATE_SIZE, 4


# NOTE: must agree with cmd_fmt.
	.equiv	CMD_MAX_LEN, 10

	.equiv	CMD_NONE, 0
	.equiv	CMD_RIGHT, 1
	.equiv	CMD_LEFT, -1
	.equiv	CMD_UP,   -BOARD_WIDTH
	.equiv	CMD_DOWN, +BOARD_WIDTH

	.equiv	BLOCK_INVALID_POS, -1

	.text

# Print a character n times.
#
# void printnchar(char ch, unsigned n)
printnchar:
	push	r12
	push	r13
	mov	r12, rdi
	mov	r13, rsi
printnchar_loop:
	test	r13, r13
	je	printnchar_out
	lea	rdi, [rip + char_fmt]
	mov	rsi, r12
	xor	eax, eax
	call	printf
	dec	r13
	jmp	printnchar_loop
printnchar_out:
	pop	r13
	pop	r12
	ret

# void print_newline(void)
print_newline:
	lea	rdi, [rip + char_fmt]
	mov	rsi, 0xa # newline
	xor	eax, eax
	call	printf
	ret

# void print_hborder(bool top)
print_hborder:
	test	edi, edi
	je	print_hborder_bottom
	lea	rdi, [rip + char_fmt]
	mov	rsi, BORDER_TL # left corner
	xor	eax, eax
	call	printf
	mov	rdi, BORDER_TT # border
	lea	rsi, [BOARD_WIDTH * BOARD_SIZE_MULT_W]
	call	printnchar
	lea	rdi, [rip + char_fmt]
	mov	rsi, BORDER_TR # right corner
	xor	eax, eax
	call	printf
	call	print_newline
print_hborder_out:
	ret
print_hborder_bottom:
# We print a gap in the bottom border. 
	lea	rdi, [rip + char_fmt]
	mov	rsi, BORDER_BL # left corner
	xor	eax, eax
	call	printf
	mov	rdi, BORDER_BB # border
	lea	rsi,  [BOARD_SIZE_MULT_W - 1]
	call	printnchar
	lea	rdi, [rip + char_fmt]
	mov	rsi, BORDER_BR # right corner
	xor	eax, eax
	call	printf
	mov	rdi, BORDER_GAP # gap
	lea	rsi,  [BOARD_SIZE_MULT_W * 2]
	call	printnchar
	lea	rdi, [rip + char_fmt]
	mov	rsi, BORDER_BL # left corner
	xor	eax, eax
	call	printf
	lea	rdi, [rip + char_fmt]
	mov	rdi, BORDER_BB # border
	lea	rsi,  [BOARD_SIZE_MULT_W - 1]
	call	printnchar
	lea	rdi, [rip + char_fmt]
	mov	rsi, BORDER_BR # right corner
	xor	eax, eax
	call	printf
	call	print_newline
	jmp	print_hborder_out

# unsigned get_bit_shift(uint64_t num)
get_bit_shift:
	.set	NUM_BITS_MAX, 64
	test	rdi, rdi
	je	get_bit_shift_out1
	xor	eax, eax
get_bit_shift_loop:
	mov	rdx, 1
	mov	ecx, eax
	shl	rdx, cl
	and	rdx, rdi
	test	rdx, rdx
	jne	get_bit_shift_out2
	cmp	eax, NUM_BITS_MAX
	jge	get_bit_shift_out2
	inc	eax
	jmp	get_bit_shift_loop
get_bit_shift_out1:
	xor	eax, eax
get_bit_shift_out2:
	ret

# uint32_t get_tile_state(void *board_state, unsigned row, unsigned col)
get_tile_state:
	mov	r8d, edx
	mov	eax, esi
	imul	eax, BOARD_WIDTH
	add	eax, r8d
	mov	eax, [rdi + rax * TILE_STATE_SIZE]
	ret

# char get_tile_num(unsigned tile)
get_tile_num:
	ret

# char get_tile_sym(int num)
get_tile_sym:
	.set	ASCII_SPACE, 0x20
	.set	ASCII_NUM_START, 48
	cmp	edi, TILE_STATE_EMPTY
	je	get_tile_sym_out1
	call	get_bit_shift
	dec	eax
	lea	rax, [eax + ASCII_NUM_START]
	ret
get_tile_sym_out1:
	mov	eax, ASCII_SPACE
	ret

# void print_board_tile(void *board_state, unsigned row, unsigned col)
print_board_tile:
	test	rdi, rdi
	je	print_board_tile_fail
	cmp	edx, BOARD_HEIGHT
	jge	print_board_tile_fail
	cmp	ecx, BOARD_WIDTH
	jge	print_board_tile_fail
	push	rbx
	push	r12
	push	r13
	mov	rbx, rdi
	mov	r12d, esi
	mov	r13d, edx
	mov	esi, r12d
	mov	edx, r13d
	call	get_tile_state
	cmp	eax, TILE_STATE_MAX
	jg	print_board_tile_fail
	mov	edi, eax
	call	get_tile_sym
	mov	edi, eax
	mov	esi, BOARD_SIZE_MULT_W
	call	printnchar
	pop	r13
	pop	r12
	pop	rbx
	ret
print_board_tile_fail:
	ud2

# void print_board_row(void *board_state, unsigned row)
print_board_row:
	cmp	esi, BOARD_HEIGHT
	jge	print_board_row_fail
	push	rbx
	push	r12
	push	r13
	mov	rbx, rdi
	mov	r12d, esi
	lea	rdi, [rip + char_fmt]
	mov	esi, BORDER_LL
	xor	eax, eax
	call	printf
	xor	r13d, r13d
print_board_row_loop:
	cmp	r13d, BOARD_WIDTH
	jge	print_board_row_out
	mov	rdi, rbx
	mov	esi, r12d
	mov	edx, r13d
	call	print_board_tile
	inc	r13d
	jmp	print_board_row_loop
print_board_row_out:
	lea	rdi, [rip + char_fmt]
	mov	esi, BORDER_RR
	xor	eax, eax
	call	printf
	call	print_newline
	pop	r13
	pop	r12
	pop	rbx
	ret
print_board_row_fail:
	ud2

# void print_board(void *board_state)
print_board:
	push	rbx
	push	r12
	push	r13
	mov	rbx, rdi
	xor	r12d, r12d
	mov	edi, 1
	call	print_hborder
print_board_loop1:
	cmp	r12, BOARD_HEIGHT
	jge	print_board_out
	xor	r13d, r13d
print_board_loop2:
	cmp	r13, BOARD_SIZE_MULT_H
	jge	print_board_skip
	mov	rdi, rbx
	mov	esi, r12d
	call	print_board_row
	inc	r13d
	jmp	print_board_loop2
print_board_skip:
	inc	r12d
	jmp	print_board_loop1
print_board_out:
	mov	edi, 0
	call	print_hborder
	pop	r13
	pop 	r12
	pop	rbx
	ret

# void print_cmdline(void)
print_cmdline:
	lea	rdi, [rip + cmdline]
	xor	eax, eax
	call	printf
	ret

# void alloc_command(unsigned len, char **cmd, int *block)
alloc_command:
	.set	SIZEOF_INT, 4
	push	rbx
	push	rbp
	mov	rbx, rsi
	mov	rbp, rdx
	call	malloc
	test	rax, rax
	je	alloc_command_fail1
	mov	QWORD PTR [rbx], rax
	mov	rdi, SIZEOF_INT
	call	malloc # do we really need malloc for the int?
	test	rax, rax
	je	alloc_command_fail2
	mov	QWORD PTR [rbp], rax
	pop	rbp
	pop	rbx
	ret
alloc_command_fail2:
	mov	rdi, rbx
	call	free
alloc_command_fail1:
	ud2

# void free_command(char *command, int *block)
free_command:
	push	rbx
	mov	rbx, rsi
	call	free
	mov	rdi, rbx
	call	free
	pop	rbx
	ret

# bool get_command(char *command, int *block)
get_command:
	test	rdi, rdi
	je	get_command_fail
	test	rsi, rsi
	je	get_command_fail
	push	rbx
	push	rbp
	mov	rbx, rdi
	mov	rbp, rsi
	lea	rdi, [rip + cmd_fmt]
	mov	rsi, rbx
	mov	rdx, rbp
	xor	eax, eax
	call	scanf
	cmp	eax, 2
	jne	get_command_fail
	mov	eax, TRUE
get_command_out:
	pop	rbp
	pop	rbx
	ret
get_command_fail:
	mov	eax, FALSE
	jmp	get_command_out

# int check_command(char *command)
check_command:
	push	rbx
	mov	rbx, rdi
	lea	rsi, [rip + cmd_right]
	call	strcmp
	test	eax, eax
	jne	check_command_skip1
	mov	eax, CMD_RIGHT
	pop	rbx
	ret
check_command_skip1:
	mov	rdi, rbx
	lea	rsi, [rip + cmd_left]
	call	strcmp
	test	eax, eax
	jne	check_command_skip2
	mov	eax, CMD_LEFT
	pop	rbx
	ret
check_command_skip2:
	mov	rdi, rbx
	lea	rsi, [rip + cmd_up]
	call	strcmp
	test	eax, eax
	jne	check_command_skip3
	mov	eax, CMD_UP
	pop	rbx
	ret
check_command_skip3:
	mov	rdi, rbx
	lea	rsi, [rip + cmd_down]
	call	strcmp
	test	eax, eax
	jne	check_command_skip4
	mov	eax, CMD_DOWN
	pop	rbx
	ret
check_command_skip4:
	mov	eax, CMD_NONE
	pop	rbx
	ret

# Converts tile number to state.
#
# int get_tile_state_from_num(unsigned val)
get_tile_state_from_num:
	inc	edi
	mov	ecx, edi
	mov	eax, 1
	shl	eax, cl
	ret

# Checks whether a block is valid. Used for checking user input.
#
# bool check_block(int block)
check_block:
	cmp	edi, TILE_STATE_MIN
	jl	check_block_fail
	cmp	edi, TILE_STATE_MAX
	jg	check_block_fail
	mov	eax, TRUE
	ret
check_block_fail:
	mov	eax, FALSE
	ret

# Attempt to find the next block of a particular type, starting from a
# given location.
#
# int get_next_block(void *board_state, int block, int prev)
get_next_block:
        test    rdi, rdi
        je      get_next_block_fail
        cmp     edx, -1
        jl      get_next_block_fail
        mov     ecx, edx
        inc     edx
        cmp     edx, BOARD_SIZE
        jge     get_next_block_out1
        mov     eax, edx
        lea     rdi, [rdi + TILE_STATE_SIZE * rdx]
get_next_block_loop:
        cmp     DWORD PTR [rdi], esi
        cmove   ecx, eax
        je      get_next_block_out2
        add     rdi, TILE_STATE_SIZE
        inc     eax
        cmp     eax, BOARD_SIZE
        jge     get_next_block_out1
        jmp     get_next_block_loop
get_next_block_out1:
        # We've run to the end of the board without finding the block.
        mov     eax, BLOCK_INVALID_POS
        ret
get_next_block_out2:
        # We've found the block.
        mov     eax, ecx
        ret
get_next_block_fail:
        ud2

# int get_block_at(void *board_state, int idx)
get_block_at:
	test	rdi, rdi
	je	get_block_at_fail1
	cmp	esi, BOARD_SIZE
	jge	get_block_at_fail2
	mov	eax, DWORD PTR [rdi + TILE_STATE_SIZE * rsi]
	ret
get_block_at_fail1:
	ud2
get_block_at_fail2:
	mov	eax, TILE_STATE_INVALID
	ret

# Checks whether the move is legal, i.e. whether the taget tile is empty or
# contains a copy of the same block. Proceeds to move the block if the move
# is lega.
#
# bool perform_move(void *board_state, int cmd, int block)
perform_move:
	.set	MOVE_SLOT_COUNT, 4 # largest block (4 tiles)
	.set	MOVE_SLOT_SIZE, 4
	push	rbx
	push	rbp
	push	r12
	push	r13
	push	r14
	push	r15
	lea	r15, [2 * MOVE_SLOT_COUNT * MOVE_SLOT_SIZE] # {src[], dst[]}
	sub	rsp, r15
	mov	rbx, rdi
	mov	rbp, -1
	movsxd	rax, esi
	mov	r12, rax
	mov	r13d, edx
	mov	r14d, TRUE
	mov	rdi, rsp
	mov	esi, NULL
	mov	edx, r15d
	call	memset
	xor	r15d, r15d
perform_move_loop:
	mov	rdi, rbx
	mov	esi, r13d
	mov	edx, ebp
	call	get_next_block
	cmp	eax, BLOCK_INVALID_POS
	je	perform_move_do
	mov	ebp, eax
	cmp	r12, CMD_RIGHT
	je	perform_move_right
	cmp	r12, CMD_LEFT
	je	perform_move_left
perform_move_generic:
	mov	rdi, rbx
	lea	rsi, [rbp + r12]
	call	get_block_at
	cmp	eax, TILE_STATE_INVALID
	je	perform_move_fail
	mov	edx, TILE_STATE_EMPTY
	or	edx, r13d
	and	eax, edx
	cmp	eax, 0
	mov	ecx, FALSE
	mov	r14d, TRUE
	cmove	r14d, ecx
	je	perform_move_out
	jmp	perform_move_push
perform_move_out:
	mov	eax, r14d
	jmp	perform_move_ret
perform_move_fail:
	mov	eax, FALSE
perform_move_ret:
	lea	rax, [2 * MOVE_SLOT_COUNT * MOVE_SLOT_SIZE]
	add	rsp, rax
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	rbp
	pop	rbx
	ret
perform_move_right:
perform_move_left:
# Make sure we end up on the same row, since wrapping arround is not allowed.
	mov	r8d, ebp
	mov	eax, r8d
	xor	edx, edx
	mov	ecx, BOARD_WIDTH
	div	ecx
	mov	r9d, eax
	lea	rax, [r8 + r12]
	cdqe
	xor	edx, edx
	div	ecx
	cmp	eax, r9d
	je	perform_move_generic
	jmp	perform_move_fail
perform_move_push:
# Push move onto move stacks
	lea	rcx, [rsp + r15 * MOVE_SLOT_SIZE]
	mov	DWORD PTR [rcx], ebp
	lea	rax, [rbp + r12]
	lea	rcx, [r15 + MOVE_SLOT_COUNT]
	lea	rcx, [rsp + rcx * MOVE_SLOT_SIZE]
	mov	DWORD PTR [rcx], eax
	inc	r15d
	jmp	perform_move_loop
perform_move_do:
# Perform the tile swap. We can clobber whatever regs we want since we're
# returning at the end.
	.set	POP_FD, 1 # pop the move stack in a direction that avoids
			  # clobbering tiles
	.set	POP_BK, -1
	test	r15d, r15d
	je	perform_move_out
	mov	r13d, r15d
	cmp	r12d, CMD_NONE
	mov	rax, POP_FD
	cmovl	r14, rax
	mov	rax, POP_BK
	cmovg	r14, rax
	mov	rax, -1 # So the index starts from 0
	cmovl	r15, rax
	add	r15, r14
	mov	r8d, DWORD PTR [rsp + r15 * MOVE_SLOT_SIZE]
	mov	r9d, DWORD PTR [rbx + r8 * TILE_STATE_SIZE]
	mov	r11d, TILE_STATE_EMPTY
perform_move_do_loop:
	mov	r8d, DWORD PTR [rsp + r15 * MOVE_SLOT_SIZE]
	lea	rax, [rbx + r8 * TILE_STATE_SIZE]
	mov	edx, DWORD PTR [rax]
	mov	DWORD PTR [rax], r11d
	lea	rax, [r15 + MOVE_SLOT_COUNT]
	mov	r10d, DWORD PTR [rsp + rax * MOVE_SLOT_SIZE]
	mov	DWORD PTR [rbx + r10 * TILE_STATE_SIZE], r9d
	add	r15, r14
	cmp	r15d, 0
	jl	perform_move_out
	cmp	r15d, r13d
	jge	perform_move_out
	jmp	perform_move_do_loop

# bool run_command(void *board_state, char *command, int block)
run_command:
	test	rdi, rdi
	je	run_command_fail
	test	rsi, rsi
	je	run_command_fail
	push	rbx
	push	rbp
	push	r12
	push	r13
	mov	rbx, rdi
	mov	r12d, edx
	mov	rdi, rsi
	call	check_command
	cmp	eax, CMD_NONE
	je	run_command_fail
	mov	r13d, eax
	mov	edi, r12d
	call	check_block
	test	eax, eax
	je	run_command_fail
	mov	rdi, rbx
	mov	esi, r13d
	mov	edx, r12d
	call	perform_move
	cmp	eax, FALSE
	je	run_command_out
	mov	eax, TRUE
run_command_out:
	pop	r13
	pop	r12
	pop	rbp
	pop	rbx
	ret
run_command_fail:
	mov	eax, FALSE
	jmp	run_command_out

# void print_command(void *command, int *block)
print_command:
	test	rdi, rdi
	je	print_command_fail
	test	rsi, rsi
	je	print_command_fail
	mov	edx, DWORD PTR [rsi]
	mov	rsi, rdi
	lea	rdi, [rip + cmd_fmt]
	xor	eax, eax
	call	printf
	call	print_newline
	ret
print_command_fail:
	ud2

# Initializes the game board.
#
# unsigned init_board(void)
init_board:
	push	rbx
# Allocate space for game board.
	lea	rdi, [BOARD_SIZE * TILE_STATE_SIZE]
	call	malloc
	test	rax, rax
	je	init_board_fail1
	mov	rbx, rax
# Place tiles on game board.
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	0], 	TILE_STATE_V1
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	1], 	TILE_STATE_LL
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	2], 	TILE_STATE_LL
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	3], 	TILE_STATE_V2
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	4], 	TILE_STATE_V1
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	5], 	TILE_STATE_LL
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	6], 	TILE_STATE_LL
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	7], 	TILE_STATE_V2
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	8], 	TILE_STATE_V3
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	9], 	TILE_STATE_HH
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	10], 	TILE_STATE_HH
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	11], 	TILE_STATE_V4
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	12], 	TILE_STATE_V3
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	13], 	TILE_STATE_S2
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	14], 	TILE_STATE_S3
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	15], 	TILE_STATE_V4
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	16], 	TILE_STATE_S1
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	17], 	TILE_STATE_EMPTY
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	18], 	TILE_STATE_EMPTY
	mov	DWORD PTR [rbx + TILE_STATE_SIZE *	19], 	TILE_STATE_S4
	mov	QWORD PTR [rip + board_state], rbx
	mov	eax, RET_OK
	pop	rbx
	ret
init_board_fail2:
	mov	rdi, rbp
	call	free
init_board_fail1:
	mov	rdi, rbx
	call	free
	mov	eax, RET_ERR
	pop	rbp
	pop	rbx
	ret

# void cleanup_board(void)
cleanup_board:
	mov	rdi, QWORD PTR [rip + board_state]
	call	free
	ret

# The player has won when the large block is at the bottom center of the board.
#
# bool check_win(void *board_state)
check_win:
	.set	LL_TL_POS, 13
	.set	LL_TR_POS, 14
	.set	LL_BL_POS, 17
	.set	LL_BR_POS, 18
	lea	rax, [rdi + LL_TL_POS * TILE_STATE_SIZE]
	mov	eax, DWORD PTR [rax]
	cmp	eax, TILE_STATE_LL
	jne	check_win_fail
	lea	rax, [rdi + LL_TR_POS * TILE_STATE_SIZE]
	mov	eax, DWORD PTR [rax]
	cmp	eax, TILE_STATE_LL
	jne	check_win_fail
	lea	rax, [rdi + LL_BL_POS * TILE_STATE_SIZE]
	mov	eax, DWORD PTR [rax]
	cmp	eax, TILE_STATE_LL
	jne	check_win_fail
	lea	rax, [rdi + LL_BR_POS * TILE_STATE_SIZE]
	mov	eax, DWORD PTR [rax]
	cmp	eax, TILE_STATE_LL
	jne	check_win_fail
	mov	eax, TRUE
	ret
check_win_fail:
	mov	eax, FALSE
	ret

# void clear_screen(void)
clear_screen:
	lea	rdi, [rip + clr_scrn]
	xor	eax, eax
	call	printf
	ret

# int main()
main:
	push	r12
	sub	rsp, 0x18
	mov	QWORD PTR [rsp], NULL
	mov	QWORD PTR [rsp + 0x8], NULL
	lea	rdi, [rip + greeting]
	xor	eax, eax
	call	printf
	call	init_board
	cmp	eax, RET_OK
	jne	main_init_fail
	mov	rdi, CMD_MAX_LEN
	lea	rsi, [rsp]
	lea	rdx, [rsp + 0x8]
	call	alloc_command
	cmp	QWORD PTR [rsp], NULL
	je	main_alloc_fail
	cmp	QWORD PTR [rsp + 0x8], NULL
	je	main_alloc_fail
	xor	r12d, r12d
main_loop:
	call	clear_screen
	mov	rdi, QWORD PTR [rip + board_state]
	call	print_board
	mov	rdi, QWORD PTR [rip + board_state]
	call	check_win
	test	eax, eax
	jne	main_cmd_win
	call	print_cmdline
	mov	rdi, QWORD PTR [rsp]
	mov	rsi, QWORD PTR [rsp + 0x8]
	call	get_command
	test	eax, eax
	je	main_cmd_fail
	inc	r12d
	mov	rdi, QWORD PTR [rsp]
	mov	rsi, QWORD PTR [rsp + 0x8]
	call	print_command
	mov	rax, QWORD PTR [rsp + 0x8]
	mov	edi, DWORD PTR [rax]
	call	get_tile_state_from_num
	mov	rdi, QWORD PTR [rip + board_state]
	mov	rsi, QWORD PTR [rsp]
	mov	edx, eax
	call	run_command
	test	eax, eax
	je	main_cmd_fail
	jmp	main_loop
main_out:
	mov	rdi, QWORD PTR [rsp]
	mov	rsi, QWORD PTR [rsp + 0x8]
	call	free_command
	call	cleanup_board
	xor	eax, eax
	add	rsp, 0x18
	pop	r12
	ret
main_cmd_fail:
	lea	rdi, [rip + cmd_fail_msg]
	xor	eax, eax
	call	printf
	jmp	main_loop
main_alloc_fail:
	mov	rdi, QWORD PTR [rsp]
	mov	rsi, QWORD PTR [rsp + 0x8]
	call	free_command
	call	cleanup_board
main_init_fail:
	lea	rdi, [rip + init_fail_msg]
	call	printf
	mov	eax, 1
	add	rsp, 0x18
	pop	r12
	ret
main_cmd_win:
	lea	rdi, [rip + win_msg]
	mov	esi, r12d
	xor	eax, eax
	call	printf
	jmp	main_out

	.data

greeting:
	.asciz	"Welcome to Klocki!\n" \
		"Move the large block down and out of the box to win.\n"

init_fail_msg:
	.asciz	"Failed to initialize board!\n"

cmd_fail_msg:
	.asciz	"Invalid command!\n"

win_msg:
	.asciz	"You won in %d move(s)!\n"

char_fmt:
	.asciz	"%c"
num_fmt:
	.asciz	"%d"

cmdline:
	.asciz	"> "

cmd_fmt:
	.asciz	"%5s %1d"

cmd_right:
	.asciz	"right"
cmd_left:
	.asciz	"left"
cmd_up:
	.asciz	"up"
cmd_down:
	.asciz	"down"

clr_scrn:
	.asciz	"\033[2J"

# Pointer to the board state.
board_state:
	.quad	NULL
