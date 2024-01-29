const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const String = @import("zig_string.zig").String;
const Engine = @import("engine.zig");
pub const math = @import("math/main.zig");

pub fn main() !void {
    var engine = try Engine.Engine.init(1200, 800, "zeus-zig | frames: {0} , updates: {0}, delta: {0}");
    defer engine.deinit();

    const v = .{
        .left = -10,
        .right = 10,
        .bottom = -10,
        .top = 10,
        .near = -100,
        .far = 10_000,
    };
    engine.camera.projection_matrix = math.Mat4x4.projection2D(v);

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

    while (engine.is_running()) {
        shader.bind();
        // Engine.Shader.set_matrix(0, engine.camera.projection_matrix);
        const time: f32 = @floatCast(glfw.getTime());
        motion.v[0] = math.sin(time);
        Engine.Shader.set_vec3(0, motion);
        Engine.Shader.set_matrix(1, engine.camera.projection_matrix);

        mesh.bind();
        mesh2.bind();
        try engine.update_time();
    }
}
