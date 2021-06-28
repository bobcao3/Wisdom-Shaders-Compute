shape_cube = 0
shape_bottom_slab = 1
shape_top_slab = 2
shape_sheet = 3
shape_column = 4
shape_sphere = 5
shape_transparent = 6 # No interaction with the ray
shape_translucent = 7 # Color gets tinted

emissives = ["lantern", "lava", "fire", "torch", "glow", "beacon"]
transparents = ["door", "banner", "trapdoor", "rail", "lever", "button"]
columns = ["fence", "wall", "pot", "anvil"]

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
        for t in transparents:
            if t in line:
                shape = shape_transparent
        for c in columns:
            if c in line:
                shape = shape_column
        if "glass" in line:
            shape = shape_translucent
        if "torch" in line:
            shape = shape_sphere
        if "carpet" in line:
            shape = shape_sheet
        if "plate" in line:
            shape = shape_sheet
        if line == "snow":
            shape = shape_sheet
        if "hopper" in line:
            shape = shape_top_slab
        # Emissive
        for e in emissives:
            if e in line:
                emissive = 1
        # Add into list
        if "slab" in line:
            add_block(shape_bottom_slab, emissive, line, "type=bottom")
            add_block(shape_top_slab, emissive, line, "type=top")
        elif "stair" in line:
            add_block(shape_bottom_slab, emissive, line, "half=bottom")
            add_block(shape_top_slab, emissive, line, "half=top")            
        else:
            add_block(shape, emissive, line)

for key, items in ids.items():
    formatted = ' '.join(items)
    print(f"block.{key + 80000}={formatted}")