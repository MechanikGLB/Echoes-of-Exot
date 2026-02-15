extends MeshInstance3D

@onready var blood = $bloodSplatter
@onready var terrain = $terrainSplatter

var alpha = 0.8

func _ready() -> void:
	var dup_mat = material_override.duplicate()
	dup_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	dup_mat.blend_mode = StandardMaterial3D.BLEND_MODE_MIX
	material_override = dup_mat

func init(pos1, pos2):
	var draw_mesh = ImmediateMesh.new()
	mesh = draw_mesh
	draw_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material_override)
	draw_mesh.surface_add_vertex(pos1)
	draw_mesh.surface_add_vertex(pos2)
	draw_mesh.surface_end()
	
func _process(delta: float) -> void:
	alpha -= delta * 3.5
	alpha = clamp(alpha, 0.0, 1.0)
	material_override.albedo_color.a = alpha

func trigger_particles(pos, gun_pos, on_enemy):
	if on_enemy:
		blood.position = pos
		blood.look_at(gun_pos)
		blood.emitting = true
	else:
		terrain.position = pos
		terrain.look_at(gun_pos)
		terrain.emitting = true

func _on_timer_timeout() -> void:
	queue_free()
