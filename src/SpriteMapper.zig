const std = @import("std");
const gl = @import("gl3.zig");
const Editor = @import("Editor.zig").Editor;
const zgui = @import("zgui");
const ColourUtils = @import("ColourUtils.zig");

pub const SpriteMapper = struct {
    texture: gl.GLuint = undefined,

    pub fn setupTexture(self: *SpriteMapper, editor: *Editor) void {

        //create a texture maybe
        var textureID = [1]gl.GLuint{0};
        gl.genTextures(1, &textureID);
        self.texture = textureID[0];

        self.resetTexture(editor);
    }

    pub fn resetTexture(self: *SpriteMapper, editor: *Editor) void {
        _ = editor;

        gl.bindTexture(gl.TEXTURE_2D, self.texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);

        var w: u16 = 256;
        var h: u16 = 256;

        var image: [256 * 256]u16 = undefined;
        var x: u16 = 0;
        var y: u16 = 0;
        while (y < h) : (y = y + 1) {
            while (x < w) : (x = x + 1) {
                var pixelIndex = editor.spritemem[x + (y * 256)];
                var pixel = editor.palette[pixelIndex];

                image[y * w + x] = ColourUtils.u16ToRGB5551(pixel);
            }
            x = 0;
        }

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, w, h, 0, gl.RGBA, gl.UNSIGNED_SHORT_5_5_5_1, &image);
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }

    pub fn drawUI(self: *SpriteMapper) void {
        _ = self;
        zgui.image(@intToPtr(*anyopaque, self.texture), .{
            .w = 256,
            .h = 256,
        });
    }

    pub fn cleanup(self: *SpriteMapper) void {
        gl.deleteTextures(1, &(self.texture));
    }
};
