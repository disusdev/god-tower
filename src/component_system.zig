const std = @import("std");
const meta = std.meta;
const rl = @import("rl.zig");

pub const Entity = struct {
    name: [128:0]u8 = undefined,
    components: std.StringHashMap(u64) = undefined,
    hierarchy: Hierarchy = undefined,
    enable: bool = true,

    pub fn create(parent: ?u64) !EntityHandle {
        var entity = Entity {};

        const entity_id = states.items[current_state].entities.items.len;
        _ = try std.fmt.bufPrint(&entity.name, "default_{d}", .{entity_id});

        entity.components = std.StringHashMap(u64).init(allocator);

        const depth = calculate_depth(parent);
        const hierarchy = Hierarchy {
            .id = entity_id,
            .parent_id = parent,
            .depth = depth,
            .left_sibling = find_left(depth, parent),
            .right_sibling = null,
            .first_child = null,
        };

        if (hierarchy.left_sibling) |left| {
            states.items[current_state].entities.items[left].hierarchy.right_sibling = hierarchy.id;
        } else if (parent) |id| {
            states.items[current_state].entities.items[id].hierarchy.first_child = hierarchy.id;
        }

        if (hierarchy.left_sibling) |id| {
            if (id == entity_id) {
                std.debug.panic("We in trouble!\n", .{});
            }
        }

        entity.hierarchy = hierarchy;

        try states.items[current_state].entities.append(entity);
        try states.items[current_state].locals.append(rl.MatrixIdentity());
        try states.items[current_state].globals.append(calculate_global_transform(entity_id));

        return .{ .id = entity_id };
    }
};

pub const EntityHandle = struct {
    id: u64,
    
    pub fn set_enable(self: EntityHandle, enable: bool) void {
        states.items[current_state].entities.items[self.id].enable = enable;
    }
    
    pub fn get_enable(self: EntityHandle) bool {
        return states.items[current_state].entities.items[self.id].enable;
    }
    
    pub fn set_parent(self: EntityHandle, other: ?EntityHandle) void {
        // @todo make it work with siblings
        if (states.items[current_state].entities.items[self.id].hierarchy.parent_id) |id| {
            states.items[current_state].entities.items[id].hierarchy.first_child = self.id;
        }
        if (other) |o| {
            states.items[current_state].entities.items[self.id].hierarchy.parent_id = o.id;
            states.items[current_state].entities.items[o.id].hierarchy.first_child = self.id;
        } else {
            states.items[current_state].entities.items[self.id].hierarchy.parent_id = null;
        }
    }
    
    pub inline fn get_component(self: EntityHandle, comptime T: type) ?T {
        if (states.items[current_state].entities.items[self.id].components.get(@typeName(T))) |id| {
            return T {
                .id = id,
            };
        }
        return null;
    }
    
    pub fn add_component(self: EntityHandle, comptime T: type, component: T) void {
        states.items[current_state].entities.items[self.id].components.put(@typeName(T), component.id) catch {
            @panic("add_component");
        };
    }

    pub fn get_child(self: EntityHandle) ?EntityHandle {
        if (states.items[current_state].entities.items[self.id].hierarchy.first_child) |child| {
            return .{ .id = child };
        }
        return null;
    }

    pub fn set_pos(self: EntityHandle, x: f32, y: f32) void {
        states.items[current_state].locals.items[self.id].m12 = x;
        states.items[current_state].locals.items[self.id].m13 = y;
        states.items[current_state].update_transforms();
    }

    pub fn get_pos(self: EntityHandle) rl.Vector2 {
        const x = states.items[current_state].globals.items[self.id].m12;
        const y = states.items[current_state].globals.items[self.id].m13;
        return .{.x=x,.y=y};
    }

    pub fn get_rot(self: EntityHandle) f32 {
        const rotation = rl.atan2f(states.items[current_state].globals.items[self.id].m1,
                                   states.items[current_state].globals.items[self.id].m0);
        return rotation * rl.RAD2DEG;
    }

    pub fn rotate(self: EntityHandle, delta: f32) void {
        const x = states.items[current_state].locals.items[self.id].m12;
        const y = states.items[current_state].locals.items[self.id].m13;
        states.items[current_state].locals.items[self.id].m12 = 0;
        states.items[current_state].locals.items[self.id].m13 = 0;

        states.items[current_state].locals.items[self.id] = rl.MatrixMultiply(states.items[current_state].local_transforms.items[self.id],
                                                                              rl.MatrixRotateZ(delta * rl.DEG2RAD));

        states.items[current_state].locals.items[self.id].m12 = x;
        states.items[current_state].locals.items[self.id].m13 = y;

        states.items[current_state].update_transforms();
    }

    pub fn set_rot(self: EntityHandle, rot: f32) void {
        const x = states.items[current_state].locals.items[self.id].m12;
        const y = states.items[current_state].locals.items[self.id].m13;
        states.items[current_state].locals.items[self.id].m12 = 0;
        states.items[current_state].locals.items[self.id].m13 = 0;

        states.items[current_state].locals.items[self.id] = rl.MatrixRotateZ(rot * rl.DEG2RAD);

        states.items[current_state].locals.items[self.id].m12 = x;
        states.items[current_state].locals.items[self.id].m13 = y;

        states.items[current_state].update_transforms();
    }
};

const Hierarchy = struct {
    id: u64,
    depth: u64,
    parent_id: ?u64,
    left_sibling: ?u64,
    right_sibling: ?u64,
    first_child: ?u64,
};

const ComponentSystemState = struct {
    entities: std.ArrayList(Entity),
    locals: std.ArrayList(rl.Matrix),
    globals: std.ArrayList(rl.Matrix),

    // @todo add later
    // changed_this_frame: std.ArrayList(u64),
    // remove_this_frame: std.ArrayList(i32),
    // entity_pool: std.ArrayList(i32),

    fn update_transforms(self: *ComponentSystemState) void {
        for (self.globals.items, 0..) |_, i| {
            self.globals.items[i] = calculate_global_transform(i);
        }
    }
};

pub var current_state: u64 = 0;
pub var states: std.ArrayList(ComponentSystemState) = undefined;
pub var allocator: std.mem.Allocator = undefined;

pub fn init(_allocator: std.mem.Allocator) void {
    allocator = _allocator;
    states = std.ArrayList(ComponentSystemState).init(allocator);
}

pub fn add_new_state() !u64 {
    try states.append(.{
        .entities = std.ArrayList(Entity).init(allocator),
        .locals = std.ArrayList(rl.Matrix).init(allocator),
        .globals = std.ArrayList(rl.Matrix).init(allocator),
    });
    return states.items.len - 1;
}

fn calculate_depth(id: ?u64) u64 {
  var depth: u64 = 0;
  var index: ?u64 = id;
  while (index != null) {
    depth += 1;
    index = states.items[current_state].entities.items[index.?].hierarchy.parent_id;
  }
  return depth;
}

fn find_left(depth: u64, parent: ?u64) ?u64 {
    var sibling: ?u64 = null;
    for(states.items[current_state].entities.items, 0..) |entity, i| {
        if (entity.hierarchy.depth == depth and
            entity.hierarchy.parent_id == parent and
            entity.hierarchy.right_sibling == null) {
                sibling = i;
                break;
        }
    }
    return sibling;
}

fn calculate_global_transform(id: u64) rl.Matrix {
    var global = rl.MatrixIdentity();
    var index: ?u64 = id;
    while (index != null) {
      const local = states.items[current_state].locals.items[index.?];
      global = rl.MatrixMultiply(global, local);
      index = states.items[current_state].entities.items[index.?].hierarchy.parent_id;
    }
    return global;
}
