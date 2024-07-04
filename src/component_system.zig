const std = @import("std");
const rl = @import("rl.zig");
const RenderSystem = @import("render_system.zig");
const AbilitySystem = @import("ability_system.zig");
const Physics = @import("physics.zig");
const Box = @import("box2d.zig");
const AnimationSystem = @import("animation_system.zig");

pub const Entity = struct {
    name: [128:0]u8 = undefined, // 128
    components: std.StringHashMap(?Component) = undefined,
    hierarchy: Hierarchy = undefined, // 48
    enable: bool = true, // 1

    pub fn create(parent: ?u64) !EntityHandle {
        var entity = Entity {};

        const entity_id = states.items[current_state].entities.items.len;
        _ = try std.fmt.bufPrint(&entity.name, "default_{d}", .{entity_id});

        entity.components = std.StringHashMap(?Component).init(allocator);

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
        try states.items[current_state].local_transforms.append(rl.MatrixIdentity());
        try states.items[current_state].global_transforms.append(calculate_global_transform(entity_id));

        return .{ .id = entity_id };
    }
};

pub const EntityHandle = struct {
    id: u64,

    pub fn add_component(self: *EntityHandle, key: []const u8, component: Component) !void {
        try states.items[current_state].entities.items[self.id].components.put(key, component);
    }

    pub fn get_component(self: *EntityHandle, key: []const u8) ?Component {
        if (states.items[current_state].entities.items[self.id].components.get(key)) |comp| {
            return comp;
        }
        return null;
    }

    pub fn set_pos(self: *EntityHandle, x: f32, y: f32) void {
        states.items[current_state].local_transforms.items[self.id].m12 = x;
        states.items[current_state].local_transforms.items[self.id].m13 = y;
        states.items[current_state].update_transforms();
    }

    pub fn get_pos(self: EntityHandle) rl.Vector2 {
        const x = states.items[current_state].global_transforms.items[self.id].m12;
        const y = states.items[current_state].global_transforms.items[self.id].m13;
        return .{.x=x,.y=y};
    }

    pub fn get_rot(self: EntityHandle) f32 {
        const rotation = rl.atan2f(states.items[current_state].global_transforms.items[self.id].m1, states.items[current_state].global_transforms.items[self.id].m0);
        return rotation * rl.RAD2DEG;
    }

    pub fn rotate(self: EntityHandle, delta: f32) void {
        const x = states.items[current_state].local_transforms.items[self.id].m12;
        const y = states.items[current_state].local_transforms.items[self.id].m13;
        states.items[current_state].local_transforms.items[self.id].m12 = 0;
        states.items[current_state].local_transforms.items[self.id].m13 = 0;

        states.items[current_state].local_transforms.items[self.id] = rl.MatrixMultiply(states.items[current_state].local_transforms.items[self.id], rl.MatrixRotateZ(delta * rl.DEG2RAD));

        states.items[current_state].local_transforms.items[self.id].m12 = x;
        states.items[current_state].local_transforms.items[self.id].m13 = y;

        states.items[current_state].update_transforms();
    }

    pub fn set_rot(self: EntityHandle, rot: f32) void {
        const x = states.items[current_state].local_transforms.items[self.id].m12;
        const y = states.items[current_state].local_transforms.items[self.id].m13;
        states.items[current_state].local_transforms.items[self.id].m12 = 0;
        states.items[current_state].local_transforms.items[self.id].m13 = 0;

        states.items[current_state].local_transforms.items[self.id] = rl.MatrixRotateZ(rot * rl.DEG2RAD);

        states.items[current_state].local_transforms.items[self.id].m12 = x;
        states.items[current_state].local_transforms.items[self.id].m13 = y;

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

pub const Component = union {
    renderer: RenderSystem.RendererHandle,
    physics: Physics.PhysicsBodyHandle,
    animator: AnimationSystem.AnimatorHandle,
    // controller
};

const ComponentSystemState = struct {
    entities: std.ArrayList(Entity),
    local_transforms: std.ArrayList(rl.Matrix),
    global_transforms: std.ArrayList(rl.Matrix),

    changed_this_frame: std.ArrayList(u64),
    // remove_this_frame: std.ArrayList(i32),
    // entity_pool: std.ArrayList(i32),

    fn update_transforms(self: *ComponentSystemState) void {
        for (self.global_transforms.items, 0..) |_, i| {
            self.global_transforms.items[i] = calculate_global_transform(i);
        }
    }
};

pub fn opaqPtrTo(ptr: ?*anyopaque, comptime T: type) T {
    return @ptrCast(@alignCast(ptr));
}

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
        .local_transforms = std.ArrayList(rl.Matrix).init(allocator),
        .global_transforms = std.ArrayList(rl.Matrix).init(allocator),
        .changed_this_frame = std.ArrayList(u64).init(allocator),
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
      const local = states.items[current_state].local_transforms.items[index.?];
      global = rl.MatrixMultiply(global, local);
      index = states.items[current_state].entities.items[index.?].hierarchy.parent_id;
    }
    return global;
}
