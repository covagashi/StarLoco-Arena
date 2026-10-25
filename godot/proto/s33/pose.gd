extends RefCounted

## S33 prototype: ONE procedural pose set shared by every technique and every
## class. A pose is a handful of angles on a common skeleton (hips, head,
## two arms, two legs), so the 3D rig and the 2D cutout read the same numbers:
## that is the "one animation per skeleton, not per class or direction" bet.
##
## Angles are radians; arm/leg > 0 swings the limb forward. `squash` scales
## the body (1 = rest), `flash` whitens it (hit feedback), `fall` tips the
## whole figure over (death).

const ANIMS := ["idle", "walk", "cast", "hit", "die"]
const LENGTH := {"idle": 1.6, "walk": 0.7, "cast": 1.0, "hit": 0.5, "die": 1.0}
## Moment the cast lets go of the spell (seconds into "cast").
const CAST_RELEASE := 0.42


static func pose(anim: String, t: float) -> Dictionary:
	var p := {"bob": 0.0, "lean": 0.0, "head": 0.0, "arm_l": 0.0, "arm_r": 0.0,
		"leg_l": 0.0, "leg_r": 0.0, "squash": 1.0, "flash": 0.0, "fall": 0.0,
		"staff": 0.0}
	match anim:
		"idle":
			var w := TAU * t / LENGTH.idle
			p.bob = 0.02 * sin(w * 2.0)
			p.squash = 1.0 + 0.025 * sin(w * 2.0)
			p.head = 0.06 * sin(w)
			p.arm_l = 0.10 * sin(w + 0.6)
			p.arm_r = 0.10 * sin(w + 0.6)
		"walk":
			var w := TAU * t / LENGTH.walk
			p.leg_l = 0.65 * sin(w)
			p.leg_r = -p.leg_l
			p.arm_l = -0.55 * sin(w)
			p.arm_r = -p.arm_l
			p.bob = 0.035 * absf(sin(w))
			p.lean = 0.10
		"cast":
			# wind-up → release → follow-through, eased by hand
			var k := clampf(t / CAST_RELEASE, 0.0, 1.0)
			var back := clampf((t - CAST_RELEASE) / 0.35, 0.0, 1.0)
			var up := _ease_out(k) * (1.0 - _ease_in(back) * 0.75)
			p.arm_r = lerpf(0.0, 2.5, up)
			p.staff = up
			p.arm_l = -0.5 * up
			p.lean = lerpf(-0.18, 0.22, _ease_out(k)) * (1.0 - back * 0.8)
			p.squash = 1.0 + 0.08 * sin(PI * k) - 0.06 * sin(PI * back)
			p.bob = 0.03 * sin(PI * k)
		"hit":
			var k := clampf(t / LENGTH.hit, 0.0, 1.0)
			var kick := exp(-7.0 * k) * sin(PI * minf(k * 4.0, 1.0))
			p.lean = -0.45 * kick
			p.head = -0.30 * kick
			p.arm_l = 0.8 * kick
			p.arm_r = 0.8 * kick
			p.squash = 1.0 - 0.18 * kick
			p.flash = clampf(1.0 - k * 3.0, 0.0, 1.0)
		"die":
			var k := clampf(t / LENGTH.die, 0.0, 1.0)
			p.fall = _ease_in(k) * 1.45
			p.arm_l = 1.2 * k
			p.arm_r = 1.0 * k
			p.head = 0.4 * k
			p.squash = 1.0 - 0.1 * sin(PI * k)
	return p


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(x: float) -> float:
	return x * x
