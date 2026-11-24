class_name V10MetaUI
extends RefCounted

# Small UI helper of the meta components. A Label with OVERRUN_TRIM_ELLIPSIS whose size is set BEFORE it enters the
# tree grows back to its full text width on enter (Godot 4.5: the stale minimum size wins), so the ellipsis never
# shows and the text runs off the card. trim() remembers the wanted size; refit(root) re-applies it once the
# component is in the tree (components call it from _ready and after a rebuild).

const META: = "v10_trim_size"


static func trim(l: Label, sz: Vector2) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size = sz
	l.set_meta(META, sz)
	return l


# same for a wrapped caption (autowrap): only remembers and re-applies the size
static func keep(l: Label, sz: Vector2) -> Label:
	l.size = sz
	l.set_meta(META, sz)
	return l


static func refit(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is Label and root.has_meta(META):
		(root as Label).size = root.get_meta(META)
	for c in root.get_children():
		refit(c)
