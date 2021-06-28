shape_cube = 0
shape_bottom_slab = 1
shape_top_slab = 2
shape_sheet = 3
shape_column = 4
shape_sphere = 5
shape_transparent = 6 # No interaction with the ray
shape_translucent = 7 # Color gets tinted

emissives = ["lantern", "lava", "fire", "torch", "glow", "beacon", "sea_pickle", "end_rod", "glow", "concrete_powder"]
transparents = ["door", "banner", "trapdoor", "rail", "lever", "button", "water", "iron_bars", "wire", "cobweb", "sapling", "tulip", "fungus", "vine", "root", "sugar_cane", "ladder"]
transparents_exact = [
    "minecraft:grass", "minecraft:fern", "minecraft:dead_bush", "minecraft:seagrass", "minecraft:dandelion", "minecraft:poppy",
    "minecraft:blue_orchid", "minecraft:allium", "minecraft:azure_bluet", "minecraft:oxeye_daisy", "minecraft:cornflower",
    "minecraft:lily_of_the_valley", "minecraft:wither_rose", "minecraft:brown_mushroom", "minecraft:red_mushrrom", "minecraft:lily_pad",
    "minecraft:sunflower", "minecraft:lilac", "minecraft:rose_bush", "minecraft:peony", "minecraft:tall_grass", "minecraft:large_fern"]
columns = ["fence", "wall", "pot", "anvil", "sea_pickle", "bamboo", "cactus", "chorus", "end_rod"]

hardcodes = {"minecraft:end_rod": 1, "minecraft:torch": 2, "minecraft:wall_torch": 2, "minecraft:soul_torch": 3, "minecraft:soul_wall_torch": 3}

ids = {}

def get_id(shape: int, emissive: int, hardcodes: int):
    return (shape << 1) | emissive | (hardcodes << 8)

def add_block(shape: int, emissive: int, hardcode: int, name, flag = ""):
    id = get_id(shape, emissive, hardcode)
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
        hardcode = 0
        # Shapes
        for t in transparents:
            if t in line:
                shape = shape_transparent
        for t in transparents_exact:
            if t == line:
                shape = shape_transparent
        for c in columns:
            if c in line:
                shape = shape_column
        if "glass" in line:
            shape = shape_translucent
        if "leaves" in line:
            shape = shape_translucent
        if "torch" in line:
            shape = shape_sphere
        if "carpet" in line:
            shape = shape_sheet
        if "plate" in line:
            shape = shape_sheet
        if line == "minecaft:snow":
            shape = shape_sheet
        if line == "minecraft:enchanting_table":
            shape = shape_bottom_slab
        if "hopper" in line:
            shape = shape_top_slab
        # Emissive
        for e in emissives:
            if e in line:
                emissive = 1
        # Hard codes
        for h in hardcodes.keys():
            if h == line:
                hardcode = hardcodes[h]
        # Add into list
        if "slab" in line:
            add_block(shape_bottom_slab, emissive, hardcode, line, "type=bottom")
            add_block(shape_top_slab, emissive, hardcode, line, "type=top")
        elif "stair" in line:
            add_block(shape_bottom_slab, emissive, hardcode, line, "half=bottom")
            add_block(shape_top_slab, emissive, hardcode, line, "half=top")            
        else:
            add_block(shape, emissive, hardcode, line)

for key, items in ids.items():
    formatted = ' '.join(items)
    print(f"block.{key | (1 << 12)}={formatted}")