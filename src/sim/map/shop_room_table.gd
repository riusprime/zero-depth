class_name ShopRoomTable
extends RefCounted
## A biome's shop room, compiled (v0.8.0 SR; ShopRoomDefinition, RunContentCompiler.compile_shop_rooms): whole
## centimetres and per mille, like RoomLayoutTable. ShopRoom furnishes the floor's shop room with it.

var id := &""
var biome := &""
## The stall's pieces, centimetres from its centre (its anchor unused), front (the counter) toward the frame's -y.
var stall := RoomLayoutGroupTable.new()
## The stall's candidate centres, per mille of the room in the shop frame, in order.
var stall_spots: Array[Vector2i] = []
## The clear box in front of the counter: width and depth, cm.
var approach := Vector2i(500, 300)
## The dressing round the stall (its groups; cells and keep_clear unused).
var layout := RoomLayoutTable.new()
