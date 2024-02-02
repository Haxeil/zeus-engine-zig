const std = @import("std");
const time = std.time;

const NS_PER_FPS: f64 = 1_000_000_000.0 / 900.0;

pub const EngineTime = struct {
    delta: f32,
    frames: u32,
    updates: u32,
    get_timer: *time.Timer,
    last_time: f64,

    const Self = @This();

    pub fn init(get_timer: *time.Timer) !Self {
        return .{
            .delta = 0.0,
            .frames = 0,
            .updates = 0,
            .get_timer = get_timer,
            .last_time = @as(f64, @floatFromInt(time.nanoTimestamp())),
        };
    }

    pub fn update(self: *Self) !void {
        var now: f64 = @as(f64, @floatFromInt(time.nanoTimestamp()));

        self.delta += @floatCast((now - self.last_time) / NS_PER_FPS);
        self.last_time = now;
    }
};
