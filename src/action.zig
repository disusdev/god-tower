const std = @import("std");

//const FnPtr = fn (dt: f32) bool;

pub const Action = struct {
    name: []const u8,
    preconditions: std.StringHashMap(bool),
    effects: std.StringHashMap(bool),
    cost: f64,
    //func: ?FnPtr = null,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, cost: f64) Action {
        return Action{
            .name = name,
            .preconditions = std.StringHashMap(bool).init(allocator),
            .effects = std.StringHashMap(bool).init(allocator),
            .cost = cost,
        };
    }

    pub fn addPrecondition(self: *Action, key: []const u8, value: bool) void {
        self.preconditions.put(key, value) catch unreachable;
    }

    pub fn addEffect(self: *Action, key: []const u8, value: bool) void {
        self.effects.put(key, value) catch unreachable;
    }
};