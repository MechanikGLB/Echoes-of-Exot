extends Label

var time_elapsed: float = 0.0  # Время в секундах
var is_running: bool = true    # Флаг для паузы/запуска

func _ready():
	# Можно сразу запустить, если нужно
	pass

func _process(delta):
	if is_running:
		time_elapsed += delta
		update_display()

# Обновляем текст Label
func update_display():
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	text = "%02d:%02d" % [minutes, seconds]  # Формат MM:SS

# Функции для управления таймером (если нужно)
func start():
	is_running = true

func stop():
	is_running = false

func reset():
	time_elapsed = 0.0
	update_display()
