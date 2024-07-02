const std = @import("std");
const rl = @import("rl.zig");
const physics = @import("physics.zig");
const Character = @import("character.zig");

pub const MoveAbility = struct {
    speed: f32 = 24.0,

    pub fn exec(self: MoveAbility, character: Character, move: rl.Vector2, dt: f32) void {
        _ = dt;
        var velocity = move;
        velocity = rl.Vector2Scale(rl.Vector2Normalize(velocity), self.speed);
        
        const real_velocity = physics.get_vel(character.body);
        velocity.x += real_velocity.x * -0.2;
        velocity.y += real_velocity.y * -0.2;
        
        physics.set_vel(character.body, velocity);
    }
};

pub const AttackAbility = struct {
    attack_damage: u32 = 1,
    attack_line: [2] rl.Vector2 = undefined,
    attack_progress: f32 = 0.0,
    attack_seed: i8 = 0,
    attack_length: f32 = 16.0,
    attack_speed: f32 = 3.5,
    attack_angle: f32 = 0.0,
    attack_src_angle: f32 = 0.0,
    attack_dst_angle: f32 = 0.0,

    pub fn CheckCollisionLineCircle(start: rl.Vector2, end: rl.Vector2, center: rl.Vector2, radius: f32) bool {
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
    
    pub fn step(self: *AttackAbility, character: *Character, characters: [] Character, dt: f32) void {
        self.attack_progress = @min(1, self.attack_progress + dt * self.attack_speed);
        self.attack_angle = rl.Lerp(self.attack_dst_angle, self.attack_src_angle, self.attack_progress);
        const attack_radians = std.math.degreesToRadians(self.attack_angle);
        self.attack_line[0] = physics.get_pos(character.body);
        self.attack_line[1] = .{ .x = @cos(attack_radians), .y = @sin(attack_radians) };
        self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
        self.attack_line[1].x += self.attack_line[0].x;
        self.attack_line[1].y += self.attack_line[0].y;
        
        for (characters) |*char| {
            _ = self.attack_solve(char);
        }
        
        if (self.attack_progress == 1) {
            character.weapon.?.renderer.visible = false;
        }
    }
    
    pub fn attack_solve(self: AttackAbility, other: *Character) u32 {
        const other_pos = physics.get_pos(other.body);
        if (CheckCollisionLineCircle(self.attack_line[0], self.attack_line[1], other_pos, 8.0)) {
            return other.damage(self.attack_damage, self.attack_seed);
        }
        return 0;
    }

    pub fn exec(self: *AttackAbility, character: *Character) void {
        self.attack_progress = 0.0;
        self.attack_src_angle = 45 + 180 + (90 * @as(f32, @floatFromInt(@intFromEnum(character.dir))));
        self.attack_dst_angle = self.attack_src_angle + 90;
        if (character.dir == .SideLeft or
            (character.animator.flip and (character.dir == .Up or
            character.dir == .Down))) {
            const src = self.attack_src_angle;
            self.attack_src_angle = self.attack_dst_angle;
            self.attack_dst_angle = src;
        }
        self.attack_angle = self.attack_dst_angle;
        const attack_radians = std.math.degreesToRadians(self.attack_angle);
        self.attack_line[0] = physics.get_pos(character.body);
        self.attack_line[1] = .{
            .x = @cos(attack_radians),
            .y = @sin(attack_radians)
        };
        self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
        self.attack_line[1].x += self.attack_line[0].x;
        self.attack_line[1].y += self.attack_line[0].y;
        self.attack_seed = self.attack_seed + 1;
        character.weapon.?.renderer.visible = true;
    }
};
