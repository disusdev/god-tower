pub usingnamespace @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

pub fn RLerp(a: f32, b: f32, v: f32) f32 {
    return (v - a) / (b - a);
}