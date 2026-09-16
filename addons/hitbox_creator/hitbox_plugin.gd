@tool
extends EditorPlugin

var dock: Control
var hitbox_manager: HitBoxManager

func _enter_tree() -> void:
	print("[HitBox Plugin] Initializing...")
	
	# Создаем менеджер
	hitbox_manager = HitBoxManager.new()
	hitbox_manager.editor_plugin = self
	hitbox_manager.editor_interface = get_editor_interface()
	
	# Создаем UI
	dock = hitbox_manager.create_dock_panel()
	if dock:
		add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)
		print("[HitBox Plugin] Dock panel created")
	else:
		printerr("[HitBox Plugin] Failed to create dock panel")
	
	# Подключаем сигналы
	get_editor_interface().get_selection().selection_changed.connect(
		hitbox_manager._on_selection_changed
	)
	
	print("[HitBox Plugin] Initialized successfully")

func _exit_tree() -> void:
	print("[HitBox Plugin] Cleaning up...")
	
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		print("[HitBox Plugin] Dock panel removed")
	
	if hitbox_manager:
		hitbox_manager.queue_free()
		print("[HitBox Plugin] Manager cleaned up")

func _enable_plugin() -> void:
	print("[HitBox Plugin] Enabled")

func _disable_plugin() -> void:
	print("[HitBox Plugin] Disabled")
