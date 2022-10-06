const std = @import("std");
const zgui = @import("zgui");
const gl = @import("gl3.zig");
const Picker16 = @import("ColourPicker16Bit.zig").Picker16Bit;
const colourutil = @import("ColourUtils.zig");
const TileMapper = @import("TileMapper.zig").TileMapper;
const SpriteMapper = @import("SpriteMapper.zig").SpriteMapper;

const ArrayList = std.ArrayList;

pub const Editor = struct {
    const Size = struct {
        width: u32,
        height: u32,
    };

    const MouseState = struct {
        left_active: bool = false,
        right_active: bool = false,
    };

    palette: [255]u16 = .{0} ** 255,
    paletteMode: enum { Col16, Col255 } = .Col255,
    currentPalette: u3 = 0,
    currentIndex: u8 = 0,
    picker: Picker16 = .{},

    //current sprite working on
    canvas: [8 * 8]u8 = .{0} ** 64,
    zoom: f32 = 1.0,
    canvasSize: Size = .{ .width = 8, .height = 8 },
    show_lines: bool = true,
    mouse: MouseState = .{},

    //all defined sprites
    spritemem: [256 * 256]u8 = .{0} ** (256 * 256),
    //if a sprite at index is used
    usedsprite: u1024 = 0,
    //current selected sprite
    currentSprite: u16 = 1,
    currentSpritePicker: i32 = 1,

    tile: TileMapper = .{},
    spriteMap: SpriteMapper = .{},

    pub fn setup(self: *Editor) void {
        _ = self;
        self.tile.setupTexture(self);
        self.spriteMap.setupTexture(self);
    }

    fn clickedPaletteOption(self: *Editor, index: u32) void {
        self.currentIndex = @intCast(u8, index);
        self.picker.setColour(self.palette[index]);
    }

    pub fn drawPaletteSelector255(self: *Editor) void {
        zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 1, 2 } });
        if (zgui.beginChild("palette", .{
            .border = true,
        }) == false) {
            return;
        }

        zgui.pushStyleVar2f(.{ .idx = .item_spacing, .v = .{ 1, 1 } });
        var rows: u32 = 0;
        var columns: u32 = 0;
        const items_in_row = 8;
        const dimension = zgui.getWindowWidth() / items_in_row - 2;

        var buffer: [1000]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const allocator = fba.allocator();

        var pos = zgui.getWindowPos();
        var size: [2]f32 = .{ dimension, dimension };
        var selectedPos: ?[2]f32 = undefined;
        while (columns < 16) : (columns = columns + 1) {
            while (rows < items_in_row) : (rows = rows + 1) {
                zgui.sameLine(.{});

                var index = columns * items_in_row + rows;
                var btnName = std.fmt.allocPrintZ(allocator, "{}-{}", .{ columns, rows }) catch "";
                if (zgui.invisibleButton(btnName, .{ .w = dimension, .h = dimension })) {
                    self.clickedPaletteOption(index);
                }

                var spx = pos[0] + @intToFloat(f32, rows) * size[0];
                var spy = pos[1] + @intToFloat(f32, columns) * size[1];
                zgui.addRectFilled(.{
                    .from = .{ spx, spy },
                    .dimension = .{ .size = size },
                }, colourutil.u16ToU32(self.palette[index]), .{
                    .list = .Window,
                });

                if (index == self.currentIndex) {
                    selectedPos = .{ spx, spy };
                }
            }
            rows = 0;
            zgui.newLine();
        }

        if (selectedPos) |spx| {
            zgui.addRect(.{
                .from = .{ spx[0], spx[1] },
                .dimension = .{ .size = .{ dimension + 1, dimension + 1 } },
            }, 0xFF0000FF, .{
                .list = .Window,
                .thickness = 3.0,
            });
        }

        zgui.popStyleVar(.{ .count = 1 });

        zgui.endChild();
        zgui.popStyleVar(.{ .count = 1 });
    }

    pub fn drawPaletteSelector16(self: *Editor) void {
        zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 1, 2 } });
        if (zgui.beginChild("palette", .{
            .border = true,
        }) == false) {
            return;
        }

        zgui.pushStyleVar2f(.{ .idx = .item_spacing, .v = .{ 1, 1 } });
        var rows: u32 = 0;
        var columns: u32 = 0;
        const items_in_row = 4;
        const dimension = zgui.getWindowWidth() / items_in_row - 2;

        var buffer: [1000]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const allocator = fba.allocator();

        var pos = zgui.getWindowPos();
        var size: [2]f32 = .{ dimension, dimension };

        while (columns < 4) : (columns = columns + 1) {
            while (rows < items_in_row) : (rows = rows + 1) {
                zgui.sameLine(.{});

                var index = columns * items_in_row + rows;
                var btnName = std.fmt.allocPrintZ(allocator, "{}-{}", .{ columns, rows }) catch "";
                if (zgui.invisibleButton(btnName, .{ .w = dimension, .h = dimension })) {
                    self.clickedPaletteOption(index);
                }

                var spx = pos[0] + @intToFloat(f32, rows) * size[0];
                var spy = pos[1] + @intToFloat(f32, columns) * size[1];
                zgui.addRectFilled(.{
                    .from = .{ spx, spy },
                    .dimension = .{ .size = size },
                }, colourutil.u16ToU32(self.palette[index]), .{ .list = .Window });
            }
            rows = 0;
            zgui.newLine();
        }
        zgui.popStyleVar(.{ .count = 1 });

        zgui.endChild();
        zgui.popStyleVar(.{ .count = 1 });
    }

    pub fn drawSelectedColour(self: *Editor) void {
        if (zgui.colorButton("Set Colour", .{
            .col = colourutil.u16ToF32(self.palette[self.currentIndex]),
            .flags = .{
                .no_side_preview = true,
            },
            .w = 40,
            .h = 40,
        })) {
            self.picker.show(self.palette[self.currentIndex]);
        }

        self.picker.renderPicker();

        self.palette[self.currentIndex] = self.picker.colour;
    }

    pub fn setupScreen(self: *Editor, width: f32, height: f32) void {
        zgui.setNextWindowPos(.{ .x = 0.0, .y = 0.0, .cond = .none });
        zgui.setNextWindowSize(.{ .w = width, .h = height, .cond = .none });

        if (zgui.begin("_", .{ .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
        } }) == false) {
            return;
        }

        if (zgui.beginChild("leftPanel", .{
            .w = 200,
            .border = true,
        }) == false) {
            return;
        }

        if (zgui.button("export", .{})) {
            self.dumpContents() catch |err| {
                std.debug.print("{}", .{err});
                return;
            };
        }

        _ = zgui.checkbox("Show Lines", .{
            .v = &self.show_lines,
        });

        self.drawCurrentModeSelector();
        self.drawCurrentIndexSelector();

        zgui.text("Palette", .{});
        zgui.separator();

        self.drawSelectedColour();

        if (self.paletteMode == .Col16) {
            self.drawPaletteSelector16();
        } else {
            self.drawPaletteSelector255();
        }

        zgui.endChild();

        zgui.sameLine(.{});
        if (zgui.beginChild("rholder", .{ .border = true, .flags = .{} }) == false) {
            return;
        }

        if (zgui.beginChild("rightPanel", .{ .h = 300, .border = true, .flags = .{
            .always_horizontal_scrollbar = true,
        } }) == false) {
            return;
        }

        self.drawCanvas();

        zgui.endChild();

        if (zgui.beginChild("map", .{ .border = true, .flags = .{} }) == false) {
            return;
        }

        self.tile.drawUI(self);
        zgui.sameLine(.{});
        self.spriteMap.drawUI();

        zgui.endChild();
        zgui.endChild();
        zgui.end();
    }

    fn drawCanvas(self: *Editor) void {

        //draw canvas
        var wpos = zgui.getWindowPos();
        var ins: [2]f32 = .{ 5.0, 5.0 };
        var xpos: u32 = 0;
        var ypos: u32 = 0;
        var width: f32 = 10 * self.zoom;

        //draw backing panel to allow scroll
        _ = zgui.beginChild("_", .{
            .w = width * @intToFloat(f32, self.canvasSize.width),
            .h = width * @intToFloat(f32, self.canvasSize.height),
        });
        zgui.endChild();

        ins[0] = ins[0] - zgui.getScrollX();
        ins[1] = ins[1] - zgui.getScrollY();

        while (ypos < self.canvasSize.height) : (ypos = ypos + 1) {
            while (xpos < self.canvasSize.width) : (xpos += 1) {
                //get colour
                var colour = self.colourForPixel(xpos, ypos);

                var xposition = @intToFloat(f32, xpos) * width + wpos[0] + ins[0];
                var yposition = @intToFloat(f32, ypos) * width + wpos[1] + ins[1];
                zgui.addRectFilled(.{
                    .from = .{ xposition, yposition },
                    .dimension = .{ .size = .{ width, width } },
                }, colour, .{
                    .list = .Window,
                });
            }
            xpos = 0;
        }

        //draw set positions.
        if (self.show_lines) {
            xpos = 0;
            ypos = 0;
            while (xpos < self.canvasSize.width + 1) : (xpos = xpos + 1) {
                var xposition = @intToFloat(f32, xpos) * width + wpos[0] + ins[0];
                zgui.addLine(.{
                    .from = .{ xposition, wpos[1] + ins[1] },
                    .to = .{ xposition, wpos[1] + ins[1] + width * @intToFloat(f32, self.canvasSize.width) },
                }, 0xFFFFFFFF, .{ .list = .Window });
            }
            while (ypos < self.canvasSize.height + 1) : (ypos = ypos + 1) {
                var yposition = @intToFloat(f32, ypos) * width + wpos[1] + ins[1];
                zgui.addLine(.{
                    .from = .{ wpos[0] + ins[0], yposition },
                    .to = .{ wpos[0] + ins[0] + width * @intToFloat(f32, self.canvasSize.height), yposition },
                }, 0xFFFFFFFF, .{ .list = .Window });
            }
        }

        if (self.picker.showingPicker) {
            return;
        }

        //handle mouse input
        var pos = zgui.getMousePos();
        var adjusted: [2]f32 = .{ pos[0] - wpos[0] - ins[0], pos[1] - wpos[1] - ins[1] };
        if (adjusted[0] < 0) {
            return;
        }
        if (adjusted[1] < 0) {
            return;
        }
        if (adjusted[1] > 300) {
            return;
        }

        if (zgui.isMouseDragging(.left, .{})) {
            self.mouse.left_active = true;
            var indexX = @floatToInt(u32, adjusted[0] / width);
            var indexY = @floatToInt(u32, adjusted[1] / width);
            if (coordsIn(indexX, indexY, .{ 0, 0, self.canvasSize.width - 1, self.canvasSize.height - 1 })) {
                self.canvas[indexY * self.canvasSize.width + indexX] = self.currentIndex;
            }
        } else {
            if (self.mouse.left_active) {
                self.mouse.left_active = false;
                self.refreshSpriteMap();
            }
        }

        if (zgui.isMouseClicked(.left)) {
            self.mouse.left_active = true;
            var indexX = @floatToInt(u32, adjusted[0] / width);
            var indexY = @floatToInt(u32, adjusted[1] / width);
            if (coordsIn(indexX, indexY, .{ 0, 0, self.canvasSize.width - 1, self.canvasSize.height - 1 })) {
                self.canvas[indexY * self.canvasSize.width + indexX] = self.currentIndex;
            }
        } else {
            if (self.mouse.left_active) {
                self.mouse.left_active = false;
                self.refreshSpriteMap();
            }
        }

        if (zgui.isMouseClicked(.right)) {
            self.mouse.right_active = true;
            var indexX = @floatToInt(u32, adjusted[0] / width);
            var indexY = @floatToInt(u32, adjusted[1] / width);
            if (coordsIn(indexX, indexY, .{ 0, 0, self.canvasSize.width - 1, self.canvasSize.height - 1 })) {
                self.floodFill(indexX, indexY) catch |err| {
                    std.debug.print("{}", .{err});
                    return;
                };
            }
        } else {
            if (self.mouse.right_active) {
                self.mouse.right_active = false;
                self.refreshSpriteMap();
            }
        }

        if (zgui.getMouseWheel() < 0) {
            self.zoom = self.zoom - 0.1;
            if (self.zoom < 0.5) {
                self.zoom = 0.5;
            }
        }

        if (zgui.getMouseWheel() > 0) {
            self.zoom = self.zoom + 0.1;
            if (self.zoom > 3.0) {
                self.zoom = 3.0;
            }
        }
    }

    const PointPair = struct {
        x: u32,
        y: u32,
    };

    fn floodFill(self: *Editor, xin: u32, yin: u32) !void {
        const allocator = std.heap.page_allocator;
        var list = ArrayList(PointPair).init(allocator);
        defer list.deinit();

        var initial = self.canvas[yin * self.canvasSize.width + xin];
        if (initial == self.currentIndex) {
            return;
        }
        try list.append(.{ .x = xin, .y = yin });

        while (list.items.len > 0) {
            var next = list.pop();
            self.canvas[next.y * self.canvasSize.width + next.x] = self.currentIndex;

            if (next.y > 0) {
                var checkX = next.x;
                var checkY = next.y - 1;
                var sample = self.canvas[checkY * self.canvasSize.width + checkX];
                if (sample == initial) {
                    try list.append(.{ .x = checkX, .y = checkY });
                }
            }

            if (next.y < self.canvasSize.height - 1) {
                var checkX = next.x;
                var checkY = next.y + 1;
                var sample = self.canvas[checkY * self.canvasSize.width + checkX];
                if (sample == initial) {
                    try list.append(.{ .x = checkX, .y = checkY });
                }
            }

            if (next.x > 0) {
                var checkX = next.x - 1;
                var checkY = next.y;
                var sample = self.canvas[checkY * self.canvasSize.width + checkX];
                if (sample == initial) {
                    try list.append(.{ .x = checkX, .y = checkY });
                }
            }

            if (next.x < self.canvasSize.width - 1) {
                var checkX = next.x + 1;
                var checkY = next.y;
                var sample = self.canvas[checkY * self.canvasSize.width + checkX];
                if (sample == initial) {
                    try list.append(.{ .x = checkX, .y = checkY });
                }
            }
        }

        self.refreshSpriteMap();
    }

    fn coordsIn(x: u32, y: u32, b: [4]u32) bool {
        if (x < b[0]) {
            return false;
        }
        if (y < b[1]) {
            return false;
        }
        if (x > b[2]) {
            return false;
        }
        if (y > b[3]) {
            return false;
        }
        return true;
    }

    fn colourForPixel(self: *Editor, xpos: u32, ypos: u32) u32 {
        var value: u8 = self.canvas[ypos * self.canvasSize.width + xpos];
        var paletteColour = self.palette[value];

        return colourutil.u16ToU32(paletteColour);
    }

    fn drawCurrentIndexSelector(self: *Editor) void {
        if (zgui.inputInt("Sprite", .{
            .v = &self.currentSpritePicker,
        })) {
            if (self.currentSpritePicker > 1023) {
                self.currentSpritePicker = 1023;
            }
            if (self.currentSpritePicker < 1) {
                self.currentSpritePicker = 1;
            }
            self.currentSprite = @intCast(u16, self.currentSpritePicker);
            self.selectCurrentIndex(self.currentSprite);
        }
    }

    fn drawCurrentModeSelector(self: *Editor) void {
        var currentMode = if (self.paletteMode == .Col255) "8 Bit" else "4 Bit";

        if (zgui.beginCombo("Mode", .{
            .preview_value = currentMode,
        })) {
            if (zgui.selectable("8 Bit", .{
                .selected = self.paletteMode == .Col255,
            })) {
                self.paletteMode = .Col255;
            }

            if (zgui.selectable("4 Bit", .{
                .selected = self.paletteMode == .Col16,
            })) {
                self.paletteMode = .Col16;
            }
            zgui.endCombo();
        }
    }

    fn dumpContents(self: *Editor) !void {
        _ = try std.fs.cwd().deleteFile("export.txt");

        const file = try std.fs.cwd().createFile(
            "export.txt",
            .{ .read = true },
        );
        defer file.close();

        const allocator = std.heap.page_allocator;

        var rpos: u32 = 0;
        _ = try file.write("const sprite = [_]u16{\n");
        while (rpos < 1024) : (rpos += 1) {
            var xread: u16 = 0;
            var yread: u16 = 0;
            while (yread < 8) : (yread += 1) {
                while (xread < 8) : (xread += 2) {
                    var read = (rpos % 32) * 8 + (rpos / 32) * 8 * 256;
                    var left = self.spritemem[read + yread * 256 + xread + 1];
                    var right = self.spritemem[read + yread * 256 + xread];
                    var lshift: u16 = @intCast(u16, left) << 8;
                    var sright: u16 = @intCast(u16, right);
                    lshift += sright;

                    var bytestring = std.fmt.allocPrintZ(allocator, "0x{X:0>4}, ", .{lshift}) catch "";
                    _ = try file.write(bytestring);
                }
                xread = 0;
                _ = try file.write("\n");
            }

            _ = try file.write("\n");
        }
        _ = try file.write("};\n");

        _ = try file.write("const palette = [_]u16{\n");
        var pMax: u32 = if (self.paletteMode == .Col255) 255 else 16;
        var xpos: u16 = 0;
        while (xpos < pMax) {
            var byteval: u16 = self.palette[xpos];
            var bytestring = std.fmt.allocPrintZ(allocator, "0x{X:0>4}, ", .{byteval}) catch "";
            _ = try file.write(bytestring);

            xpos += 1;

            if (xpos % 15 == 0) {
                _ = try file.write("\n");
            }
        }
        _ = try file.write("};\n");

        _ = try file.write("const map = [_]u16{\n");
        try self.tile.dump(&file);
        _ = try file.write("};\n");
    }

    fn refreshSpriteMap(self: *Editor) void {
        var index: u16 = self.currentSprite;
        var xpos = index % 32;
        var ypos = index / 32;
        var base = xpos * 8 + ypos * 256 * 8;
        var itery: u16 = 0;
        var iterx: u16 = 0;
        while (itery < 8) : (itery += 1) {
            while (iterx < 8) : (iterx += 1) {
                self.spritemem[base + iterx + (itery * 256)] = self.canvas[iterx + itery * 8];
            }
            iterx = 0;
        }
        self.spriteMap.resetTexture(self);
        self.tile.resetTexture(self);
    }

    fn selectCurrentIndex(self: *Editor, indexNum: u16) void {
        self.currentSprite = indexNum;
        var xpos = indexNum % 32;
        var ypos = indexNum / 32;
        var base = xpos * 8 + ypos * 256 * 8;
        var itery: u16 = 0;
        var iterx: u16 = 0;
        while (itery < 8) : (itery += 1) {
            while (iterx < 8) : (iterx += 1) {
                self.canvas[iterx + itery * 8] = self.spritemem[base + iterx + (itery * 256)];
            }
            iterx = 0;
        }
    }
};
