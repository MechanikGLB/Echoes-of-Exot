@tool
class_name HitBoxUtils
extends RefCounted

static func parse_limb_name(node_name: String, limb_names: Array) -> Dictionary:
	"""Парсит имя ноды в структуру конечности"""
	print("[HitBox Utils] Parsing: ", node_name)
	
	# Удаляем _v если есть
	var clean_name = node_name.replace("_v", "")
	
	# Ищем последнее подчеркивание
	var parts = clean_name.split("_")
	if parts.size() < 2:
		print("[HitBox Utils] Not enough parts")
		return {}
	
	# Проверяем, является ли последняя часть числом
	var last_part = parts[parts.size() - 1]
	print("[HitBox Utils] Last part: ", last_part, " is int: ", last_part.is_valid_int())
	
	if not last_part.is_valid_int():
		return {}
	
	var limb_number = last_part.to_int()
	
	# Имя конечности - все части кроме последней
	var limb_name_parts = parts.slice(0, parts.size() - 1)
	var limb_name = "_".join(limb_name_parts)
	
	print("[HitBox Utils] Limb name candidate: ", limb_name, " number: ", limb_number)
	
	# Проверяем, является ли это известной конечностью
	var is_known_limb = false
	for known_limb in limb_names:
		if limb_name == known_limb or limb_name.begins_with(known_limb + "_"):
			is_known_limb = true
			print("[HitBox Utils] Matched known limb: ", known_limb)
			break
	
	if not is_known_limb:
		# Проверяем, содержит ли имя ключевые слова конечностей
		for known_limb in limb_names:
			if known_limb in limb_name:
				is_known_limb = true
				print("[HitBox Utils] Contains known limb: ", known_limb)
				break
	
	if is_known_limb:
		var result = {
			"limb_name": limb_name,
			"limb_number": limb_number,
			"has_v": "_v" in node_name,
			"full_name": node_name
		}
		print("[HitBox Utils] Result: ", result)
		return result
	
	print("[HitBox Utils] Not a limb")
	return {}

static func should_skip_node(node_name: String) -> bool:
	"""Определяет, нужно ли пропустить ноду при создании хитбоксов"""
	var lower_name = node_name.to_lower()
	var skip_keywords = [
		"camera", "cam", "view", 
		"weapon", "gun", "sword", "rifle", "pistol",
		"item", "tool", "attachment", "attach",
		"light", "lamp", "fx", "effect", "particle",
		"trigger", "zone", "area", "volume",
		"helper", "dummy", "point", "locator",
		"hitbox", "collision", "bounding", "bone"
	]
	
	for keyword in skip_keywords:
		if keyword in lower_name:
			print("[HitBox Utils] Skipping ", node_name, " because of keyword: ", keyword)
			return true
	
	return false

static func get_all_children(node: Node) -> Array:
	"""Рекурсивно получает всех детей ноды"""
	var result = []
	for child in node.get_children():
		result.append(child)
		result.append_array(get_all_children(child))
	return result
