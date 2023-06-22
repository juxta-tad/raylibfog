package main

import "core:fmt"
import "core:math"
import lg "core:math/linalg"
import rl "vendor:raylib"
GLSL_VERSION :: 330
main :: proc(){
    screenWidth :i32= 1920/2;
    screenHeight :i32= 1080/2;
    //rl.SetTargetFPS(60)
    rl.SetConfigFlags({
        //rl.ConfigFlag.MSAA_4X_HINT,
        rl.ConfigFlag.WINDOW_RESIZABLE,
        //rl.ConfigFlag.VSYNC_HINT,
    })
    rl.InitWindow(screenWidth,screenHeight, "raylib [shaders] example - fog");


    camera := rl.Camera{};
    {
        using camera
        position = { 2.0, 2.0, 6.0};    // Camera position
        target = { 0.0, 0.5, 0.0 };      // Camera looking at point
        up = { 0.0, 1.0, 0.0 };          // Camera up vector (rotation towards target)
        fovy = 45.0;                                // Camera field-of-view Y
        projection = .PERSPECTIVE;             // Camera projection type
    }

    modelA  := rl.LoadModelFromMesh(rl.GenMeshTorus(0.4, 1.0, 16, 32));
    modelB  := rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0));
    modelC  := rl.LoadModelFromMesh(rl.GenMeshSphere(0.5, 32, 32));
    texture := rl.LoadTexture("resources/texel_checker.png");

    modelA.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture;
    modelB.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture;
    modelC.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = texture;

    shader := rl.LoadShader("resources/shaders/lighting.vs", "resources/shaders/fog.fs");

    shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocation(shader, "matModel");
    shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos");

    ambientLoc := rl.GetShaderLocation(shader, "ambient");
    S_val := [?]f32{ 0.2, 0.2, 0.2, 1.0 }
    rl.SetShaderValue(shader, auto_cast ambientLoc, &S_val, .VEC4);

    fogDensity :f32= 0.15;
    fogDensityLoc := rl.GetShaderLocation(shader, "fogDensity");
    rl.SetShaderValue(shader, auto_cast fogDensityLoc, &fogDensity, .FLOAT);

    // NOTE: All models share the same shader
    modelA.materials[0].shader = shader;
    modelB.materials[0].shader = shader;
    modelC.materials[0].shader = shader;

    // Using just 1 point lights
    CreateLight(.LIGHT_POINT, { 0, 2, 6 }, {}, rl.WHITE, shader);

    //rl.SetTargetFPS(60)

    defer rl.CloseWindow();
    for !rl.WindowShouldClose(){
        deltaTime := rl.GetFrameTime()

        rl.UpdateCamera(&camera, .ORBITAL);

        if (rl.IsKeyDown(.UP))
        {
            fogDensity += 0.001;
            if (fogDensity > 1.0) do fogDensity = 1.0;
        }

        if (rl.IsKeyDown(.DOWN))
        {
            fogDensity -= 0.001;
            if (fogDensity < 0.0) do fogDensity = 0.0;
        }

        rl.SetShaderValue(shader, auto_cast fogDensityLoc, &fogDensity, .FLOAT);

        // Rotate the torus
        angle : f32= -0.025 * 60 * deltaTime
        modelA.transform *= lg.matrix4_rotate(angle,lg.Vector3f32{1,1,0})
        // Update the light shader with the camera view position
        rl.SetShaderValue(shader, auto_cast shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], &camera.position.x, .VEC3);
        //----------------------------------------------------------------------------------

        rl.BeginDrawing();{
            rl.ClearBackground(rl.GRAY)
            rl.BeginMode3D(camera);

            // Draw the three models
            rl.DrawModel(modelA, {}, 1.0, rl.WHITE);
            rl.DrawModel(modelB, { -2.6, 0, 0 }, 1.0, rl.WHITE);
            rl.DrawModel(modelC, { 2.6, 0, 0 }, 1.0, rl.WHITE);

            for i := -20; i < 20; i += 2 do rl.DrawModel(modelA,{ f32(i), 0, 2 }, 1.0, rl.WHITE);

            rl.EndMode3D();

            rl.DrawText(rl.TextFormat("Use KEY_UP/KEY_DOWN to change fog density [%.2f]", fogDensity), 10, 10, 20, rl.RAYWHITE);

        }
        rl.EndDrawing()
    }

    rl.UnloadModel(modelA)
    rl.UnloadModel(modelB)
    rl.UnloadModel(modelC)
    rl.UnloadTexture(texture)
    rl.UnloadShader(shader)

    rl.CloseWindow()


}



 MAX_LIGHTS  :: 4         // Max dynamic lights supported by shader
// Light data
Light :: struct {   
    L_type : LightType,
    enabled : bool,
    position : rl.Vector3,
    target : rl.Vector3 ,
    color : rl.Color,
    attenuation : f32,
    
    // Shader locations
    enabledLoc   : int ,
    typeLoc   : int ,
    positionLoc   : int ,
    targetLoc   : int ,
    colorLoc   : int ,
    attenuationLoc   : int ,
}

// Light type
LightType ::  enum {
    LIGHT_DIRECTIONAL = 0,
    LIGHT_POINT,
}




lightsCount :int= 0

// Create a light and get shader locations
CreateLight :: proc(L_type : LightType, position, target : rl.Vector3 , color : rl.Color ,  shader : rl.Shader) -> Light
{
    using rl
    light := Light{};

    if (lightsCount < MAX_LIGHTS)
    {
        light.enabled = true;
        light.L_type = L_type;
        light.position = position;
        light.target = target;
        light.color = color;

        // NOTE: Lighting shader naming must be the provided ones
        light.enabledLoc =  int(GetShaderLocation(shader, TextFormat("lights[%i].enabled", lightsCount)))
        light.typeLoc =     int(GetShaderLocation(shader, TextFormat("lights[%i].type", lightsCount)))
        light.positionLoc = int(GetShaderLocation(shader, TextFormat("lights[%i].position", lightsCount)))
        light.targetLoc =   int(GetShaderLocation(shader, TextFormat("lights[%i].target", lightsCount)))
        light.colorLoc =    int(GetShaderLocation(shader, TextFormat("lights[%i].color", lightsCount)))

        UpdateLightValues(shader, &light);
        
        lightsCount+=1;
    }

    return light;
}

// Send light properties to shader
// NOTE: Light shader locations should be available 

UpdateLightValues :: proc(shader : rl.Shader , light : ^Light)
{
    using light
    using rl
    // Send to shader light enabled state and type
    
    rl.SetShaderValue(shader, auto_cast light.enabledLoc, &light.enabled, .INT);
    rl.SetShaderValue(shader, auto_cast light.typeLoc, &light.L_type, .INT);

    // Send to shader light position values
    positionn := rl.Vector3{ light.position.x, light.position.y, light.position.z };
    SetShaderValue(shader, auto_cast light.positionLoc, &positionn, .VEC3);

    // Send to shader light target position values
    targett := rl.Vector3{ light.target.x, light.target.y, light.target.z };
    SetShaderValue(shader,auto_cast light.targetLoc, &targett, .VEC3);

    // Send to shader light color values
    colorr := Vector4{ f32(color.r)/f32(255),f32(color.g)/f32(255), f32(color.b)/f32(255), f32(color.a)/f32(255) };
    SetShaderValue(shader, auto_cast light.colorLoc, &colorr, .VEC4);
}
