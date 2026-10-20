class_name CharacterPortrait
extends RefCounted
## Small self-contained JPEGs travel with saves; no device-local paths on the wire.
const EDGE := 256
const MAX_ENCODED := 100000
const MAX_FILE_BYTES := 20000000

static func import_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return {"error": "Choose a PNG, JPEG or WebP image smaller than 20 MB."}
	var bytes := file.get_buffer(file.get_length())
	var img := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png": error = img.load_png_from_buffer(bytes)
		"jpg", "jpeg": error = img.load_jpg_from_buffer(bytes)
		"webp": error = img.load_webp_from_buffer(bytes)
	if error != OK or img.is_empty():
		return {"error": "That image could not be opened. Choose PNG, JPEG or WebP."}
	return {"portrait": encode(img)}

static func encode(source: Image) -> String:
	var side := mini(source.get_width(), source.get_height())
	var img := source.get_region(Rect2i((source.get_width() - side) / 2, (source.get_height() - side) / 2, side, side))
	img.resize(EDGE, EDGE, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	return Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.8))

static func decode(encoded: String) -> Image:
	if encoded.is_empty() or encoded.length() > MAX_ENCODED:
		return null
	var img := Image.new()
	if img.load_jpg_from_buffer(Marshalls.base64_to_raw(encoded)) != OK:
		return null
	if img.get_width() != EDGE or img.get_height() != EDGE:
		return null
	return img
