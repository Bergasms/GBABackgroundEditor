const std = @import("std");
const zgui = @import("zgui");
const colourutil = @import("ColourUtils.zig");

pub const Picker16Bit = struct {
    sliderColour: [3]i32 = .{ 0, 0, 0 },
    showingPicker: bool = false,
    colour: u16 = 0,
    sliderPct: f32 = 0,
    setFocus: bool = false,

    pub fn show(self: *Picker16Bit, colour: u16) void {
        self.showingPicker = true;
        self.setFocus = true;
        self.setColour(colour);
    }

    pub fn setColour(self: *Picker16Bit, colour: u16) void {
        self.colour = colour;
        self.sliderColour[0] = @intCast(i32, colour & 0x1F);
        self.sliderColour[1] = @intCast(i32, (colour >> 5) & 0x1F);
        self.sliderColour[2] = @intCast(i32, (colour >> 10) & 0x1F);
    }

    pub fn renderPicker(self: *Picker16Bit) void {
        if (self.showingPicker == false) {
            return;
        }

        var pos = zgui.getCursorScreenPos();
        zgui.setNextWindowPos(.{ .x = pos[0] + 200, .y = pos[1] - 46, .cond = .none });
        zgui.setNextWindowSize(.{ .w = 300, .h = 200, .cond = .none });
        if (self.setFocus) {
            self.setFocus = false;
            zgui.setNextWindowFocus();
        }
        var showWindow: bool = true;

        if (zgui.begin("Colour Picker", .{
            .popen = &showWindow,
            .flags = .{
                .no_resize = true,
                .no_collapse = true,
            },
        })) {
            zgui.text("Red   Green  Blue", .{});
            if (zgui.sliderInt3("", .{
                .v = &self.sliderColour,
                .min = 0,
                .max = 31,
            })) {
                var red = @intCast(u16, self.sliderColour[0]);
                var green = @intCast(u16, self.sliderColour[1]);
                var blue = @intCast(u16, self.sliderColour[2]);
                self.colour = ((blue << 10) & 0x7C00) + ((green << 5) & 0x03E0) + red;
            }
            zgui.sameLine(.{});
            _ = zgui.colorButton(" ", .{
                .col = colourutil.u16ToF32(self.colour),
            });
            zgui.newLine();

            zgui.pushStyleColor4f(.{
                .idx = .frame_bg,
                .c = .{ 0, 0, 0, 0 },
            });
            zgui.pushStyleColor4f(.{
                .idx = .frame_bg_hovered,
                .c = .{ 0, 0, 0, 0 },
            });
            zgui.pushStyleColor4f(.{
                .idx = .frame_bg_active,
                .c = .{ 0, 0, 0, 0 },
            });
            if (zgui.sliderFloat("sliderPicker", .{
                .v = &self.sliderPct,
                .min = 0.0,
                .max = 1.0,
                .cfmt = "",
            })) {
                self.convertSliderValueToRGB16();
            }
            zgui.popStyleColor(.{ .count = 3 });

            var wpos = zgui.getWindowPos();
            wpos[0] += 12;
            const width = 192 / 3;
            zgui.addRectFilledMultiColor(.{ .from = .{ wpos[0], wpos[1] + 80 }, .dimension = .{ .size = .{ width, 12 } } }, .{
                .list = .Window,
                .top_left = 0xFFFF0000,
                .top_right = 0xFF00FF00,
                .bottom_right = 0xFF00FF00,
                .bottom_left = 0xFFFF0000,
            });

            wpos[0] += width;
            zgui.addRectFilledMultiColor(.{ .from = .{ wpos[0], wpos[1] + 80 }, .dimension = .{ .size = .{ width, 12 } } }, .{
                .list = .Window,
                .top_left = 0xFF00FF00,
                .top_right = 0xFF0000FF,
                .bottom_right = 0xFF0000FF,
                .bottom_left = 0xFF00FF00,
            });

            wpos[0] += width;
            zgui.addRectFilledMultiColor(.{ .from = .{ wpos[0], wpos[1] + 80 }, .dimension = .{ .size = .{ width, 12 } } }, .{
                .list = .Window,
                .top_left = 0xFF0000FF,
                .top_right = 0xFFFF0000,
                .bottom_right = 0xFFFF0000,
                .bottom_left = 0xFF0000FF,
            });
        }
        zgui.end();

        if (!showWindow) {
            self.showingPicker = false;
        }
        return;
    }

    fn convertSliderValueToRGB16(self: *Picker16Bit) void {
        //0 -> 33 blue goes 31 -> 0
        //0 -> 33 green goes 0 -> 31
        //33 -> 66 green goes 31 -> 0
        //33 -> 66 red goes 0 -> 31
        //66 -> 100 red goes 31 -> 0
        //66 -> 100 blue goes -> 31
        //
        var fred: f32 = 0;
        var fgreen: f32 = 0;
        var fblue: f32 = 0;
        if (self.sliderPct < 0.33) {
            fblue = 31 - ((self.sliderPct / 0.33) * 31);
            fgreen = ((self.sliderPct / 0.33) * 31);
        } else if (self.sliderPct < 0.66) {
            var pct = self.sliderPct - 0.33;
            fgreen = 31 - ((pct / 0.33) * 31);
            fred = ((pct / 0.33) * 31);
        } else {
            var pct = self.sliderPct - 0.66;
            fred = 31 - ((pct / 0.33) * 31);
            fblue = ((pct / 0.33) * 31);
        }

        var red = @floatToInt(u16, fred);
        var green = @floatToInt(u16, fgreen);
        var blue = @floatToInt(u16, fblue);
        self.colour = ((blue << 10) & 0x7C00) + ((green << 5) & 0x03E0) + red;
        self.setColour(self.colour);
    }
};
