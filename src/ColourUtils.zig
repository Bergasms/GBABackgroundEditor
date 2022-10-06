const std = @import("std");

pub fn u16ToU32(from: u16) u32 {
    var floatB = @intToFloat(f32, ((from >> 10) & 0x1F)) / 31.0;
    var floatG = @intToFloat(f32, ((from >> 5) & 0x1F)) / 31.0;
    var floatR = @intToFloat(f32, (from & 0x1F)) / 31.0;
    //ABGR
    var uppedB = (@intCast(u32, @floatToInt(u8, floatB * 255)) << 16) & 0xFF0000;
    var uppedG = (@intCast(u32, @floatToInt(u8, floatG * 255)) << 8) & 0xFF00;
    var uppedR = @intCast(u32, @floatToInt(u8, floatR * 255)) & 0xFF;
    return 0xFF000000 + uppedB + uppedG + uppedR;
}

pub fn u16ToF32(from: u16) [4]f32 {
    var floatB = @intToFloat(f32, ((from >> 10) & 0x1F)) / 31.0;
    var floatG = @intToFloat(f32, ((from >> 5) & 0x1F)) / 31.0;
    var floatR = @intToFloat(f32, (from & 0x1F)) / 31.0;
    return .{ floatR, floatG, floatB, 1.0 };
}

pub fn u16ToRGB5551(from: u16) u16 {
    var r = (from & 0x1F);
    var g = ((from >> 5) & 0x1F);
    var b = ((from >> 10) & 0x1F);
    return (r << 11) | (g << 6) | (b << 1);
}
