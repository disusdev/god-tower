const std = @import("std");
const rl = @import("rl.zig");
const Frame = @import("frame.zig");
const Box = @import("box2d.zig");
const physics = @import("physics.zig");
const T = @This();
const AbilitySystem = @import("ability_system.zig");

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
    state: AnimationState = .Idle,
    anim_idx: usize = 1,
    frame_idx: usize = 0,
    frame_time: f32 = 0.0,
    loop: bool = true,
    flip: bool = false,
};

const Renderer = struct {
    texture: rl.Texture2D = undefined,
    rect: rl.Rectangle = undefined,
    visible: bool = true,
};

pub const Weapon = struct {
    pos: rl.Vector2,
    target: *T,
    rot: f32,
    pivot: rl.Vector2,
    renderer: Renderer,
    
    pub fn init(pos: rl.Vector2, target: *T, tex: rl.Texture2D, rect: rl.Rectangle, pivot: rl.Vector2) Weapon {
        return Weapon {
            .pos = pos,
            .target = target,
            .rot = 0,
            .renderer = .{ .texture = tex, .rect = rect, .visible = false },
            .pivot = pivot,
        };
    }
    
    pub fn draw(self: Weapon) void {
        if (!self.renderer.visible) return;
        const target_pos = physics.get_pos(self.target.body);
        // rl.DrawTextureRec(self.renderer.texture, self.renderer.rect, rl.Vector2Add(target_pos, self.pos), rl.WHITE);
        const dst_rect = .{
            .x = target_pos.x+self.pos.y,
            .y = target_pos.y+self.pos.y,
            .width = self.renderer.rect.width,
            .height = self.renderer.rect.height
        };
        rl.DrawTexturePro(self.renderer.texture, self.renderer.rect, dst_rect, self.pivot, self.rot, rl.WHITE);
    }
};

weapon: ?Weapon = null,

body: Box.BodyHandle = undefined,

move: AbilitySystem.MoveAbility = .{},
attack: AbilitySystem.AttackAbility = .{},

stat_points: u32 = 0,
stats: Attributes = undefined,
exp: u32 = 0,
level: u32 = 0,

hp: i32 = 10,


animations: []const []const Frame = undefined,
renderer: Renderer = undefined,

dir: Direction = .Down,

animator: Animation = Animation {},

dmg_seed: i8 = -1,

dead: bool = false,

pub fn damage(self: *T, dmg: u32, seed: i8) u32 {
    if (seed == self.dmg_seed) return 0;
    if (self.hp <= 0) return 0;
    self.animator.state = .Hit;
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

pub fn draw(self: *T) void {
    if (self.dead) return;
    if (!self.renderer.visible) return;

    var pos = rl.Vector2Zero();
    if (physics.world.bodies.getPtr(self.body)) |body| {
        pos.x = body.position.x;
        pos.y = body.position.y;
    }

    self.set_animation(self.animator.state, self.dir);

    var rect = self.animator.current_anim[self.animator.frame_idx].rect;
    rect.width = if (self.animator.flip) -@abs(rect.width) else @abs(rect.width);

    rl.DrawTextureRec(self.renderer.texture, rect, .{ .x=pos.x-@abs(self.animator.current_anim[self.animator.frame_idx].rect.width)/2, .y=pos.y-6-@abs(self.animator.current_anim[self.animator.frame_idx].rect.height)/2 }, rl.WHITE);
    if (self.weapon) |w| {
        w.draw();
    }

    self.animator.frame_time += rl.GetFrameTime();
    if (self.animator.frame_time >= (@as(f32, @floatFromInt(self.animator.current_anim[self.animator.frame_idx].duration)) * 0.001)) {
        if (self.animator.loop == false and (self.animator.frame_idx + 1) == self.animator.current_anim.len) {
            if (self.animator.state == .Hit and self.hp <= 0) {
                self.dead = true;
            }
            self.animator.state = .Idle;
            return;
        }
        self.animator.frame_idx = (self.animator.frame_idx + 1) % self.animator.current_anim.len;
        self.animator.frame_time = 0.0;
    }
    
    if (self.weapon) |*w| {
        w.rot = self.attack.attack_angle + 90;
    }
    rl.DrawLineV(self.attack.attack_line[0], self.attack.attack_line[1], rl.GREEN);
}

pub fn update(self: *T, dt: f32, characters: [] T) void {
    if (self.animator.state == .Attack) {
        self.attack.step(self, characters, dt);
        return;
    }
    
    if (self.animator.state == .Hit) {
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

    self.move.exec(self.*, .{.x=x_axis, .y=y_axis}, dt);
    
    if (rl.IsKeyPressed(rl.KEY_RIGHT_CONTROL) or
        rl.IsKeyPressed(rl.KEY_LEFT_CONTROL) or
        rl.IsGamepadButtonPressed(0, rl.GAMEPAD_BUTTON_RIGHT_FACE_LEFT)) {
        self.animator.state = .Attack;
        self.attack.exec(self);
        physics.set_vel(self.body, rl.Vector2Zero());
    } else if (rl.Vector2Length(physics.get_vel(self.body)) > 0.1) {
        self.animator.state = .Move;
    } else {
        self.animator.state = .Idle;
    }
}

// @todo make read from file to faster iteration for character animation and map creation!
//       mb maps could be read from folders with CSVs of layers that called: bg, floor, walls, decor, objects.

pub fn hero(x:f32, y:f32) T {
    return T {
        .body = physics.world.addBody(Box.Body.init(.{ .x = x, .y = y }, .{ .x = 8.0, .y = 6.0 }, 2.0, 0.2)),
        .renderer = .{ .texture = rl.LoadTexture("data/sprites/hero.png") },
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
        .body = physics.world.addBody(Box.Body.init(.{ .x = x, .y = y }, .{ .x = 8.0, .y = 6.0 }, 2.0, 0.2)),
        .renderer = .{ .texture = rl.LoadTexture("data/sprites/slime.png") },
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