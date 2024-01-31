const std = @import("std");
const time = std.time;

const NS_PER_FPS: f32 = 1_000_000_000.0 / 60.0;

pub const EngineTime = struct {
    delta: f32,
    frames: u32,
    updates: u32,
    last_time: time.Timer,

    const Self = @This();

    pub fn init() !Self {
        return .{
            .delta = 0.0,
            .frames = 0,
            .updates = 0,
            .last_time = try time.Timer.start(),
        };
    }

    pub fn update(self: *Self) !void {
        var now = try time.Timer.start();

        self.delta += @as(f32, @floatFromInt(self.last_time.read() - now.read())) / NS_PER_FPS;
    }
};
