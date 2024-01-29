const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const time = @import("time.zig");
const math = @import("math/main.zig");

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

pub const Engine = struct {
    window: ?glfw.Window = undefined,
    camera: Camera = .{},

    engine_time: ?time.EngineTime = undefined,
    timer: ?std.time.Timer = undefined,

    const Self = @This();

    pub fn init(width: u32, height: u32, comptime title: [*:0]const u8) !Engine {
        glfw.setErrorCallback(errorCallback);

        if (!glfw.init(.{})) {
            std.log.err("initializing glfw failed : {?s}", .{glfw.getErrorString()});
        }

        var window = glfw.Window.create(width, height, title, null, null, .{});

        glfw.makeContextCurrent(window);

        const proc: glfw.GLProc = undefined;
        try gl.load(proc, glGetProcAddress);

        return .{
            .window = window,
            .engine_time = try time.EngineTime.init(),
            .timer = try std.time.Timer.start(),
        };
    }

    pub fn is_running(self: *Self) bool {
        self.window.?.swapBuffers();
        glfw.pollEvents();
        gl.clear(gl.COLOR_BUFFER_BIT);
        self.engine_time.?.update() catch {};

        gl.viewport(0, 0, @intCast(self.window.?.getSize().width), @intCast(self.window.?.getSize().height));

        while (self.engine_time.?.delta >= 1) {
            self.engine_time.?.updates += 1;
            self.engine_time.?.delta -= 1;

            gl.clearColor(0.4, 1.0, 0.3, 0.1);
        }

        return !self.window.?.shouldClose();
    }

    pub fn update_time(self: *Self) !void {
        self.engine_time.?.frames += 1;
        var allocator = std.heap.page_allocator;
        if (self.timer.?.read() / 1_000_000 > 1_000) {
            self.timer.?.reset();

            var raw_string = try std.fmt.allocPrintZ(allocator, "zeus-zig | frames: {d} , updates: {d}, delta: {d} ", .{
                self.engine_time.?.frames,
                self.engine_time.?.updates,
                self.engine_time.?.delta,
            });

            defer allocator.free(raw_string);

            self.window.?.setTitle(raw_string);
            self.engine_time.?.updates = 0;
            self.engine_time.?.frames = 0;
        }
    }

    pub fn deinit(self: Self) void {
        self.window.?.destroy();
    }
};

pub const Camera = struct {
    projection_matrix: math.Mat4x4 = math.Mat4x4.ident,
};

pub const Mesh = struct {
    const ArrayList = std.ArrayList;

    vertices: ArrayList(f32),
    indices: ArrayList(u32),

    vao: u32 = undefined,
    vbo: u32 = undefined,
    ibo: u32 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Mesh {
        return .{
            .vertices = ArrayList(f32).init(allocator),
            .indices = ArrayList(u32).init(allocator),
        };
    }

    pub fn create(self: *Self) void {
        gl.genVertexArrays(1, &self.vao);

        gl.genBuffers(1, &self.vbo);

        gl.genBuffers(1, &self.ibo);

        gl.bindVertexArray(self.vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(u32) * self.vertices.items.len), self.vertices.items.ptr, gl.STATIC_DRAW);

        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
        gl.enableVertexAttribArray(0);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ibo);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * self.indices.items.len), self.indices.items.ptr, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);
    }

    pub fn bind(self: *Self) void {
        gl.bindVertexArray(self.vao);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ibo);

        gl.drawElements(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null);
    }

    pub fn deinit(self: *Self) void {
        // gl.deleteVertexArrays(1, self.vao);
        // gl.deleteBuffers(1, self.vbo);
        // gl.deleteBuffers(1, self.ibo);
        self.vertices.deinit();
        self.indices.deinit();
    }

    pub fn copy_data(self: *Self, vertices: []const f32, indicies: []const u32) !void {
        try self.vertices.appendSlice(vertices);
        try self.indices.appendSlice(indicies);
    }
};

pub const Shader = struct {
    program: u32 = undefined,

    vertex_source: []const u8,
    fragment_source: []const u8,

    vertex_shader: u32 = undefined,
    fragment_shader: u32 = undefined,

    const Self = @This();

    pub fn init(comptime vertex_path: []const u8, comptime fragment_path: []const u8) Shader {
        return .{
            .vertex_source = @embedFile(vertex_path),
            .fragment_source = @embedFile(fragment_path),
        };
    }

    pub fn comptile(self: *Self) void {
        self.vertex_shader = gl.createShader(gl.VERTEX_SHADER);

        gl.shaderSource(self.vertex_shader, 1, &self.vertex_source.ptr, null);
        gl.compileShader(self.vertex_shader);

        self.fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(self.fragment_shader, 1, &self.fragment_source.ptr, null);
        gl.compileShader(self.fragment_shader);

        self.program = gl.createProgram();

        gl.attachShader(self.program, self.vertex_shader);
        gl.attachShader(self.program, self.fragment_shader);
        gl.linkProgram(self.program);

        //defer gl.deleteProgram(shader_program);

    }

    pub fn bind(self: Self) void {
        gl.useProgram(self.program);
    }

    pub fn deinit(self: *Self) void {
        gl.deleteShader(self.vertex_shader);
        gl.deleteShader(self.fragment_shader);
    }

    pub fn set_vec3(uniform_location: i32, vec: math.Vec3) void {
        gl.uniform3fv(uniform_location, 1, &vec.v[0]);
    }

    pub fn set_matrix(uniform_location: i32, matrix: math.Mat4x4) void {
        gl.uniformMatrix4fv(uniform_location, 1, gl.FALSE, &matrix.v[0].v[0]);
    }
};
