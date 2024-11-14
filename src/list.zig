const std = @import("std");
const assert = std.debug.assert;

const constants = @import("constants.zig");

pub const IntrusiveListNode = struct {
    prev: ?*IntrusiveListNode = null,
    next: ?*IntrusiveListNode = null,
};

pub fn IntrusiveLinkedList(
    comptime Node: type,
    comptime list_field_name: std.meta.FieldEnum(Node),
) type {
    assert(@typeInfo(Node) == .Struct);

    const list_field = @tagName(list_field_name);

    return struct {
        const ListHead = @This();

        list: IntrusiveListNode = .{},
        len: u32 = 0,

        pub fn init(head: *ListHead) void {
            head.list.next = &head.list;
            head.list.prev = &head.list;
        }

        pub fn pushFront(head: *ListHead, node: *Node) void {
            if (constants.verify) head.verify();
            if (constants.verify) assert(!head.contains(node));

            head.insert(node, &head.list, head.list.next.?);
        }

        pub fn pushBack(head: *ListHead, node: *Node) void {
            if (constants.verify) head.verify();
            if (constants.verify) assert(!head.contains(node));

            head.insert(node, head.list.prev.?, &head.list);
        }

        pub fn popFront(head: *ListHead) ?*Node {
            if (head.len == 0) {
                assert(head.list.next == &head.list);
                return null;
            }

            const removed: *Node = @fieldParentPtr(list_field, head.list.next.?);
            head.remove(removed);
            return removed;
        }

        pub fn popBack(head: *ListHead) ?*Node {
            if (head.len == 0) {
                assert(head.list.next == &head.list);
                return null;
            }

            const removed: *Node = @fieldParentPtr(list_field, head.list.prev.?);
            head.remove(removed);
            return removed;
        }

        pub fn remove(head: *ListHead, node: *Node) void {
            if (constants.verify) head.verify();
            if (constants.verify) assert(head.contains(node));

            const list_node: *IntrusiveListNode = &@field(node, list_field);
            list_node.prev.?.next = list_node.next;
            list_node.next.?.prev = list_node.prev;
            list_node.prev = null;
            list_node.next = null;
            head.len -= 1;
        }

        pub fn empty(head: *ListHead) bool {
            assert((head.len == 0) == (head.list.next == &head.list));
            return head.len == 0;
        }

        pub fn contains(head: *const ListHead, node: *const Node) bool {
            var len: u32 = 0;
            var iter: *const IntrusiveListNode = head.list.next.?;

            while (iter != &head.list) {
                const iter_node: *const Node = @fieldParentPtr(list_field, iter);
                if (iter_node == node) {
                    return true;
                }

                iter = iter.next.?;
                len += 1;
            }

            assert(len == head.len);
            return false;
        }

        fn insert(head: *ListHead, node: *Node, prev: *IntrusiveListNode, next: *IntrusiveListNode) void {
            const new: *IntrusiveListNode = &@field(node, list_field);
            assert(new.prev == null);
            assert(new.next == null);

            new.next = next;
            new.prev = prev;
            prev.next = new;
            next.prev = new;
            head.len += 1;
        }

        fn verify(head: *const ListHead) void {
            var iter = head.list.next;
            for (0..head.len) |_| {
                assert(iter != &head.list); // No cycles in the list
                iter = iter.?.next;
            }

            assert(iter == &head.list); // After 'len' steps, we should be back at the head.
        }
    };
}

test "IntrusiveLinkedList Queue" {
    const Node = struct { id: u32, list: IntrusiveListNode };
    const List = IntrusiveLinkedList(Node, .list);

    var nodes: [3]Node = undefined;
    for (&nodes, 0..) |*node, i| node.* = .{ .id = @intCast(i), .list = .{} };

    var list = List{};
    list.init();

    list.pushBack(&nodes[0]);
    list.pushBack(&nodes[1]);
    list.pushBack(&nodes[2]);

    try std.testing.expectEqual(list.popFront().?, &nodes[0]);
    try std.testing.expectEqual(list.popFront().?, &nodes[1]);
    try std.testing.expectEqual(list.popFront().?, &nodes[2]);
    try std.testing.expectEqual(list.popFront(), null);
}

test "IntrusiveLinkedList Stack [Back]" {
    const Node = struct { id: u32, list: IntrusiveListNode };
    const List = IntrusiveLinkedList(Node, .list);

    var nodes: [3]Node = undefined;
    for (&nodes, 0..) |*node, i| node.* = .{ .id = @intCast(i), .list = .{} };

    var list = List{};
    list.init();

    list.pushBack(&nodes[0]);
    list.pushBack(&nodes[1]);
    list.pushBack(&nodes[2]);

    try std.testing.expectEqual(list.popBack().?, &nodes[2]);
    try std.testing.expectEqual(list.popBack().?, &nodes[1]);
    try std.testing.expectEqual(list.popBack().?, &nodes[0]);
    try std.testing.expectEqual(list.popBack(), null);
}

test "IntrusiveLinkedList Stack [Front]" {
    const Node = struct { id: u32, list: IntrusiveListNode };
    const List = IntrusiveLinkedList(Node, .list);

    var nodes: [3]Node = undefined;
    for (&nodes, 0..) |*node, i| node.* = .{ .id = @intCast(i), .list = .{} };

    var list = List{};
    list.init();

    list.pushFront(&nodes[0]);
    list.pushFront(&nodes[1]);
    list.pushFront(&nodes[2]);

    try std.testing.expectEqual(list.popFront().?, &nodes[2]);
    try std.testing.expectEqual(list.popFront().?, &nodes[1]);
    try std.testing.expectEqual(list.popFront().?, &nodes[0]);
    try std.testing.expectEqual(list.popFront(), null);
}
