const std = @import("std");
const eql = std.mem.eql;

const ColorDescriptor = packed struct {
    global_color_table_present: u1,
    color_resolution: u3,
    colors_sorted: u1,
    global_color_table_size: u3,
};

const GifInfo = struct {
    signature: [3]u8,
    version: [3]u8,
    canvas_width: u16,
    canvas_height: u16,
    color_descriptor: ColorDescriptor,

    pub fn fromReader(reader: std.fs.File.Reader) !GifInfo {
        return GifInfo{
            .signature = try reader.readBytesNoEof(3),
            .version = try reader.readBytesNoEof(3),
            .canvas_width = std.mem.readInt(u16, &(try reader.readBytesNoEof(2)), .little),
            .canvas_height = std.mem.readInt(u16, &(try reader.readBytesNoEof(2)), .little),
            .color_descriptor = @bitCast(try reader.readByte()),
        };
    }

    pub fn validate(self: @This()) !void {
        if (!eql(u8, self.signature[0..], "GIF")) {
            return error.InvalidGifSignature;
        }
        if (!(eql(u8, self.version[0..], "87a") or eql(u8, self.version[0..], "89a"))) {
            return error.UnsupportedGifVersion;
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len != 2) {
        try stderr.print("Usage: {s} <path-to-gif>\n", .{args[0]});
        return;
    }

    var file = try std.fs.cwd().openFile(args[1], .{ .mode = .read_only });
    defer file.close();

    const reader = file.reader();
    const gif = try GifInfo.fromReader(reader);
    try gif.validate();

    try stdout.print(
        "GIF Info:\n  signature: {s}\n  version: {s}\n  canvas width: {d}\n  canvas height: {d}\n" //
        ++ "  global color table present: {}\n  color resolution: {d}\n  colors sorted: {}\n" //
        ++ "  global color table size: {d}\n",
        .{
            gif.signature,
            gif.version,
            gif.canvas_width,
            gif.canvas_height,
            gif.color_descriptor.global_color_table_present == 1,
            gif.color_descriptor.color_resolution + 1,
            gif.color_descriptor.colors_sorted == 1,
            std.math.pow(u8, 2, gif.color_descriptor.global_color_table_size + 1),
        },
    );
}
