const std = @import("std");
const print = std.debug.print;
const raylib = @import("rl.zig");

pub fn shader_load(path: []const u8, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var shader_src = std.ArrayList(u8).init(allocator);

    var file = try std.fs.cwd().openFile(path, .{});

    const str = try file.readToEndAlloc(allocator, try file.getEndPos());
    defer allocator.free(str);
    
    const key = "#include";
    var splits = std.mem.split(u8, str, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) continue;

        if (std.mem.startsWith(u8, line, key)) {
            if (std.mem.indexOf(u8, line, "<")) |index1| {
                if (std.mem.indexOf(u8, line, ">")) |index2| {
                    const fpath = line[index1 + 1 .. index2];
                    const include = try shader_load(fpath, allocator);
                    try shader_src.appendSlice(include.items);
                    include.deinit();
                }
            }
            continue;
        }

        try shader_src.appendSlice(line[0 .. line.len]);
        try shader_src.append('\n');
    }
    
    return shader_src;
}

fn compile(path: []const u8,
           shader_type: i32,
           allocator: std.mem.Allocator) !?u32 {
    var src = try shader_load(path, allocator);
    defer src.deinit();
    try src.append('\x00');
    
    const shader_id = raylib.rlCompileShader(@ptrCast(src.items.ptr), shader_type);
    if (shader_id == 0) {
        return null;
    }
    return shader_id;
}

pub const Shader = struct {
    id: u32,
    vs: u32,
    fs: u32,
    vs_path: []const u8,
    fs_path: []const u8,
    vs_mod: i64,
    fs_mod: i64,
    locs: [32]i32 = undefined,
    
    const ShaderError = error {
        VertexCopilation,
        FragmentCopilation,
        Link,
    };
    
    fn init(vs_path: []const u8,
            fs_path: []const u8,
            allocator: std.mem.Allocator) !Shader {
        var vs_id: u32 = undefined;
        var fs_id: u32 = undefined;
        
        if (try compile(vs_path, raylib.RL_VERTEX_SHADER, allocator)) |id| {
            vs_id = id;
        } else {
            return ShaderError.VertexCopilation;
        }
        
        if (try compile(fs_path, raylib.RL_FRAGMENT_SHADER, allocator)) |id| {
            fs_id = id;
        } else {
            return ShaderError.FragmentCopilation;
        }
        
        const id = raylib.rlLoadShaderProgram(vs_id, fs_id);
        if (id == 0) {
            return ShaderError.Link;
        }
        
        var shader = Shader {
            .id = id,
            .vs = vs_id,
            .fs = fs_id,
            .vs_path = vs_path,
            .fs_path = fs_path,
            .vs_mod = raylib.GetFileModTime(@ptrCast(vs_path.ptr)),
            .fs_mod = raylib.GetFileModTime(@ptrCast(fs_path.ptr)),
        };
        
        @memset(shader.locs[0..], -1);
        
        // Get handles to GLSL input attribute locations
        shader.locs[raylib.SHADER_LOC_VERTEX_POSITION] = raylib.rlGetLocationAttrib(id, "vertexPosition");
        shader.locs[raylib.SHADER_LOC_VERTEX_TEXCOORD01] = raylib.rlGetLocationAttrib(id, "vertexTexCoord");
        shader.locs[raylib.SHADER_LOC_VERTEX_TEXCOORD02] = raylib.rlGetLocationAttrib(id, "vertexTexCoord2");
        shader.locs[raylib.SHADER_LOC_VERTEX_NORMAL] = raylib.rlGetLocationAttrib(id, "vertexNormal");
        shader.locs[raylib.SHADER_LOC_VERTEX_TANGENT] = raylib.rlGetLocationAttrib(id, "vertexTangent");
        shader.locs[raylib.SHADER_LOC_VERTEX_COLOR] = raylib.rlGetLocationAttrib(id, "vertexColor");

        // Get handles to GLSL uniform locations (vertex shader)
        shader.locs[raylib.SHADER_LOC_MATRIX_MVP] = raylib.rlGetLocationUniform(id, "mvp");
        shader.locs[raylib.SHADER_LOC_MATRIX_VIEW] = raylib.rlGetLocationUniform(id, "matView");
        shader.locs[raylib.SHADER_LOC_MATRIX_PROJECTION] = raylib.rlGetLocationUniform(id, "matProjection");
        shader.locs[raylib.SHADER_LOC_MATRIX_MODEL] = raylib.rlGetLocationUniform(id, "matModel");
        shader.locs[raylib.SHADER_LOC_MATRIX_NORMAL] = raylib.rlGetLocationUniform(id, "matNormal");

        // Get handles to GLSL uniform locations (fragment shader)
        shader.locs[raylib.SHADER_LOC_COLOR_DIFFUSE] = raylib.rlGetLocationUniform(id, "colDiffuse");
        shader.locs[raylib.SHADER_LOC_MAP_DIFFUSE] = raylib.rlGetLocationUniform(id, "texture0");  // SHADER_LOC_MAP_ALBEDO
        shader.locs[raylib.SHADER_LOC_MAP_SPECULAR] = raylib.rlGetLocationUniform(id, "texture1"); // SHADER_LOC_MAP_METALNESS
        shader.locs[raylib.SHADER_LOC_MAP_NORMAL] = raylib.rlGetLocationUniform(id, "texture2");
        
        return shader;
    }
    
    fn is_outdated(self: Shader) bool {
        const vs_mod = raylib.GetFileModTime(@ptrCast(self.vs_path.ptr));
        if (vs_mod != self.vs_mod) {
            return true;
        }
        const fs_mod = raylib.GetFileModTime(@ptrCast(self.fs_path.ptr));
        if (fs_mod != self.fs_mod) {
            return true;
        }
        return false;
    }
    
    pub fn set_value(self: Shader, name: []const u8, value: i32) void {
        const loc = raylib.rlGetLocationUniform(self.id, name.ptr);
        if (loc != -1) {
            raylib.rlEnableShader(self.id);
            raylib.rlSetUniform(loc, &value, raylib.SHADER_UNIFORM_INT, 1);
        }
    }
};

pub const ShaderLib = struct {
    allocator: std.mem.Allocator,
    shaders: std.ArrayList(Shader),
    
    pub fn init(allocator: std.mem.Allocator) ShaderLib {
        return ShaderLib {
            .allocator = allocator,
            .shaders = std.ArrayList(Shader).init(allocator),
        };
    }
    
    pub fn update(self: *ShaderLib) !void {
        for (self.shaders.items, 0..) |shader, i| {
            if (shader.is_outdated()) {
                const new_shader = Shader.init(shader.vs_path, shader.fs_path, self.allocator) catch |err| {
                    print("[ERROR] {any}\n", .{err});
                    return err;
                };
                // @todo unload previouse shader program
                self.shaders.items[i] = new_shader;
            }
        }
    }
    
    pub fn put(self: *ShaderLib,
               vs_path: []const u8,
               fs_path: []const u8) !u64 {
        const idx = self.shaders.items.len;
        const shader = try Shader.init(vs_path, fs_path, self.allocator);
        try self.shaders.append(shader);
        return idx;
    }
    
    pub fn get(self: *ShaderLib,
               idx: u64) Shader {
        const shader = self.shaders.items[idx];
        return shader;
        // raylib.Shader {
        //     .id = shader.id,
        //     .locs = @ptrCast(&shader.locs),
        // };
    }
};

pub var shader_lib: ShaderLib = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    shader_lib = ShaderLib.init(allocator);
}