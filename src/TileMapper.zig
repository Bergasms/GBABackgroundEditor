const std = @import("std");
const gl = @import("gl3.zig");
const Editor = @import("Editor.zig").Editor;
const zgui = @import("zgui");
const ColourUtils = @import("ColourUtils.zig");

pub const TileMapper = struct {
    texture: gl.GLuint = undefined,
    map: [32 * 32]TileMap = undefined,
    selectedTile: ?u10 = null,

    selectedHFlip: bool = false,
    selectedVFlip: bool = false,
    selectedTileIndex: u32 = 0,
    sliderTileIndex: i32 = 0,

    const TileMap = packed struct {
        tile: u10,
        hflip: bool = false,
        vflip: bool = false,
        palette: u4 = 0,
    };

    pub fn setupTexture(self: *TileMapper, editor: *Editor) void {
        var x: u16 = 0;
        while (x < 32 * 32) : (x = x + 1) {
            self.map[x] = .{
                .tile = 0,
            };
        }

        //create a texture maybe
        var textureID = [1]gl.GLuint{0};
        gl.genTextures(1, &textureID);
        self.texture = textureID[0];

        self.resetTexture(editor);
    }

    pub fn resetTexture(self: *TileMapper, editor: *Editor) void {
        _ = editor;

        gl.bindTexture(gl.TEXTURE_2D, self.texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);

        var w: u16 = 256;
        var h: u16 = 256;

        var image: [256 * 256]u16 = undefined;

        var tileIndex: u16 = 0;
        while (tileIndex < 1024) : (tileIndex += 1) {
            var currentMap = self.map[tileIndex];
            var readX: u16 = 0;
            var readY: u16 = 0;
            var currentTile: u16 = @intCast(u16, currentMap.tile);
            var spriteBase: u16 = (currentTile % 32) * 8 + (currentTile / 32) * 256;
            var writeBase = (tileIndex % 32) * 8 + (tileIndex / 32) * 256 * 8;
            while (readY < 8) : (readY += 1) {
                while (readX < 8) : (readX += 1) {
                    var actualY = readY;
                    var actualX = readX;
                    if (currentMap.vflip) {
                        actualY = 8 - readY;
                    }
                    if (currentMap.hflip) {
                        actualX = 8 - actualX;
                    }
                    var pixelIndex = editor.spritemem[spriteBase + actualX + actualY * 256];
                    var pixel = editor.palette[pixelIndex];
                    image[writeBase + readX + readY * 256] = ColourUtils.u16ToRGB5551(pixel);
                }
                readX = 0;
            }
        }

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, w, h, 0, gl.RGBA, gl.UNSIGNED_SHORT_5_5_5_1, &image);
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }

    pub fn drawUI(self: *TileMapper, editor: *Editor) void {
        _ = self;

        var wpos = zgui.getWindowPos();
        var ins: [2]f32 = .{ 10.0, 10.0 };

        if (self.selectedTile) |tileIndex| {
            ins[1] += 70;
            //show UI for selected tile

            if (zgui.checkbox("Flip Horizontal", .{
                .v = &self.selectedHFlip,
            })) {
                std.debug.print("tindex {}\n", .{tileIndex});
                self.applyChanges();
                self.resetTexture(editor);
            }

            if (zgui.checkbox("Flip Vertical", .{
                .v = &self.selectedVFlip,
            })) {
                self.applyChanges();
                self.resetTexture(editor);
            }

            if (zgui.inputInt("Sprite", .{
                .v = &self.sliderTileIndex,
            })) {
                if (self.sliderTileIndex > 1023) {
                    self.sliderTileIndex = 1023;
                }
                if (self.sliderTileIndex < 0) {
                    self.sliderTileIndex = 0;
                }
                self.selectedTileIndex = @intCast(u32, self.sliderTileIndex);
                self.applyChanges();
                self.resetTexture(editor);
            }
        }

        zgui.image(@intToPtr(*anyopaque, self.texture), .{
            .w = 256,
            .h = 256,
        });

        if (self.selectedTile) |tileIndex| {
            var xpos = 8 * (tileIndex % 32);
            var ypos = 8 * (tileIndex / 32);
            zgui.addRect(.{
                .from = .{
                    @intToFloat(f32, xpos) + wpos[0] + ins[0],
                    @intToFloat(f32, ypos) + wpos[1] + ins[1],
                },
                .dimension = .{ .size = .{ 8, 8 } },
            }, 0xFF0000FF, .{
                .list = .Window,
                .thickness = 2.0,
            });
        }

        var pos = zgui.getMousePos();
        var adjusted: [2]f32 = .{ pos[0] - wpos[0] - ins[0], pos[1] - wpos[1] - ins[1] };

        if (adjusted[0] < 0) {
            return;
        }
        if (adjusted[1] < 0) {
            return;
        }
        if (adjusted[0] >= 256) {
            return;
        }
        if (adjusted[1] >= 256 + ins[1]) {
            return;
        }

        if (zgui.isMouseClicked(.right)) {
            if (self.selectedTile) |_| {
                self.applyChanges();
            }
            self.selectedTile = null;
        }
        if (zgui.isMouseClicked(.left)) {
            var indexX = @floatToInt(u32, adjusted[0] / 8);
            var indexY = @floatToInt(u32, adjusted[1] / 8);
            var indexInArray = indexX + indexY * 32;
            if (indexInArray > 1023) {
                return;
            }
            self.selectedTile = @intCast(u10, indexInArray);
            var tile = self.map[indexInArray];
            self.selectedHFlip = tile.hflip;
            self.selectedVFlip = tile.vflip;
            self.sliderTileIndex = @intCast(i32, tile.tile);
            self.selectedTileIndex = @intCast(u32, tile.tile);
        }
    }

    fn applyChanges(self: *TileMapper) void {
        if (self.selectedTile) |index| {
            self.map[index].hflip = self.selectedHFlip;
            self.map[index].vflip = self.selectedVFlip;
            self.map[index].tile = @intCast(u10, self.selectedTileIndex);
        }
    }

    pub fn cleanup(self: *TileMapper) void {
        gl.deleteTextures(1, &(self.texture));
    }

    pub fn dump(self: *TileMapper, file: *const std.fs.File) !void {
        const allocator = std.heap.page_allocator;
        var index: u16 = 0;
        while (index < 1024) : (index += 1) {
            var toWrite = @bitCast(u16, self.map[index]);
            var bytestring = std.fmt.allocPrintZ(allocator, "0x{X:0>4}, ", .{toWrite}) catch "";
            _ = try file.write(bytestring);
            if (index % 15 == 0) {
                _ = try file.write("\n");
            }
        }
    }
};
