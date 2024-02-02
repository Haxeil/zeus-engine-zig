const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const time = @import("time.zig");
const math = @import("math/main.zig");
const c = @cImport({
    @cInclude("stb_image.h");
});

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
    timer: f64 = 0.0,

    const Error = error{
        GLError,
    };

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

        var engine = Engine{
            .window = window,
            .engine_time = try time.EngineTime.init(),
            .timer = @floatFromInt(std.time.milliTimestamp()),
        };

        std.debug.print("timer: {}", .{engine.timer});
        engine.camera.engine = &engine;

        engine.camera.update_projection_matrix();

        return engine;
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

            gl.clearColor(0.960, 0.960, 0.960, 1);
        }

        return !self.window.?.shouldClose();
    }

    pub fn update_time(self: *Self) !void {
        self.engine_time.?.frames += 1;
        var allocator = std.heap.page_allocator;

        if ((@as(f64, @floatFromInt(std.time.milliTimestamp())) - self.timer) >= 1_000) {
            self.timer += 1_000;
            // not working
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
    view_matrix: math.Mat4x4 = math.Mat4x4.ident,
    engine: *Engine = undefined,

    near_plane: f32 = -1 + 0.1,
    far_plane: f32 = 1_000,
    fov: f32 = 75,
    aspect_ration: f32 = 1,

    pub fn update_projection_matrix(self: *Camera) void {
        const width = glfw.Window.getSize(self.engine.window.?).width;
        const height = glfw.Window.getSize(self.engine.window.?).height;

        self.aspect_ration = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

        self.projection_matrix = math.Mat4x4.perspective(
            math.degreesToRadians(f32, self.fov),
            self.aspect_ration,
            self.near_plane,
            self.far_plane,
        );
    }
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

    pub fn create(self: *Self) !void {
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

        try gl_log();
    }

    pub fn bind(self: *Self) !void {
        gl.bindVertexArray(self.vao);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ibo);

        gl.drawElements(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null);

        try gl_log();
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

    const Error = error{
        VertexShaderCompilation,
        FragmentShaderCompilation,
        InvalidUniformName,
    };

    const Self = @This();

    pub fn init(comptime vertex_path: []const u8, comptime fragment_path: []const u8) Shader {
        return .{
            .vertex_source = @embedFile(vertex_path),
            .fragment_source = @embedFile(fragment_path),
        };
    }

    pub fn comptile(self: *Self) !void {
        self.vertex_shader = gl.createShader(gl.VERTEX_SHADER);

        var error_log: [512]u8 = [_]u8{0} ** 512;

        var success: i32 = undefined;

        gl.shaderSource(self.vertex_shader, 1, &self.vertex_source.ptr, null);
        gl.compileShader(self.vertex_shader);
        gl.getShaderiv(self.vertex_shader, gl.COMPILE_STATUS, &success);
        //fail to compile
        if (success == 0) {
            gl.getShaderInfoLog(self.vertex_shader, 512, null, error_log[0..]);
            std.log.err("vertex shader err: \n{s}", .{error_log});
            return Error.VertexShaderCompilation;
        }

        self.fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(self.fragment_shader, 1, &self.fragment_source.ptr, null);
        gl.compileShader(self.fragment_shader);

        gl.getShaderiv(self.fragment_shader, gl.COMPILE_STATUS, &success);
        //fail to compile
        if (success == 0) {
            gl.getShaderInfoLog(self.fragment_shader, 512, null, error_log[0..]);
            std.log.err("fragmen shader err: \n{s}", .{error_log});
            return Error.FragmentShaderCompilation;
        }

        self.program = gl.createProgram();

        gl.attachShader(self.program, self.vertex_shader);
        gl.attachShader(self.program, self.fragment_shader);
        gl.linkProgram(self.program);

        try gl_log();
        //defer gl.deleteProgram(shader_program);

    }

    pub fn bind(self: Self) !void {
        gl.useProgram(self.program);
        try gl_log();
    }

    pub fn deinit(self: *Self) void {
        gl.deleteShader(self.vertex_shader);
        gl.deleteShader(self.fragment_shader);
    }

    // pub fn set_vec3(uniform_location: i32, vec: math.Vec3) void {
    //     gl.uniform3fv(uniform_location, 1, &vec.v[0]);
    // }

    // pub fn set_matrix(uniform_location: i32, matrix: math.Mat4x4) void {
    //     gl.uniformMatrix4fv(uniform_location, 1, gl.FALSE, &matrix.v[0].v[0]);
    // }

    pub fn set_uniform(self: Self, uniform: [*c]const u8, value: anytype) !void {
        // gets location of uniform from a string
        const location: i32 = gl.getUniformLocation(self.program, uniform);
        // checks if the index is valid (uniform found !)
        if (location == -1) return Error.InvalidUniformName;

        switch (@TypeOf(value)) {
            i32 => gl.uniform1i(location, value),
            f32 => gl.uniform1f(location, value),
            math.Vec2 => gl.uniform2fv(location, 1, &value.v[0]),
            math.Vec3 => gl.uniform3fv(location, 1, &value.v[0]),
            math.Vec4 => gl.uniform4fv(location, 1, &value.v[0]),
            math.Mat4x4 => gl.uniformMatrix4fv(location, 1, gl.FALSE, &value.v[0].v[0]),
            else => {
                @compileError("unsupported type: " ++ @typeName(value));
            },
        }
        try gl_log();
    }
};

pub const Texture = struct {
    texture_coords: []f32 = [_]f32{
        0.0, 0.0, // lower-left corner
        1.0, 0.0, // lower-right corner
        0.5, 1.0, // top-center corner
    },
};

pub fn gl_log() !void {
    var err: gl.GLenum = gl.getError();
    const has_err = err != gl.getError();
    while (err != gl.NO_ERROR) {
        var err_string = switch (err) {
            gl.INVALID_ENUM => "INVALID_ENUM",
            gl.INVALID_VALUE => "INVALID_VALUE",
            gl.INVALID_OPERATION => "INVALID_OPERATION",
            gl.OUT_OF_MEMORY => "OUT_OF_MEMORY",
            gl.INVALID_FRAMEBUFFER_OPERATION => "INVALID_FRAMEBUFFER_OPERATION",
            else => "UNKNOWN_OPENGL_ERROR",
        };

        std.log.err("Found OpenGL error: {s}", .{err_string});

        err = gl.getError();
    }

    if (has_err) return Engine.Error.GLError;
}
