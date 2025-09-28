@tool
extends EditorScript

func _run():
	print("=== Проверка поддерживаемых видеоформатов ===")
	
	# Проверяем импортеры
	var importers = ResourceLoader.get_recognized_extensions_for_type("VideoStream")
	print("Поддерживаемые расширения для VideoStream: ", importers)
	
	# Тестируем загрузку разных типов
	var test_files = [
		"res://test.ogv",
		"res://test.ogg", 
		"res://test.webm",
		"res://test.avi",
        "res://test.mkv"
	]
	
	for file in test_files:
		if FileAccess.file_exists(file):
			var res = load(file)
			if res:
				print("✅ ", file, " - ", res.get_class())
			else:
				print("❌ ", file, " - не загружается")


#func _run():
	#print("=== ДИАГНОСТИКА ВИДЕОФАЙЛА ===")
	#
	#var video_path = "res://Assets/intros/B&B_intro_correct.mp4"
	#
	## Проверка существования файла
	#if FileAccess.file_exists(video_path):
		#print("✅ Файл существует")
		#
		## Проверка размера файла
		#var file = FileAccess.open(video_path, FileAccess.READ)
		#if file:
			#var size = file.get_length()
			#file.close()
			#print("📊 Размер файла: ", size, " байт")
			#
			#if size < 1000:
				#print("❌ Файл слишком маленький, вероятно пустой")
				#return
		#else:
			#print("❌ Не удалось открыть файл для чтения")
			#return
	#else:
		#print("❌ Файл не существует по пути: ", video_path)
		#return
	#
	## Пробуем разные способы загрузки
	#test_different_load_methods(video_path)
#
#func test_different_load_methods(path: String):
	#print("--- Тест методов загрузки ---")
	#
	## Метод 1: Простая загрузка
	#print("1. Простая загрузка:")
	#var res1 = load(path)
	#if res1:
		#print("   ✅ Успех: ", res1.get_class())
	#else:
		#print("   ❌ Не удалось")
	#
	## Метод 2: С указанием типа
	#print("2. Загрузка как VideoStream:")
	#var res2 = ResourceLoader.load(path, "VideoStream", ResourceLoader.CACHE_MODE_IGNORE)
	#if res2:
		#print("   ✅ Успех: ", res2.get_class())
	#else:
		#print("   ❌ Не удалось")
	#
	## Метод 3: Через FileAccess
	#print("3. Чтение как бинарный файл:")
	#var file = FileAccess.open(path, FileAccess.READ)
	#if file:
		#var data = file.get_buffer(100)  # Первые 100 байт
		#print("   ✅ Прочитано байт: ", data.size())
		#print("   📝 Сигнатура: ", data.slice(0, 8).hex_encode())
		#file.close()
	#else:
		#print("   ❌ Не удалось открыть")
