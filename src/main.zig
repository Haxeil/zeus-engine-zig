const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const String = @import("zig_string.zig").String;
const Engine = @import("engine.zig");
pub const math = @import("math/main.zig");

pub fn main() !void {
    var engine = try Engine.Engine.init(1200, 800, "zeus-zig | frames: {0} , updates: {0}, delta: {0}");
    defer engine.deinit();

    engine.camera.projection_matrix = math.Mat4x4.perspective(math.degreesToRadians(f32, 90), 1, -1.1, 10_000);
    var cam_offset = math.vec3(0, 0, 10);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("memory leak");
        }
    }

    const vertices = [_]f32{
        -0.5, -0.5, 0.0,
        0.5,  -0.5, 0.0,
        0.0,  0.5,  0.0,
    };

    const indicies = [_]u32{
        0, 1, 2,
    };

    //Mesh
    var mesh = Engine.Mesh.init(allocator);
    defer mesh.deinit();
    mesh.copy_data(&vertices, &indicies) catch {};
    mesh.create();

    var mesh2 = Engine.Mesh.init(allocator);
    defer mesh2.deinit();
    mesh2.vertices.appendSlice(&.{
        // front
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  1.0,
        // back
        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        -1.0, 1.0,  -1.0,
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
    mesh2.create();
    //Shader
    var shader = Engine.Shader.init("shader/vertex.glsl", "shader/fragment.glsl");

    defer shader.deinit();
    shader.comptile();

    var motion = math.vec3(0, 0, 0);

    var speed: f32 = 2;

    while (engine.is_running()) {
        if (engine.window.?.getKey(.w) == glfw.Action.press) {
            cam_offset.v[2] -= 0.1 * engine.engine_time.?.delta * speed;
        } else if (engine.window.?.getKey(.s) == glfw.Action.press) {
            cam_offset.v[2] += 0.1 * engine.engine_time.?.delta * speed;
        }

        if (engine.window.?.getKey(.d) == glfw.Action.press) {
            cam_offset.v[0] -= 0.1 * engine.engine_time.?.delta * speed;
        } else if (engine.window.?.getKey(.a) == glfw.Action.press) {
            cam_offset.v[0] += 0.1 * engine.engine_time.?.delta * speed;
        }

        const motion_matrix = math.Mat4x4.translate(cam_offset);
        engine.camera.view_matrix = math.Mat4x4.ident.mul(&motion_matrix);
        shader.bind();
        // Engine.Shader.set_matrix(0, engine.camera.projection_matrix);
        const time: f32 = @floatCast(glfw.getTime());
        motion.v[0] = math.sin(time);
        Engine.Shader.set_vec3(0, motion);
        Engine.Shader.set_matrix(1, engine.camera.projection_matrix);
        Engine.Shader.set_matrix(2, engine.camera.view_matrix);

        mesh.bind();
        mesh2.bind();
        try engine.update_time();
    }
}
