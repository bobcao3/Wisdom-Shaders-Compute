shape_cube = 0
shape_bottom_slab = 1
shape_top_slab = 2
shape_sphere = 3
shape_transparent = 4

emissives = ["lantern", "lava", "fire", "torch", "glow"]

ids = {}

def get_id(shape: int, emissive: int):
    return (shape << 1) | emissive

def add_block(shape: int, emissive: int, name, flag = ""):
    id = get_id(shape, emissive)
    if id not in ids.keys():
        ids[id] = []
    if flag != "":
        ids[id].append(name + ":" + flag)
    else:
        ids[id].append(name)

with open('blocks.txt') as f:
    lines = f.read().splitlines()
    for line in lines:
        shape = 0
        emissive = 0
        # Shapes
        if "stairs" in line:
            shape = shape_bottom_slab
        if "glass" in line:
            shape = shape_transparent
        # Emissive
        for e in emissives:
            if e in line:
                emissive = 1
        # Add into list
        if "slab" in line:
            add_block(shape_bottom_slab, emissive, line, "type=bottom")
            add_block(shape_top_slab, emissive, line, "type=bottom")
        else:
            add_block(shape, emissive, line)

for key, items in ids.items():
    formatted = ' '.join(items)
    print(f"block.800{key}={formatted}")