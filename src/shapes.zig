const std = @import("std");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;
const Vertex = _engine.Vertex;
pub const math = @import("math/main.zig");

fn tof32(value: anytype) f32 {
    return @as(f32, @floatFromInt(value));
}

fn circle_points(points: []math.Vec3, sides: u32, radius: f32) !void {
    if (points.len != sides + 1)
        @panic("Points slice must be sides + 1");

    for (0..sides + 1) |i| {
        var theta = tof32(i) * 2 * math.pi / tof32(sides);
        var ci = math.vec3(@cos(theta) * radius, 0, @sin(theta) * radius);
        points[i] = ci;
    }
}

pub fn sphere(mesh: *Mesh, radial_segments: i32, vertical_segments: i32, radius: f32) !void {
    const rad_segs: u32 = @intCast(if (radial_segments < 3) 3 else radial_segments);
    const vert_segs: u32 = @intCast(if (vertical_segments < 3) 3 else vertical_segments);

    const vCt: u32 = @intCast(mesh.vertices.items.len);

    for (0..(vert_segs + 1)) |v| {
        const height = -@cos(tof32(v) / tof32(vert_segs) * std.math.pi) * radius;
        const ring_radius = @sin(tof32(v) / tof32(vert_segs) * std.math.pi) * radius;

        var buffer = try std.BoundedArray(math.Vec3, 256).init(rad_segs + 1);
        try circle_points(buffer.slice(), rad_segs, ring_radius);

        for (0..rad_segs + 1) |i| {
            buffer.slice()[i].v[1] += height;

            const texU: f32 = tof32(i) / tof32(rad_segs + 1);
            const texV: f32 = tof32(v) / tof32(vert_segs + 1);

            try mesh.vertices.append(Vertex{
                .position = buffer.slice()[i],
                .uv = math.vec2(texU, texV),
            });
        }
    }

    for (mesh.vertices.items) |*vertex| {
        vertex.normal = vertex.position.normalize(1);
    }

    var r: u32 = 0;
    while (r < rad_segs) : (r += 1) {
        var v: u32 = 0;
        while (v < vert_segs) : (v += 1) {
            const v0 = vCt + ((rad_segs + 1) * v) + r;
            const v1 = vCt + ((rad_segs + 1) * v) + r + 1;
            const v2 = v0 + (rad_segs + 1);
            const v3 = v1 + (rad_segs + 1);

            try mesh.indices.appendSlice(&.{
                v0, v1, v2,
                v1, v3, v2,
            });
        }
    }
}

pub fn quad(mesh: *Mesh) !void {
    const v3 = math.vec3;
    const v2 = math.vec2;

    const i: u32 = @intCast(mesh.vertices.items.len);

    const norm = math.vec3(0, 0, -1);

    try mesh.vertices.appendSlice(&.{
        .{ .position = v3(0, 0, 0), .uv = v2(0, 0), .normal = norm },
        .{ .position = v3(1, 0, 0), .uv = v2(1, 0), .normal = norm },
        .{ .position = v3(0, 1, 0), .uv = v2(0, 1), .normal = norm },
        .{ .position = v3(1, 1, 0), .uv = v2(1, 1), .normal = norm },
    });

    try mesh.indices.appendSlice(&.{
        i + 0, i + 1, i + 2,
        i + 1, i + 3, i + 2,
    });
}
