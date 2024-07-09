	.global	_start

	.equiv	NULL, 0

	.equiv	TRUE, 1
	.equiv	FALSE, 0

	.equiv	BOX_WIDTH, 50
	.equiv	BOX_HEIGHT, 50
	.equiv	CANVAS_MULT_W, 2
	.equiv	CANVAS_MULT_H, 1
	.equiv	CANVAS_WIDTH, BOX_WIDTH*CANVAS_MULT_W
	.equiv	CANVAS_HEIGHT, BOX_HEIGHT*CANVAS_MULT_H

	.equiv	NUM_PARTICLES, 1000

	.equiv	EMITTER_WIDTH, 10
	.equiv	EMITTER_X, 2
	.equiv	EMITTER_Y, 48 // avoid collisions

	.equiv	SIZEOF_FLOAT, 4
	.equiv	SIZEOF_INT, 4
	.equiv	SIZEOF_PARTICLE, SIZEOF_FLOAT*5 + SIZEOF_INT // (x, y, vx, vy, life, active)
	.equiv	INVALID_PARTICLE, -1

	.equiv	WALL_NONE,   0
	.equiv	WALL_TOP,    1<<0
	.equiv	WALL_LEFT,   1<<1
	.equiv	WALL_RIGHT,  1<<2
	.equiv	WALL_BOTTOM, 1<<3

	.equiv	SYM_CORNER, '+'
	.equiv	SYM_HORI, '-'
	.equiv	SYM_VERT, '|'
	.equiv	SYM_PARTICLE, 'O'
	.equiv	SYM_EMPTY, ' '

	.equiv	SVC_WRITE, 64 // write() syscall

	.equiv	RENDER_DELAY, 1000

	.text

// Calls a CB for each particle.
//
// void apply_particles_all(void (*cb)(void *particle, float clock_tick))
apply_particles_all:
	sub	sp, sp, 48
	str	x30, [sp]
	stp	x19, x20, [sp, 8]
	stp	x21, x22, [sp, 24]
	str	x23, [sp, 40]
	adr	x19, particles
	ldr	x19, [x19]
	mov	x20, x0
	adr	x0, clock_tick
	ldr	w21, [x0]
	mov	w22, 0
	adr	x0, num_particles
	ldr	w23, [x0]
apply_particles_all_loop:
	ldr	w0, [x19, 20]
	mov	w1, FALSE
	cmp	w0, w1
	b.eq	apply_particles_all_continue // skip dead particles
	mov	x0, x19
	fmov	s0, w21
	blr	x20 // CB
apply_particles_all_continue:
	add	x19, x19, SIZEOF_PARTICLE
	add	w22, w22, 1
	cmp	w22, w23
	b.lt	apply_particles_all_loop
	ldr	x23, [sp, 40]
	ldp	x21, x22, [sp, 24]
	ldp	x19, x20, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 48
	ret

// Shout out to my boy Pythagoras.
//
// float calc_distance(float x1, float y1, float x2, float y2)
calc_distance:
	sub	sp, sp, 16
	str	x30, [sp]
	fsub	s0, s0, s2
	fsub	s1, s1, s3
	fmul	s0, s0, s0
	fmul	s1, s1, s1
	fadd	s0, s0, s1
	fsqrt	s0, s0
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Moves a particle based on its velocity.
//
// void move_particle(void *particle, float time_tick)
move_particle:
	sub	sp, sp, 16
	str	x30, [sp]
/* x_new = x + vx*clock_tick */
	ldr	s1, [x0] // x
	ldr	s2, [x0, 8] // vx
	fmul	s2, s2, s0
	fadd	s1, s1, s2
	str	s1, [x0]
/* y_new = ... */
	ldr	s1, [x0, 4] // y
	ldr	s2, [x0, 12] // vy
	fmul	s2, s2, s0
	fadd	s1, s1, s2
	str	s1, [x0, 4]
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Put particle back inside box.
//
// void return_particle_to_box(void *particle)
return_particle_to_box:
	sub	sp, sp, 16
	str	x30, [sp]
	fmov	s1, 1.0
	fsub	s1, s1, s1 // make zero
	adr	x1, particle_radius
	ldr	s2, [x1]
// x left
	ldr	s0, [x0]
	fsub	s0, s0, s2
	fmax	s0, s0, s2
	str	s0, [x0]
// y bottom
	ldr	s0, [x0, 4]
	fsub	s0, s0, s2
	fmax	s0, s0, s1
	str	s0, [x0, 4]
// x right
	mov	w1, BOX_WIDTH
	scvtf	s1, w1
	fsub	s3, s1, s2
	ldr	s0, [x0]
	fadd	s0, s0, s2
	fmin	s0, s0, s3
	str	s0, [x0]
// y top
	mov	w1, BOX_HEIGHT
	scvtf	s1, w1
	ldr	s0, [x0, 4] // y
	fadd	s0, s0, s2
	fmin	s0, s0, s1
	str	s0, [x0, 4]
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// We stop at the first colliding wall and assume there is only one. We might
// catch any other collisions on subsequent clock ticks.
//
// int get_colliding_wall(void *particle)
get_colliding_wall:
	sub	sp, sp, 16
	str	x30, [sp]
	ldr	s0, [x0] // x
	ldr	s1, [x0, 4] // y
	adr	x0, particle_radius
	ldr	s2, [x0]
	fmov	s3, 1.0
	fsub	s3, s3, s3 // make zero
	fsub	s4, s1, s2
	fcmp	s4, s3
	b.lt	get_colliding_wall_bottom
	mov	w0, BOX_HEIGHT
	scvtf	s5, w0
	fadd	s4, s1, s2
	fcmp	s4, s5
	b.gt	get_colliding_wall_top
	fsub	s4, s0, s2
	fcmp	s4, s3
	b.lt	get_colliding_wall_left
	mov	w0, BOX_WIDTH
	scvtf	s5, w0
	fadd	s4, s0, s2
	fcmp	s4, s5
	b.gt	get_colliding_wall_right
	mov	w0, WALL_NONE
get_colliding_wall_out:
	ldr	x30, [sp]
	add	sp, sp, 16
	ret
get_colliding_wall_bottom:
	mov	w0, WALL_BOTTOM
	b	get_colliding_wall_out
get_colliding_wall_top:
	mov	w0, WALL_TOP
	b	get_colliding_wall_out
get_colliding_wall_left:
	mov	w0, WALL_LEFT
	b	get_colliding_wall_out
get_colliding_wall_right:
	mov	w0, WALL_RIGHT
	b	get_colliding_wall_out

// Calculates the velocity change from colliding with a wall.
//
// void calc_wall_collision(int wall, void *particle)
calc_wall_collision:
	sub	sp, sp, 16
	str	x30, [sp]
	mov	w2, WALL_TOP
	mov	w3, WALL_BOTTOM
	orr	w2, w2, w3
	and	w2, w0, w2
	cmp	w2, 0
	mov	w2, 8
	mov	w3, 12
	csel	w0, w2, w3, EQ
	add	x2, x1, x0
/* Bounce */
	ldr	s0, [x2]
	fmov	s1, -1
	fmul	s0, s0, s1
	adr	x3, wall_attenuation
	ldr	s1, [x3]
	fmul	s0, s0, s1
	str	s0, [x2]
	mov	x0, x1
	bl	return_particle_to_box
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// We assume there is only ever one collision at a time.
//
// void *get_colliding_particle(void *particle)
get_colliding_particle:
	sub	sp, sp, 64
	str	x30, [sp]
	stp	x19, x20, [sp, 8]
	stp	x21, x22, [sp, 24]
	stp	x23, x24, [sp, 40]
	str	x24, [sp, 56]
	mov	x19, x0
	ldr	w23, [x19] // x
	ldr	w24, [x19, 4] // y
	adr	x0, num_particles
	ldr	w20, [x0]
	mov	w21, 0
	adr	x22, particles
	ldr	x22, [x22]
	adr	x0, particle_radius
	ldr	w25, [x0]
get_colliding_particle_loop:
	cmp	x22, x19 // same particle?
	b.eq	get_colliding_particle_skip
	fmov	s0, w23 // x1
	fmov	s1, w24 // y1
	ldr	s2, [x22] // x2
	ldr	s3, [x22, 4] // y2
	bl	calc_distance
	fmov	s1, w25
	fcmp	s0, s1
	b.gt	get_colliding_particle_skip
/* Collision has occurred. */
	mov	x0, x22
	b	get_colliding_particle_out
get_colliding_particle_skip:
	mov	x0, SIZEOF_PARTICLE
	add	x22, x22, x0
	add	w21, w21, 1
	cmp	w21, w20
	b.lt	get_colliding_particle_loop
	mov	x0, NULL // no collision
get_colliding_particle_out:
	ldr	x25, [sp, 56]
	ldp	x23, x24, [sp, 40]
	ldp	x21, x22, [sp, 24]
	ldp	x19, x20, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 64
	ret

// We assume that collisions always occur "head on". All we then do is apply the
// velocity attenuation coefficient to each particle and then swap the
// velocities between the two particles.
//
// void calc_particle_collision(void *particle1, void *particle2,
//                              float time_tick)
calc_particle_collision:
	sub	sp, sp, 32
	str	x30, [sp]
	stp	x19, x20, [sp, 8]
	str	x21, [sp, 24]
	fmov	w21, s0
	ldr	s0, [x0, 8] // vx1
	ldr	s1, [x0, 12] // vy1
	ldr	s2, [x1, 8] // vx2
	ldr	s3, [x1, 12] // vy2
	adr	x2, particle_attenuation
	ldr	s4, [x2]
/* Apply attenuation. */
	fmul	s0, s0, s4
	fmul	s1, s1, s4
	fmul	s2, s2, s4
	fmul	s3, s3, s4
/* Swap velocities. */
	str	s0, [x1, 8]
	str	s1, [x1, 12]
	str	s2, [x0, 8]
	str	s3, [x0, 12]
/*
 * Move particles away from one another. We do this to prevent the particles
 * from continuing to intersect, causing them to jitter in place as they keep
 * colliding with one another.
 *
 * We do this by continuing the particles' journeys until they are at least one
 * particle radius apart. This does not modify the simulation time.
 */
	mov	x19, x0
	mov	x20, x1
calc_particle_collision_loop:
	mov	x0, x19
	fmov	s0, w21
	bl	move_particle
	mov	x0, x20
	fmov	s0, w21
	bl	move_particle
	mov	x0, x19
	mov	x1, x20
	bl	calc_distance
	b.le	calc_particle_collision_loop
	mov	x0, x19
	bl	return_particle_to_box
	mov	x0, x20
	bl	return_particle_to_box
	ldr	x21, [sp, 24]
	ldp	x19, x20, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 32
	ret

// Mass can be ignored, because we assume all particles have the same mass.
//
// Caveat: if the (relative) velocity is high enough that the distance covered
// within one tick is greater than the diameter of a particle, then a collision
// will not register. To remedy this, clock_tick can be adjusted.
//
// void particle_collision_cb(void *particle, float clock_tick)
particle_collision_cb:
	sub	sp, sp, 32
	str	x30, [sp]
	stp	x19, x20, [sp, 8]
	mov	x19, x0
	fmov	w20, s0
	bl	get_colliding_wall
	cmp	w0, WALL_NONE
	b.eq	particle_collision_cb_skip
	mov	x1, x19
	bl	calc_wall_collision
particle_collision_cb_skip:
	mov	x0, x19
	bl	get_colliding_particle
	cmp	x0, NULL
	b.eq	particle_collision_cb_out
	mov	x1, x19
	fmov	s0, w20
	bl	calc_particle_collision
particle_collision_cb_out:
	ldp	x19, x20, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 32
	ret

// Applies gravity to the velocity of a particle. We ignore drag due to the
// distances being small.
//
// void particle_gravity_cb(void *particle, float clock_tick)
particle_gravity_cb:
	sub	sp, sp, 16
	str	x30, [sp]
/* vy_new = vy - gravity*clock_tick */
	ldr	s1, [x0, 12] // vy
	adr	x1, gravity
	ldr	s2, [x1]
	fmul	s2, s2, s0
	fsub	s1, s1, s2
	str	s1, [x0, 12] // vy
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Moves a particle based on its current velocity and the tick time.
//
// void particle_gravity_cb(void *particle, float clock_tick)
particle_movement_cb:
	sub	sp, sp, 16
	str	x30, [sp]
	bl	move_particle
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Apply velocity attentuation when a particle is rolling along the bottom.
// Also, zeroes out vy if the ball is rolling on the bottom.
//
// void particle_rolling_cb(void *particle, float clock_tick)
particle_rolling_cb:
	sub	sp, sp, 16
	str	x30, [sp]
	adr	x1, particle_radius
	ldr	s3, [x1]
	ldr	s0, [x0, 4] // y
	ldr	s1, [x0, 8] // vx
	ldr	s2, [x0, 12] // vy
	fcmp	s0, s3 // particle on bottom?
	b.gt	particle_rolling_cb_out
	adr	x1, velocity_min
	ldr	s3, [x1]
	fabs	s3, s3
	fabs	s4, s2
	fcmp	s4, s3 // particle velocity low enough?
	b.gt	particle_rolling_cb_out
	adr	x1, rolling_attenuation
	ldr	s3, [x1]
	fmul	s1, s1, s3
	str	s1, [x0, 8] // vx
	fmov	s2, 1.0
	fsub	s2, s2, s2
	str	s2, [x0, 12] // zero out vy
particle_rolling_cb_out:
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Ticks down the life of a particle and sets it to inactive if a threshold is
// reached.
// 
// void particle_life_cb(void *particle, float clock_tick)
particle_life_cb:
	sub	sp, sp, 16
	str	x30, [sp]
	ldr	s1, [x0, 16]
	fsub	s1, s1, s0
	str	s1, [x0, 16]
	fcmp	s1, s0
	mov	w1, TRUE
	mov	w2, FALSE
	csel	w1, w1, w2, GE
	str	w1, [x0, 20]
	ldr	s30, [sp]
	add	sp, sp, 16
	ret

// Emits a single particle and increments `num_particles`.
//
// void emit_single_particle(float x, float y, float vx, float vy, float life,
//                           bool active)
emit_single_particle:
	sub	sp, sp, 16
	str	x30, [sp]
	adr	x0, particles
	ldr	x0, [x0]
	adr	x1, num_particles
	ldr	w2, [x1]
	mov	w3, SIZEOF_PARTICLE
	mul	w3, w2, w3
	add	x0, x0, x3
	stp	s0, s1, [x0]
	stp	s2, s3, [x0, 8]
	str	s4, [x0, 16]
	str	w0, [x0, 20]
	add	w2, w2, 1
	str	w2, [x1]
/*
 * We reduce the render delay to offset the extra computation power needed for
 * each additional particle.
 */
	adr	x0, render_delay
	ldr	w1, [x0]
	sub	w1, w1, 1
	mov	w2, 0
	cmp	w1, w2
	csel	w1, w1, w2, GT
	str	w1, [x0]
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Emit the next particle once the emission delay has been reached.
//
// void emit_next_particle(void)
emit_next_particle:
	sub	sp, sp, 16
	str	x30, [sp]
	str	x19, [sp, 8]
	adr	x0, num_particles
	ldr	w0, [x0]
	mov	w1, NUM_PARTICLES
	cmp	w0, w1
	b.ge	emit_next_particle_out // all particles emitted
	adr	x4, last_emission_time
	ldr	s4, [x4]
	adr	x5, simulation_time
	ldr	s5, [x5]
	fmov	w19, s5
	adr	x6, emission_delay
	ldr	s6, [x6]
	fadd	s4, s4, s6
	fcmp	s4, s5
	b.gt	emit_next_particle_out // delay not reached
	mov	w1, EMITTER_WIDTH
	udiv	w2, w0, w1
	msub	w3, w2, w1, w0 // modulus
	mov	w0, EMITTER_X
	add	w0, w3, w0
	ucvtf	s0, w0
	mov	w1, EMITTER_Y
	ucvtf	s1, w1
	adr	x2, emission_velocity
	ldr	s2, [x2]
	ldr	s3, [x2, 4]
	adr	x2, emission_life
	ldr	s4, [x2]
	mov	w0, TRUE
	bl	emit_single_particle
	str	w19, [x4] // update last emission time
emit_next_particle_out:
	ldr	x19, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Adds a clock tick to the simulation time.
//
// void update_simulation_time(void)
update_simulation_time:
	sub	sp, sp, 16
	str	x30, [sp]
	adr	x0, simulation_time
	ldr	s0, [x0]
	adr	x1, clock_tick
	ldr	s1, [x1]
	fadd	s0, s0, s1
	str	s0, [x0]
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// Checks whether any particles are still active. If yes, return TRUE. If not,
// return FALSE. Only performs this check once all particles have been emitted.
//
// bool sim_is_running(void)
sim_is_running:
	sub	sp, sp, 16
	str	x30, [sp]
	mov	w4, TRUE
	mov	w5, FALSE
	fmov	s2, 1.0
	fsub	s2, s2, s2
	adr	x0, particles
	ldr	x0, [x0]
	adr	x1, num_particles
	ldr	w1, [x1]
	mov	w2, NUM_PARTICLES
	cmp	w1, w2
	b.lt	sim_is_running_out
	mov	w2, 0
	mov	x3, SIZEOF_PARTICLE
sim_is_running_loop:
	ldr	w6, [x0, 20] // active?
	mov	w7, TRUE
	cmp	w6, w7
	csel	w4, w7, w5, EQ
	b.eq	sim_is_running_out
	add	x0, x0, x3
	add	w2, w2, 1
	cmp	w2, w1
	b.lt	sim_is_running_loop
sim_is_running_out:
	mov	w0, w4
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// void clear_screen(void)
clear_screen:
        sub     sp, sp, 16
        str     x30, [sp]
	mov	x0, 0
        ldr     x1, =clrscrn
	mov	x2, 2 // length
	mov	x8, SVC_WRITE
	svc	0
        ldr     x30, [sp]
        add     sp, sp, 16
        ret

// Is there a particle at a particular location on the canvas?
//
// bool is_particle_present(int row, int col)
is_particle_present:
	sub	sp, sp, 16
	str	x30, [sp]
	mov	w7, FALSE
	adr	x2, particles
	ldr	x2, [x2]
	adr	x3, num_particles
	ldr	w3, [x3]
	cmp	w3, 0
	b.eq	is_particle_present_out
	mov	w4, 0
	mov	w5, SIZEOF_PARTICLE
/* Convert col & row into x & y. */
	mov	w10, CANVAS_MULT_H
	ucvtf	s0, w0
	ucvtf	s1, w10
	fdiv	s0, s0, s1
	fcvtnu	w0, s0
	mov	w10, BOX_HEIGHT
	sub	w0, w10, w0
	mov	w10, CANVAS_MULT_W
	ucvtf	s0, w1
	ucvtf	s1, w10
	fdiv	s0, s0, s1
	fcvtzu	w1, s0
is_particle_present_loop:
	ldr	s0, [x2] // x
	fcvtnu	w6, s0
	cmp	w6, w1
	b.ne	is_particle_present_continue
	ldr	s0, [x2, 4] // y
	fcvtnu	w6, s0
	cmp	w6, w0
	mov	w7, TRUE
	b.eq	is_particle_present_out
is_particle_present_continue:
	add	x2, x2, x5
	add	w4, w4, 1
	cmp	w4, w3
	b.lt	is_particle_present_loop
	mov	w7, FALSE
is_particle_present_out:
	mov	w0, w7
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

// void printnchar(char ch, int count)
printnchar:
        sub     sp, sp, 48
        str     x30, [sp]
        stp     x19, x20, [sp, 8]
        str     x21, [sp, 24]
        add     x19, sp, 32
	str	w0, [x19]
        mov     w20, w1
        mov     w21, 0
printnchar_loop:
	mov	w0, 0
        mov     x1, x19
	mov	x2, 1
	mov	x8, SVC_WRITE
        svc	0
        add     w21, w21, 1
        cmp     w21, w20
        b.lt    printnchar_loop
        ldr     x21, [sp, 24]
        ldp     x19, x20, [sp, 8]
        ldr     x30, [sp]
        add     sp, sp, 48
        ret

// void draw_canvas_row(int row)
draw_canvas_row:
	sub	sp, sp, 48
	str	x30, [sp]
	stp	x19, x20, [sp, 8]
	str	x21, [sp, 24]
	mov	w21, w0
	mov	w19, CANVAS_WIDTH
	mov	w20, 0
draw_canvas_row_loop:
	mov	w0, w21
	mov	w1, w20
	bl	is_particle_present
	cmp	w0, TRUE
	mov	w0, SYM_PARTICLE
	mov	w1, SYM_EMPTY
	csel	w1, w0, w1, EQ
	str	w1, [sp, 32]
	mov	w0, 0
	add	x1, sp, 32
	mov	w2, 1 // length
	mov	w8, SVC_WRITE
	svc	0
	add	w20, w20, 1
	cmp	w20, w19
	b.lt	draw_canvas_row_loop
	ldr	x21, [sp, 24]
	ldp	x19, x20, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 48
	ret
	
// void draw_canvas(void)
draw_canvas:
	sub	sp, sp, 32
	str	x30, [sp]
	stp	x19, x20, [sp, 8]
	mov	w19, CANVAS_HEIGHT
	mov	w20, 0
	mov	w0, SYM_CORNER
	mov	w1, 1
	bl	printnchar
	mov	w0, SYM_HORI
	mov	w1, CANVAS_WIDTH
	bl	printnchar
	mov	w0, SYM_CORNER
	mov	w1, 1
	bl	printnchar
	mov	w0, 0
	ldr	x1, =newline
	mov	w2, 1 // length
	mov	w8, SVC_WRITE
	svc	0
draw_canvas_loop:
	mov	w0, SYM_VERT
	mov	w1, 1
	bl	printnchar
	mov	w0, w20
	bl	draw_canvas_row
	mov	w0, SYM_VERT
	mov	w1, 1
	bl	printnchar
	mov	w0, 0
	ldr	x1, =newline
	mov	w2, 1 // length
	mov	w8, SVC_WRITE
	svc	0
	add	w20, w20, 1
	cmp	w20, w19
	b.lt	draw_canvas_loop
	mov	w0, SYM_CORNER
	mov	w1, 1
	bl	printnchar
	mov	w0, SYM_HORI
	mov	w1, CANVAS_WIDTH
	bl	printnchar
	mov	w0, SYM_CORNER
	mov	w1, 1
	bl	printnchar
	mov	w0, 0
	ldr	x1, =newline
	mov	w2, 1 // length
	mov	w8, SVC_WRITE
	svc	0
	ldp	x19, x20, [sp, 8]
	ldr	x30, [sp]
	add	sp, sp, 32
	ret

// Adds a delay between simulation ticks. Adjust `render_delay`  in case the
// simulation is rendered too quickly.
//
// void add_render_delay(void)
add_render_delay:
	sub	sp, sp, 16
	str	x30, [sp]
/*
 * We square the render delay since it decrements with each emitted particle.
 * Doing so allows us to (crudely) approximate the increased computation power
 * needed with each new particle.
 */
	adr	x0, render_delay
	ldr	w0, [x0]
	mul	w0, w0, w0
	mov	w1, 0
add_render_delay_loop:
	isb
	add	w1, w1, 1
	cmp	w1, w0
	b.lt	add_render_delay_loop
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

_start:
	.set	PROT_READ, 1
	.set	PROT_WRITE, 2
	.set	MAP_PRIVATE, 2
	.set	MAP_ANONYMOUS, 32
	.set	SVC_MMAP, 222
	sub	sp, sp, 16
	str	x30, [sp]
	mov	w0, SIZEOF_PARTICLE
	mov	w1, NUM_PARTICLES
	mul	w1, w0, w1
	mov	x0, NULL
	mov	w2, PROT_READ
	orr	w2, w2, PROT_WRITE
	mov	w3, MAP_PRIVATE
	mov	w4, MAP_ANONYMOUS
	orr	w3, w3, w4
	mov	w8, SVC_MMAP
	svc	0
	cmp	x0, NULL
	b.eq	_start_out
	adr	x1, particles
	str	x0, [x1]
_start_loop:
	bl	emit_next_particle
	adr	x0, particle_collision_cb
	bl	apply_particles_all
	adr	x0, particle_gravity_cb
	bl	apply_particles_all
	adr	x0, particle_movement_cb
	bl	apply_particles_all
	adr	x0, particle_rolling_cb
	bl	apply_particles_all
	adr	x0, particle_life_cb
	bl	apply_particles_all
	bl	update_simulation_time
	bl	add_render_delay
	bl	clear_screen
	bl	draw_canvas
	bl	sim_is_running
	cmp	w0, TRUE
	b.eq	_start_loop
_start_out: // don't bother unmapping `particles`
	mov	w0, 0
	ldr	x30, [sp]
	add	sp, sp, 16
	ret

	.data

simulation_time:
	.float	0.0

clock_tick: // in seconds; only used for simulation, not for rendering
	.float	0.05

velocity_min: // minimum velocity before movement stopped
	.float	0.5

gravity:
	.float	10.0

emission_velocity:
	.float	10.0 // x
	.float	0.0 // y
emission_life:
	.float	50.0
last_emission_time:
	.float	-5.0
emission_delay:
	.float	0.15

particle_radius:
	.float	1.0

/* Velocity is attenuated when a collision occurs. */
particle_attenuation:
	.float	0.95
wall_attenuation:
	.float	0.75
rolling_attenuation:
	.float	0.75

/*
 * Particle system. Each particle consists of a pair of coordinates and
 * velocity, respectively: (x, y, vx, vy, life, active)
 */
particles:
	.quad	NULL
num_particles:
	.4byte	0

render_delay:
	.4byte	RENDER_DELAY

newline:
	.asciz	"\n"
clrscrn:
	.asciz "\033c" // "\033[2J"
