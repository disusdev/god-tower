const rl = @import("rl.zig");
const Frame = @import("frame.zig");
const T = @This();

const Direction = enum {
    Up,
    SideRight,
    Down,
    SideLeft
};

const AnimationState = enum {
    Idle,
    Move,
    Attack,
    Hit
};

position: rl.Vector2 = undefined,
animations: []const []const Frame = undefined,
texture: rl.Texture2D = undefined,

state: AnimationState = .Idle,
dir: Direction = .Down,

velocity: rl.Vector2 = rl.Vector2Zero(),
speed: f32 = 512.0,

current_anim: [] const Frame = undefined,
anim_idx: usize = 1,
frame_idx: usize = 0,
frame_time: f32 = 0.0,

flip: bool = false,
loop: bool = true,

pub fn set_animation(self: *T, state: AnimationState, dir: Direction) void {
    var id: usize = 0;
    if (state == .Move) {
        self.loop = true;
        switch (dir) {
            .Down => id = 2,
            .SideLeft => {
                id = 3;
                self.flip = true;
            },
            .SideRight => {
                id = 3;
                self.flip = false;
            },
            .Up => id = 4
        }
    } else if (state == .Attack) {
        self.loop = false;
        switch (dir) {
            .Down => id = 5,
            .SideLeft => {
                id = 6;
                self.flip = true;
            },
            .SideRight => {
                id = 6;
                self.flip = false;
            },
            .Up => id = 7
        }
    } else {
        self.loop = true;
    }

    if (id != self.anim_idx) {
        self.anim_idx = id;
        self.current_anim = self.animations[self.anim_idx];
        self.frame_idx = 0;
        self.frame_time = 0.0;
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
    self.set_animation(self.state, self.dir);

    var rect = self.current_anim[self.frame_idx].rect;
    rect.width = if (self.flip) -@abs(rect.width) else @abs(rect.width);

    rl.DrawTextureRec(self.texture, rect, .{ .x=self.position.x-@abs(self.current_anim[self.frame_idx].rect.width)/2, .y=self.position.y-@abs(self.current_anim[self.frame_idx].rect.height)/2 }, rl.WHITE);

    self.frame_time += rl.GetFrameTime();
    if (self.frame_time >= (@as(f32, @floatFromInt(self.current_anim[self.frame_idx].duration)) * 0.001)) {
        if (self.loop == false and (self.frame_idx + 1) == self.current_anim.len) {
            self.state = .Idle;
            return;
        }
        self.frame_idx = (self.frame_idx + 1) % self.current_anim.len;
        self.frame_time = 0.0;
    }
}

pub fn update(self: *T) void {
    if (self.state == .Attack) return;

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

    if (rl.IsKeyDown(rl.KEY_A) and rl.IsKeyDown(rl.KEY_W)) {
        x_axis = -1.0;
        y_axis = -1.0;
        self.dir = .SideLeft;
    } else if (rl.IsKeyDown(rl.KEY_D) and rl.IsKeyDown(rl.KEY_W)) {
        x_axis = 1.0;
        y_axis = -1.0;
        self.dir = .SideRight;
    } else if (rl.IsKeyDown(rl.KEY_A) and rl.IsKeyDown(rl.KEY_S)) {
        x_axis = -1.0;
        y_axis = 1.0;
        self.dir = .SideLeft;
    } else if (rl.IsKeyDown(rl.KEY_D) and rl.IsKeyDown(rl.KEY_S)) {
        x_axis = 1.0;
        y_axis = 1.0;
        self.dir = .SideRight;
    } else if (rl.IsKeyDown(rl.KEY_A)) {
        x_axis = -1.0;
        self.dir = .SideLeft;
    } else if (rl.IsKeyDown(rl.KEY_D)) {
        x_axis = 1.0;
        self.dir = .SideRight;
    } else if (rl.IsKeyDown(rl.KEY_W)) {
        y_axis = -1.0;
        self.dir = .Up;
    } else if (rl.IsKeyDown(rl.KEY_S)) {
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
    } else if (rl.Vector2Length(self.velocity) > 0.1) {
        self.state = .Move;
    } else {
        self.state = .Idle;
    }
}

pub fn update_pos(self: *T, dt: f32) void {
    self.position = rl.Vector2Add(self.position, rl.Vector2Scale(self.velocity, dt));
}

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

pub fn slime() T {
    return T {
        .position = .{.x = 0, .y = 0 },
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