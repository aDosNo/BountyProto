extends "res://scripts/gang_guard.gd"

## SentryDrone — ambient police drone that patrols the district and engages the
## player ONLY after the player kills a non-target civilian. Reuses GangGuard's
## perception/combat/alert pipeline by extension; what differs:
##  - It does NOT escalate on seeing the player, on gunfire, or on ally shouts.
##    The ONLY thing that arms it is a confirmed civilian KILL (not a wound,
##    not the target, not a guard) via on_civilian_killed().
##  - Once armed it becomes a deadly hunter: alerts onto the kill position,
##    chases on last-known, and (per scope) eventually gives up via the
##    inherited alert_memory decay, disarming back to patrol.
##  - Floating movement: it hovers at a fixed height and ignores gravity.
##  - Vision cone is hidden while patrolling; it only shows while armed/tracking.
##
## Civilian-kill detection itself lives in CrowdNPC._die -> the "police_drone"
## group broadcast (see crowd_npc.gd). The drone holds the "is this punishable?"
## policy: it only responds to was_target == false.

@export_group("Drone")
## Hover height above its spawn Y. Drones float; gravity is ignored.
@export var hover_height: float = 2.6
## Gentle vertical bob amplitude/speed for the idle hover read.
@export var bob_amplitude: float = 0.18
@export var bob_speed: float = 1.8
## While disarmed the drone is non-lethal and won't fire even if it "sees" the
## player. It arms only on a civilian kill.
@export var patrol_speed: float = 2.4
## When armed, the drone moves faster than its lazy patrol.
@export var hunt_speed: float = 4.6

var _armed: bool = false
var _hover_base_y: float = 0.0
var _bob_time: float = 0.0
@onready var _drone_sprite: Sprite3D = %DroneSprite


func _ready() -> void:
	# Force sentry semantics regardless of scene flags: always-on, ambient,
	# left alone by BountyManager's pressure-enemy activation.
	sentry = true
	starts_active = true
	super._ready()
	add_to_group("police_drone")
	_hover_base_y = global_position.y
	# Drones patrol lazily until armed.
	move_speed = patrol_speed
	# Make the inherited perception effectively blind to the PLAYER until armed:
	# huge detect times so vision never escalates on its own. Civilian kill is
	# the only arming path.
	detect_time_close = 9999.0
	detect_time_far = 9999.0
	# Vision cone stays hidden while patrolling; it only appears once the drone
	# is armed and actively tracking after a civilian kill.
	_set_cone_visible(false)


## The civilian-kill broadcast. CrowdNPC calls this on the "police_drone" group
## at death with whether the dead NPC was the bounty target. Only a NON-target
## civilian kill arms the drone; everything else is ignored.
func on_civilian_killed(victim_position: Vector3, was_target: bool) -> void:
	if _is_dead or _neutralized:
		return
	if was_target:
		return  # killing the mark is the job, not a crime
	_arm_and_engage(victim_position)


func _arm_and_engage(at_position: Vector3) -> void:
	_armed = true
	move_speed = hunt_speed
	# Restore real detection responsiveness now that it's hunting, so if it
	# loses the player it can re-acquire by sight like a normal alerted unit.
	detect_time_close = 0.6
	detect_time_far = 1.4
	# Cone becomes visible now that the drone is tracking.
	_set_cone_visible(true)
	# Route the engage through the inherited alert path: this sets last-known,
	# arms alert_memory, flips the indicator, and propagates to nearby units.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var threat := player.global_position if player != null else at_position
	_enter_alerted(threat)
	print("SentryDrone ARMED on civilian kill.")


## Ignore noise and ally shouts entirely — drones are not part of the gang's
## perception net. Only on_civilian_killed arms them.
func hear_noise(_noise_position: Vector3, _loudness: float) -> void:
	pass


func on_ally_alert(_shouter_position: Vector3, _threat_position: Vector3) -> void:
	pass


## Drone is only dangerous once armed. While patrolling it never fires, even if
## the inherited combat state somehow sees the player.
func _attack_player() -> void:
	if not _armed:
		return
	super._attack_player()


## Floating movement: keep the inherited XZ steering but override vertical so
## the drone hovers + bobs instead of falling. Called by inherited
## _physics_process via move_and_slide; we post-process Y here.
func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_bob_time += delta
	super._physics_process(delta)
	# After the parent has run its XZ movement + move_and_slide, pin the hover
	# height (with a gentle bob) so gravity never pulls the drone down.
	var target_y := _hover_base_y + hover_height + sin(_bob_time * bob_speed) * bob_amplitude
	global_position.y = lerpf(global_position.y, target_y, minf(delta * 6.0, 1.0))
	velocity.y = 0.0


## When the drone gives up (inherited combat -> RETURNING/UNAWARE via
## alert_memory), disarm so it returns to harmless patrol.
func _do_return(delta: float) -> void:
	if _armed:
		_armed = false
		move_speed = patrol_speed
		detect_time_close = 9999.0
		detect_time_far = 9999.0
		# Tracking over — hide the cone again.
		_set_cone_visible(false)
		print("SentryDrone disarmed — returning to patrol.")
	super._do_return(delta)


## Toggle the inherited debug vision cone. Guard creates _vision_cone in
## _create_vision_cone(); drones gate its visibility on armed/tracking state.
func _set_cone_visible(show_cone: bool) -> void:
	if _vision_cone != null:
		_vision_cone.visible = show_cone


func _flash_hit() -> void:
	if _drone_sprite == null:
		return
	_drone_sprite.modulate = Color(1.0, 0.16, 0.08, 1.0)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(_drone_sprite) and not _is_dead:
		_drone_sprite.modulate = Color.WHITE
