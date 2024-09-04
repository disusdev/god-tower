const std = @import("std");
const rl = @import("rl.zig");
const Physics = @import("physics.zig");
const ComponentSystem = @import("component_system.zig");
const Ease = @import("ease_functions.zig");


// @todo controller where you can chouse between brain or hid
//pub const Controller = struct {
//    const Action = enum {
//        Move,
//        Look,
//        Action1,
//        Action2,
//        Action3,
//        Action4,
//    };
//
//    const Kind = enum {
//        None,
//        Device,
//        Brain
//    };
//    
//    const FnPtr = fn (ctx: anytype) void;
//    
//    kind: Kind = .None,
//    ptr_table: std.AutoHashMap(Action, FnPtr) = undefined,
//    
//    pub fn init(allocator: std.mem.Allocator) Controller {
//        return .{
//            .ptr_table = std.AutoHashMap(Action, FnPtr).init(allocator),
//        };
//    }
//    
//    pub fn attach(self: *Controller, action: Action, fn_ptr: FnPtr) !void {
//        try self.ptr_table.put(action, fn_ptr);
//    }
//    
//    pub fn update(self: *Controller) void {        
//        if (self.ptr_table.get(.Move)) |fn_ptr| {
//            var axis = rl.Vector2 {
//                .x = rl.GetGamepadAxisMovement(0, 0),
//                .y = rl.GetGamepadAxisMovement(0, 1)
//            };
//            const up = rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP);
//            const down = rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN);
//            const left = rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT);
//            const right = rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT);
//            axis.x = @floatFromInt(@as(i32, @intFromBool(right)) - @as(i32, @intFromBool(left)));
//            axis.y = @floatFromInt(@as(i32, @intFromBool(down)) - @as(i32,@intFromBool(up)));
//            fn_ptr(.{ axis });
//        }
//    }
//};

pub const InputController = struct {
    kind: u32 = 0,
    pub fn get_axis(self: InputController) rl.Vector2 {
        _ = self;
        var axis = rl.Vector2 {
            .x = rl.GetGamepadAxisMovement(0, 0),
            .y = rl.GetGamepadAxisMovement(0, 1)
        };
        const up = rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP);
        const down = rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN);
        const left = rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT);
        const right = rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT);
        axis.x = @floatFromInt(@as(i32, @intFromBool(right)) - @as(i32, @intFromBool(left)));
        axis.y = @floatFromInt(@as(i32, @intFromBool(down)) - @as(i32,@intFromBool(up)));
        return axis;
    }
    pub fn get_action(self: InputController) bool {
        _ = self;
        return rl.IsGamepadButtonDown(0, rl.GAMEPAD_BUTTON_RIGHT_FACE_LEFT) or
               rl.IsMouseButtonDown(0);
    }
};

pub const MoveAbility = struct {
    body: Physics.PhysicsBodyHandle,
    input: InputController = .{},
    speed: f32 = 48.0,

    pub fn exec(self: MoveAbility) void {
        var velocity = self.input.get_axis();
        velocity = rl.Vector2Scale(rl.Vector2Normalize(velocity), self.speed);
        
        self.body.set_vel(velocity);
    }
};

pub const Brain = struct {
    body: Physics.PhysicsBodyHandle,
    speed: f32 = 48.0,
    timer: f32 = 0.0,
    dir: rl.Vector2 = rl.Vector2Zero(),

    pub fn exec(self: *Brain) void {
        self.timer -= rl.GetFrameTime();
        if (self.timer < 0) {
            self.timer = 1.0;//@floatFromInt(rl.GetRandomValue(1, 5));
            self.dir = .{
                .x = @floatFromInt(rl.GetRandomValue(0, 2) - 1),
                .y = @floatFromInt(rl.GetRandomValue(0, 2) - 1)
            };
        }
    
        var velocity = self.dir;
        velocity = rl.Vector2Scale(rl.Vector2Normalize(velocity), self.speed);
        
        self.body.set_vel(velocity);
    }
};

pub const Stats = struct {
    owner: ComponentSystem.EntityHandle,
    hp: i32,
    last_seed: i8 = -1,
    
     pub fn damage(self: *Stats, dmg: u32, seed: i8) u32 {
        if (self.last_seed == seed) return 0;
        // @todo impulse entity back, if it got physics
        //       white flash for renderer
        self.hp -= @intCast(dmg);
        if (self.hp <= 0) {
            // play die animation
            
            self.owner.set_enable(false);
        }
        return dmg;
    }
};

pub const StatsHandle = struct {
    id: u64,
    
    pub fn create(stat: Stats) StatsHandle {
        stats.append(stat) catch {
            @panic("stats_create");
        };
        return .{
            .id = stats.items.len,
        };
    }
    
    pub fn damage(self: *StatsHandle, dmg: u32, seed: i8) u32 {
        if (stats.items[self.id].last_seed == seed) return 0;
        // @todo impulse entity back, if it got physics
        //       white flash for renderer
        stats.items[self.id].hp -= dmg;
        if (stats.items[self.id].hp <= 0) {
            stats.items[self.id].owner.set_enable(false);
        }
        return dmg;
    }
};

pub const AttackAbility = struct {
    // @todo should have weapon slot, to perform attack with it
    //       no weapon in slot, no attack
    
    // @todo weapon should be an entity, with mb some weapon logic on it
    owner: ComponentSystem.EntityHandle,
    weapon_slot: ComponentSystem.EntityHandle = undefined,
    weapon: ?ComponentSystem.EntityHandle = null,
    input: InputController = .{},

    attack_damage: u32 = 1,
    attack_line: [2] rl.Vector2 = undefined,
    attack_progress: f32 = 0.0,
    seed: i8 = 0,
    attack_length: f32 = 16.0,
    attack_speed: f32 = 3.5,
    angle: f32 = 0.0,
    attack_src_angle: f32 = 0.0,
    attack_dst_angle: f32 = 0.0,
    front: bool = true,
    play: bool = false,

    pub fn CheckCollisionLineCircle(start: rl.Vector2,
                                    end: rl.Vector2,
                                    center: rl.Vector2,
                                    radius: f32) bool {
        const startToEnd = rl.Vector2Subtract(end, start);
        const startToCenter = rl.Vector2Subtract(center, start);
    
        const startToEndLengthSquared = rl.Vector2LengthSqr(startToEnd);
    
        var t = rl.Vector2DotProduct(startToCenter, startToEnd) / startToEndLengthSquared;
        t = @max(0, @min(1, t));
    
        const projection = rl.Vector2Add(start, rl.Vector2Scale(startToEnd, t));
        const centerToProjection = rl.Vector2Subtract(center, projection);
    
        const distanceSquared = rl.Vector2LengthSqr(centerToProjection);
    
        return distanceSquared <= (radius * radius);
    }
    
    pub fn step(self: *AttackAbility, dt: f32) void {
        self.attack_progress = @min(1, self.attack_progress + dt * self.attack_speed);
        const prog = Ease.out_back(self.attack_progress);
        
        self.angle = rl.Lerp(self.attack_dst_angle, self.attack_src_angle, prog);
        const attack_radians = std.math.degreesToRadians(self.angle);
        self.attack_line[0] = self.owner.get_pos();
        self.attack_line[1] = .{ .x = @cos(attack_radians), .y = @sin(attack_radians) };
        self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
        self.attack_line[1].x += self.attack_line[0].x;
        self.attack_line[1].y += self.attack_line[0].y;
        
        self.weapon_slot.set_rot(self.angle + 90);
        
        const mul: f32 = if (self.front) 1 else -1;
        const child_rot = rl.Lerp(-90 * mul, 90 * mul, prog);
        if (self.weapon) |weapon| {
            weapon.set_rot(child_rot);
        }
        
        if (self.attack_progress == 1) {
            self.play = false;
        }
    }
    
    pub fn attack_solve(self: AttackAbility, other: *Stats) u32 {
        const other_pos = other.owner.get_pos();
        if (CheckCollisionLineCircle(self.attack_line[0], self.attack_line[1], other_pos, 8.0)) {
            return other.damage(self.attack_damage, self.seed);
        }
        return 0;
    }
    
    pub fn update_solver(self: AttackAbility) void {
        if (!self.play) return;
        for (stats.items) |*stat| {
            if (stat.owner.id == self.owner.id) continue;
            _ = self.attack_solve(stat);
        }
    }

    pub fn update(self: *AttackAbility, camera: rl.Camera2D, dt: f32) void {        
        if (self.play) {
            self.step(dt);
            return;
        }
        
        if (self.input.get_action()) {
            self.exec();
        }
        
        const mouse_pos = rl.GetMousePosition();
        const world_pos = rl.GetScreenToWorld2D(mouse_pos, camera);
        const mouse_dir = rl.Vector2Subtract(world_pos, self.owner.get_pos());
        
        const rot: f32 = @floatCast(rl.atan2(mouse_dir.y, mouse_dir.x) * rl.RAD2DEG);
        
        self.attack_progress = 0.0;
        const dir_angle = if (self.front) rot + 90 else rot - 90;
        self.attack_src_angle = 180 + dir_angle;
        self.attack_dst_angle = if (self.front) self.attack_src_angle + 180 else self.attack_src_angle - 180;

        self.angle = self.attack_dst_angle;
        const attack_radians = std.math.degreesToRadians(self.angle);
        self.attack_line[0] = self.owner.get_pos();
        self.attack_line[1] = .{
            .x = @cos(attack_radians),
            .y = @sin(attack_radians)
        };
        self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
        self.attack_line[1].x += self.attack_line[0].x;
        self.attack_line[1].y += self.attack_line[0].y;
        
        self.weapon_slot.set_rot(self.angle + 90);
        
        const mul: f32 = if (self.front) -1 else 1;
        const child_rot = rl.Lerp(-90 * mul, 90 * mul, self.attack_progress);
        if (self.weapon) |weapon| {
            weapon.set_rot(child_rot);
        }
        
        if (self.input.get_action()) {
            self.front = !self.front;
        }
    }

    pub fn exec(self: *AttackAbility) void {
        if (self.play or self.weapon == null) return;

        self.attack_progress = 0.0;

        self.angle = self.attack_dst_angle;
        const attack_radians = std.math.degreesToRadians(self.angle);
        self.attack_line[0] = self.owner.get_pos();
        self.attack_line[1] = .{
            .x = @cos(attack_radians),
            .y = @sin(attack_radians)
        };
        self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
        self.attack_line[1].x += self.attack_line[0].x;
        self.attack_line[1].y += self.attack_line[0].y;
        self.seed = @addWithOverflow(self.seed, 1)[0];
        self.play = true;
    }
};

pub const FrictionAbility = struct {
    body: Physics.PhysicsBodyHandle,
    coef: f32 = 0.2,
};

pub const MoveAbilityHandle = struct {
    id: u64,
    
    pub fn get_axis(self: MoveAbilityHandle) rl.Vector2 {
        return move_abilities.items[self.id].input.get_axis();
    }
    
    pub fn get_action(self: MoveAbilityHandle) bool {
        return move_abilities.items[self.id].input.get_action();
    }
};

pub const AttackAbilityHandle = struct {
    id: u64,
    
    pub fn set_weapon(self: AttackAbilityHandle,
                      entity: ?ComponentSystem.EntityHandle) void {
        if (attack_abilities.items[self.id].weapon) |e| {
            e.set_parent(null);
        }
        if (entity) |e| {
            e.set_parent(attack_abilities.items[self.id].weapon_slot);
        }
        attack_abilities.items[self.id].weapon = entity;
    }
};

pub const FrictionAbilityHandle = struct {
    id: u64,
};

pub const BrainHandle = struct {
    id: u64,
    
    pub fn create(brain: Brain) BrainHandle {
        brains.append(brain) catch {
            @panic("brain_create");
        };
        return .{ .id = brains.items.len - 1 };
    }
};

//pub const ControllerHandle = struct {
//    id: u64,
//};

pub var move_abilities: std.ArrayList(MoveAbility) = undefined;
pub var attack_abilities: std.ArrayList(AttackAbility) = undefined;
pub var friction_abilities: std.ArrayList(FrictionAbility) = undefined;
pub var brains: std.ArrayList(Brain) = undefined;
pub var stats: std.ArrayList(Stats) = undefined;
// pub var controllers: std.ArrayList(Controller) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    move_abilities = std.ArrayList(MoveAbility).init(allocator);
    attack_abilities = std.ArrayList(AttackAbility).init(allocator);
    friction_abilities = std.ArrayList(FrictionAbility).init(allocator);
    brains = std.ArrayList(Brain).init(allocator);
    stats = std.ArrayList(Stats).init(allocator);
}

pub fn add_move(ability: MoveAbility) !MoveAbilityHandle {
    try move_abilities.append(ability);
    return .{ .id = move_abilities.items.len - 1 };
}

pub fn add_attack(ability: AttackAbility) !AttackAbilityHandle {
    try attack_abilities.append(ability);
    return .{ .id = attack_abilities.items.len - 1 };
}

pub fn add_friction(ability: FrictionAbility) !FrictionAbilityHandle {
    try friction_abilities.append(ability);
    return .{ .id = friction_abilities.items.len - 1 };
}

pub fn update(camera: rl.Camera2D, dt: f32) void {
    // for (controllers.items) |*controller| {
    //     controller.update();
    // }

    for (move_abilities.items) |move| {
        move.exec();
    }
    
    for (brains.items) |*brain| {
        brain.exec();
    }
    
    for (attack_abilities.items) |*attack| {
        attack.update(camera, dt);
    }
    
    for (attack_abilities.items) |attack| {
        attack.update_solver();
    }
}

pub fn draw() !void {
    // for (attack_abilities.items) |attack| {
    //     var str: [128:0]u8 = std.mem.zeroes([128:0]u8);
    //     const slice = try std.fmt.bufPrint(&str, "{any}", .{attack.front});
    //     rl.DrawTextEx(rl.GetFontDefault(), @ptrCast(slice.ptr), attack.owner.get_pos(), 12, 0.5, rl.WHITE);
    // }
}
