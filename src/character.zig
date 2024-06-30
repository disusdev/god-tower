const std = @import("std");
const rl = @import("rl.zig");
const Frame = @import("frame.zig");
const T = @This();

const Direction = enum(u8) {
    Up = 0,
    SideRight = 1,
    Down = 2,
    SideLeft = 3
};

const AnimationState = enum {
    Idle,
    Move,
    Attack,
    Hit
};

const Attributes = struct {
    hp: u32,
    attack: u32,
    defence: u32,
    speed: u32
};

const Animation = struct {
    current_anim: [] const Frame = undefined,
    anim_idx: usize = 1,
    frame_idx: usize = 0,
    frame_time: f32 = 0.0,
    loop: bool = true,
    flip: bool = false,
};

stat_points: u32 = 0,
stats: Attributes = undefined,
exp: u32 = 0,
level: u32 = 0,

hp: i32 = 10,

attack_damage: u32 = 1,

position: rl.Vector2 = undefined,
animations: []const []const Frame = undefined,
texture: rl.Texture2D = undefined,

state: AnimationState = .Idle,
dir: Direction = .Down,

velocity: rl.Vector2 = rl.Vector2Zero(),
speed: f32 = 512.0,

animator: Animation = Animation {},

dmg_seed: i8 = -1,

attack_line: [2] rl.Vector2 = undefined,
attack_progress: f32 = 0.0,
attack_seed: i8 = 0,
attack_length: f32 = 16.0,
attack_speed: f32 = 3.5,
attack_angle: f32 = 0.0,
attack_src_angle: f32 = 0.0,
attack_dst_angle: f32 = 0.0,

dead: bool = false,

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

pub fn attack(self: *T) void {
    self.attack_progress = 0.0;
    self.attack_src_angle = 45 + 180 + (90 * @as(f32, @floatFromInt(@intFromEnum(self.dir))));
    self.attack_dst_angle = self.attack_src_angle + 90;
    if (self.dir == .SideLeft or
        (self.animator.flip and (self.dir == .Up or
        self.dir == .Down))) {
        const src = self.attack_src_angle;
        self.attack_src_angle = self.attack_dst_angle;
        self.attack_dst_angle = src;
    }
    self.attack_angle = self.attack_dst_angle;
    const attack_radians = std.math.degreesToRadians(self.attack_angle);
    self.attack_line[0] = self.position;
    self.attack_line[1] = .{
        .x = @cos(attack_radians),
        .y = @sin(attack_radians)
    };
    self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
    self.attack_line[1].x += self.attack_line[0].x;
    self.attack_line[1].y += self.attack_line[0].y;
    self.attack_seed = self.attack_seed + 1;
}

pub fn attack_step(self: *T, progress: f32, characters: [] T) void {
    self.attack_angle = rl.Lerp(self.attack_dst_angle, self.attack_src_angle, progress);// dt * self.attack_speed;
    const attack_radians = std.math.degreesToRadians(self.attack_angle);
    self.attack_line[0] = self.position;
    self.attack_line[1] = .{ .x = @cos(attack_radians), .y = @sin(attack_radians) };
    self.attack_line[1] = rl.Vector2Scale(self.attack_line[1], self.attack_length);
    self.attack_line[1].x += self.attack_line[0].x;
    self.attack_line[1].y += self.attack_line[0].y;
    
    for (characters) |*character| {
        self.attack_solve(character);
    }
}

pub fn attack_solve(self: *T, other: *T) void {
    if (CheckCollisionLineCircle(self.attack_line[0], self.attack_line[1], other.position, 8.0)) {
        self.exp += other.damage(self.attack_damage, self.attack_seed);
    }
}

pub fn damage(self: *T, dmg: u32, seed: i8) u32 {
    if (seed == self.dmg_seed) return 0;
    if (self.hp <= 0) return 0;
    self.state = .Hit;
    self.dmg_seed = seed;
    self.hp -= @intCast(dmg);
    if (self.hp == 0) {
        // light death
    } else if (self.hp < 0) {
        // brutal death
    }
    return dmg;
}

pub fn set_animation(self: *T, state: AnimationState, dir: Direction) void {
    var id: usize = 0;
    if (state == .Move) {
        self.animator.loop = true;
        switch (dir) {
            .Down => id = 2,
            .SideLeft => {
                id = 3;
                self.animator.flip = true;
            },
            .SideRight => {
                id = 3;
                self.animator.flip = false;
            },
            .Up => id = 4
        }
    } else if (state == .Attack) {
        self.animator.loop = false;
        switch (dir) {
            .Down => id = 5,
            .SideLeft => {
                id = 6;
                self.animator.flip = true;
            },
            .SideRight => {
                id = 6;
                self.animator.flip = false;
            },
            .Up => id = 7
        }
    } else if (state == .Hit) {
        self.animator.loop = false;
        switch (dir) {
            .Down => id = 8,
            .SideLeft => {
                id = 9;
                self.animator.flip = true;
            },
            .SideRight => {
                id = 9;
                self.animator.flip = false;
            },
            .Up => id = 10
        }
    } else {
        self.animator.loop = true;
    }

    if (id != self.animator.anim_idx) {
        self.animator.anim_idx = id;
        self.animator.current_anim = self.animations[self.animator.anim_idx];
        self.animator.frame_idx = 0;
        self.animator.frame_time = 0.0;
    }
}

pub fn solve_collision(self: *T, rect: rl.Rectangle) void {
    var closest_point: rl.Vector2 = undefined;
    closest_point.x = @max(rect.x, @min(self.position.x, rect.x + rect.width));
    closest_point.y = @max(rect.y, @min(self.position.y, rect.y + rect.height));

    const distance_vector = rl.Vector2 { .x = closest_point.x - self.position.x, .y = closest_point.y - self.position.y };
    const distance: f32 = rl.Vector2Length(distance_vector);

    if (distance < 1.0) {
        const penetration_depth = 0.5 - distance;
        const collision_normal = rl.Vector2Normalize(distance_vector);

        self.position.x -= collision_normal.x * penetration_depth;
        self.position.y -= collision_normal.y * penetration_depth;

        const velocity_dot_normal: f32 = self.velocity.x * collision_normal.x + self.velocity.y * collision_normal.y;
        self.velocity.x -= velocity_dot_normal * collision_normal.x;
        self.velocity.y -= velocity_dot_normal * collision_normal.y;
    }
}

pub fn draw(self: *T) void {
    if (self.dead) return;

    self.set_animation(self.state, self.dir);

    var rect = self.animator.current_anim[self.animator.frame_idx].rect;
    rect.width = if (self.animator.flip) -@abs(rect.width) else @abs(rect.width);

    rl.DrawTextureRec(self.texture, rect, .{ .x=self.position.x-@abs(self.animator.current_anim[self.animator.frame_idx].rect.width)/2, .y=self.position.y-@abs(self.animator.current_anim[self.animator.frame_idx].rect.height)/2 }, rl.WHITE);

    self.animator.frame_time += rl.GetFrameTime();
    if (self.animator.frame_time >= (@as(f32, @floatFromInt(self.animator.current_anim[self.animator.frame_idx].duration)) * 0.001)) {
        if (self.animator.loop == false and (self.animator.frame_idx + 1) == self.animator.current_anim.len) {
            if (self.state == .Hit and self.hp <= 0) {
                self.dead = true;
            }
            self.state = .Idle;
            return;
        }
        self.animator.frame_idx = (self.animator.frame_idx + 1) % self.animator.current_anim.len;
        self.animator.frame_time = 0.0;
    }
    
    rl.DrawLineV(self.attack_line[0], self.attack_line[1], rl.GREEN);
}

pub fn update(self: *T, dt: f32, characters: [] T) void {
    if (self.state == .Attack) {
        self.attack_progress = @min(1, self.attack_progress + dt * self.attack_speed);
        self.attack_step(self.attack_progress, characters);
        return;
    }
    
    if (self.state == .Hit) {
        return;
    }

    var x_axis = rl.GetGamepadAxisMovement(0, 0);
    var y_axis = rl.GetGamepadAxisMovement(0, 1);

    if (x_axis > 0.5) {
        self.dir = .SideRight;
    } else if (x_axis < -0.5) {
        self.dir = .SideLeft;
    } else if (y_axis < -rl.EPSILON) {
        self.dir = .Up;
    } else if (y_axis > rl.EPSILON) {
        self.dir = .Down;
    }
    
    const up = rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP);
    const down = rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN);
    const left = rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT);
    const right = rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT);

    if (left and up) {
        x_axis = -1.0;
        y_axis = -1.0;
        self.dir = .SideLeft;
    } else if (right and up) {
        x_axis = 1.0;
        y_axis = -1.0;
        self.dir = .SideRight;
    } else if (left and down) {
        x_axis = -1.0;
        y_axis = 1.0;
        self.dir = .SideLeft;
    } else if (right and down) {
        x_axis = 1.0;
        y_axis = 1.0;
        self.dir = .SideRight;
    } else if (left) {
        x_axis = -1.0;
        self.dir = .SideLeft;
    } else if (right) {
        x_axis = 1.0;
        self.dir = .SideRight;
    } else if (up) {
        y_axis = -1.0;
        self.dir = .Up;
    } else if (down) {
        y_axis = 1.0;
        self.dir = .Down;
    }

    self.velocity.x = x_axis;
    self.velocity.y = y_axis;
    self.velocity = rl.Vector2Scale(rl.Vector2Normalize(self.velocity), self.speed);

    if (rl.IsKeyPressed(rl.KEY_RIGHT_CONTROL) or
        rl.IsKeyPressed(rl.KEY_LEFT_CONTROL) or
        rl.IsGamepadButtonPressed(0, rl.GAMEPAD_BUTTON_RIGHT_FACE_LEFT)) {
        self.velocity = rl.Vector2Zero();
        self.state = .Attack;
        self.attack();
    } else if (rl.Vector2Length(self.velocity) > 0.1) {
        self.state = .Move;
    } else {
        self.state = .Idle;
    }
}

pub fn update_pos(self: *T, dt: f32) void {
    self.position = rl.Vector2Add(self.position, rl.Vector2Scale(self.velocity, dt));
}

// @todo make read from file to faster iteration for character animation and map creation!
//       mb maps could be read from folders with CSVs of layers that called: bg, floor, walls, decor, objects.

pub fn hero() T {
    return T {
        .position = .{.x = 0, .y = 0 },
        .texture = rl.LoadTexture("data/sprites/hero.png"),
        .animations = &.{
            &.{// idle
                .{.rect = .{.x = 0 * 48, .y = 0, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 0, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 0, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 0, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// action
                .{.rect = .{.x = 0 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// run down
                .{.rect = .{.x = 0 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 2 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 3 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 120},
            },
            &.{// run side
                .{.rect = .{.x = 0 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 2 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 3 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 120},
            },
            &.{// run up
                .{.rect = .{.x = 0 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 2 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 3 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 120},
            },
            &.{// attack down
                .{.rect = .{.x = 0 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// attack side
                .{.rect = .{.x = 0 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// attack up
                .{.rect = .{.x = 0 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// hit down
                .{.rect = .{.x = 0 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 0 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// hit side
                .{.rect = .{.x = 0 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 0 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// hit up
                .{.rect = .{.x = 0 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 0 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 80},
            },
        }
    };
}

pub fn slime(x:f32, y:f32) T {
    return T {
        .hp = 2,
        .position = .{.x = x, .y = y },
        .texture = rl.LoadTexture("data/sprites/slime.png"),
        .animations = &.{
            &.{// idle
                .{.rect = .{.x = 0 * 48, .y = 0, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 0, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 0, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 0, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// action
                .{.rect = .{.x = 0 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 640},
                .{.rect = .{.x = 1 * 48, .y = 1 * 48, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// run down
                .{.rect = .{.x = 0 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 2 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// run side
                .{.rect = .{.x = 0 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 3 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// run up
                .{.rect = .{.x = 0 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 4 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// attack down
                .{.rect = .{.x = 0 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 5 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// attack side
                .{.rect = .{.x = 0 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 6 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// attack up
                .{.rect = .{.x = 0 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 1 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 2 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
                .{.rect = .{.x = 3 * 48, .y = 7 * 48, .width = 48, .height = 48}, .duration = 100},
            },
            &.{// hit down
                .{.rect = .{.x = 0 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 0 * 48, .y = 8 * 48, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// hit side
                .{.rect = .{.x = 0 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 0 * 48, .y = 9 * 48, .width = 48, .height = 48}, .duration = 80},
            },
            &.{// hit up
                .{.rect = .{.x = 0 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 120},
                .{.rect = .{.x = 1 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 2 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 80},
                .{.rect = .{.x = 0 * 48, .y = 10 * 48, .width = 48, .height = 48}, .duration = 80},
            },
        }
    };
}