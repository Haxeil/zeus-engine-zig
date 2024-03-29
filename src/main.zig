const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const String = @import("zig_string.zig").String;
const Engine = @import("engine.zig");
pub const math = @import("math/main.zig");
const Shapes = @import("Shapes.zig");

pub fn main() !void {
    var engine = try Engine.Engine.init(1200, 800, "zeus-zig | frames: {0} , updates: {0}, delta: {0}");
    defer engine.deinit();

    var cam_offset = math.vec3(0, 0, 10);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("memory leak");
        }
    }

    var mesh2 = Engine.Mesh.init(allocator);
    defer mesh2.deinit();

    mesh2.vertices.appendSlice(&.{
        // front
        Engine.Vertex{ .position = math.vec3(-1.0, -1.0, 1.0) },
        Engine.Vertex{ .position = math.vec3(1.0, -1.0, 1.0) },
        Engine.Vertex{ .position = math.vec3(1.0, 1.0, 1.0) },
        Engine.Vertex{ .position = math.vec3(-1.0, 1.0, 1.0) },

        // back
        Engine.Vertex{ .position = math.vec3(-1.0, -1.0, -1.0) },
        Engine.Vertex{ .position = math.vec3(1.0, -1.0, -1.0) },
        Engine.Vertex{ .position = math.vec3(1.0, 1.0, -1.0) },
        Engine.Vertex{ .position = math.vec3(-1.0, 1.0, -1.0) },
    }) catch {};

    mesh2.indices.appendSlice(&.{
        // front
        0, 1, 2,
        2, 3, 0,
        // right
        1, 5, 6,
        6, 2, 1,
        // back
        7, 6, 5,
        5, 4, 7,
        // left
        4, 0, 3,
        3, 7, 4,
        // bottom
        4, 5, 1,
        1, 0, 4,
        // top
        3, 2, 6,
        6, 7, 3,
    }) catch {};

    try Shapes.sphere(&mesh2, 60, 60, 5);

    try mesh2.create();
    //Shader
    var shader = Engine.Shader.init("shader/vertex.glsl", "shader/fragment.glsl");

    defer shader.deinit();
    try shader.comptile();

    var motion = math.vec3(0, 0, 0);

    var speed: f32 = 0.355;

    while (engine.is_running()) {

        // game logic runs at 60 fps
        while (engine.engine_time.?.delta >= 1) {
            if (engine.window.?.getKey(.w) == glfw.Action.press) {
                cam_offset.v[2] -= engine.engine_time.?.delta * speed;
            } else if (engine.window.?.getKey(.s) == glfw.Action.press) {
                cam_offset.v[2] += engine.engine_time.?.delta * speed;
            }

            if (engine.window.?.getKey(.d) == glfw.Action.press) {
                cam_offset.v[0] -= engine.engine_time.?.delta * speed;
            } else if (engine.window.?.getKey(.a) == glfw.Action.press) {
                cam_offset.v[0] += engine.engine_time.?.delta * speed;
            }

            if (engine.window.?.getKey(.q) == glfw.Action.press) {
                cam_offset.v[1] -= engine.engine_time.?.delta * speed;
            } else if (engine.window.?.getKey(.e) == glfw.Action.press) {
                cam_offset.v[1] += engine.engine_time.?.delta * speed;
            }

            const time: f32 = @floatCast(glfw.getTime() * 10.0);
            motion.v[0] = math.sin(time);
            engine.engine_time.?.updates += 1;
            engine.engine_time.?.delta -= 1;
        }

        // engine.camera.update_projection_matrix();
        // rendering logic runs as fast as possible
        const motion_matrix = math.Mat4x4.translate(cam_offset);
        engine.camera.view_matrix = math.Mat4x4.ident.mul(&motion_matrix);
        try shader.bind();
        // Engine.Shader.set_matrix(0, engine.camera.projection_matrix);

        // Engine.Shader.set_vec3(0, motion);
        // Engine.Shader.set_matrix(1, engine.camera.projection_matrix);
        // Engine.Shader.set_matrix(2, engine.camera.view_matrix);
        try shader.set_uniform("_offset", motion);
        try shader.set_uniform("_p", engine.camera.projection_matrix);
        try shader.set_uniform("_v", engine.camera.view_matrix);

        try mesh2.bind();
        try engine.update_time();
    }
}

fn game_loop() void {}
