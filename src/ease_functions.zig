const std = @import("std");

pub fn out_back(x: f32) f32 {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * std.math.pow(f32, x - 1, 3) + c1 * std.math.pow(f32, x - 1, 2);
}

pub fn out_elastic(x: f32) f32 {
    const c4 = (2.0 * std.math.pi) / 3.0;
    return if (x == 0) 0
    else if (x == 1) 1
    else std.math.pow(f32, 2, -10 * x) * @sin((x * 10 - 0.75) * c4) + 1;
}