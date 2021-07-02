// Custom functions
function compute_uniform(thing)
{
    // some stuff here
    return thing + 5
}

shaderpack = {}

// Every shader must implement this function
function onInit()
{
    shaderpack.noiseimg0 = LoadExternalImg("noise_256.png")
    shaderpack.noiseimg1 = LoadExternalImg("noise_128.png")
    shaderpack.noiseimg2 = LoadExternalImg("noise_64.png")

    // Creates a noise tex with 3 LOD levels
    shaderpack.noisetex = CreateTextureFromImg([noiseimg0, noiseimg1, noiseimg2])

    // Loads an external 3D image of dimension 32x32x16, pixel format is "R16", input data format is "unsigned short"
    shaderpack.lut3d = LoadExternalImg("lut3d.dat", [32, 32, 16], "R16", "UNSIGNED_SHORT")

    shaderpack.smap0 = CreateImg([1024, 1024], "R32F")
    shaderpack.smap1 = CreateImg([1024, 1024], "R32F")
    shaderpack.vsm = CreateImg([512, 512], "R32F")
}

// Every shader must implement this function
function onRender(state)
{
    // state is a list containing current states (e.g. proj matrices, time, the biome player is in, positions, etc.)

    RenderGeometry(
        "shadowmap", // name / id for the geometry group to render
        [shaderpack.smap0], // render targets
        ["shadow.fsh", "shadow.vsh"], // shaders
        (geometryStates) => {
            // geometryStates are things special for this specific geometry group, e.g. the textures, etc.
            // This lambda runs before rendering, after shader program is bound
            BindUniformTexture("albedo", shadowStates.albedo)
            BindUniformImage("lut3dimg", shaderpack.lut3d)
            BindUniformFloat("cascade", 0)
            BindUniformMatrix("proj", state.shadow.projection)
            ClearColor(0.0, 0.0, 0.0, 0.0)
            ClearDepth(0.0)
        },
        (geometryStates) => {
            // This runs after rendering
            CopyTexture(shaderpack.smap0, shaderpack.smap1)
        }
    )

    DispatchCompute(
        ["variance_shadow_map.comp"], // shaders source
        [32, 32, 1], // number of groups
        () => {
            // this runs before
            BindUniformImage("vsmimg", shaderpack.vsm)
            BindUniformImage()
        },
        () => {
            // this runs after, it can be nothing
        }
    )

    // ... and things and things and things
    RenderGeometry(
        "quad", // a quad, good for "composite" passes
        [state.framebuffer], // if this is specified, this pass will render to the framebuffer output\
        ["tonemap.fsh", "tonemap.vsh"],
        () => {
            BindUniformImage("composite", shaderpack.composite)
        },
        () => {
        }
    )
}