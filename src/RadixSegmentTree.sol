// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.0;

/// @notice Radix-Segment Tree implementation.
/// @author JChoy (https://github.com/JhChoy/radix-segment-tree/blob/master/src/RadixSegmentTree.sol)
library RadixSegmentTreeLib {
    error OutOfRange();
    error WrongOffset();

    // bytes32(uint256(keccak256("RadixSegmentTree")) - 1)
    uint256 internal constant ROOT = 0x93d586536338c237314802209ad99ffc16300a0123983a9edf87427344edd372;
    uint256 internal constant MAX_VALUE = 2 ** 232 - 1;

    struct RadixSegmentTree {
        mapping(bytes32 entry => uint256) branch;
    }

    struct Value {
        uint8 length; // @dev 4 < length
        uint256 value; // @dev value <= MAX_VALUE
    }

    struct Node {
        uint16 children;
        Value entry;
        uint256 addr; // @dev tree.slot or encoded value
    }

    function _checkRange(uint256 value) private pure {
        if (value > MAX_VALUE) revert OutOfRange();
    }

    function add(RadixSegmentTree storage tree, uint256 value) internal {
        _checkRange(value);
    }

    function remove(RadixSegmentTree storage tree, uint256 value) internal {
        _checkRange(value);
    }

    function update(RadixSegmentTree storage tree, uint256 from, uint256 to) internal {
        _checkRange(from);
        _checkRange(to);
    }

    function query(RadixSegmentTree storage tree, uint256 value)
        internal
        view
        returns (uint256 left, uint256 mid, uint256 right)
    {
        _checkRange(value);
    }

    function findBranch(uint256 a, uint256 b, uint8 offset) internal pure returns (uint256 branch, uint8 length) {
        require(a != b && offset < 64);
        assembly {
            // a = 0x132xx...x
            // b = 0x134xx...x
            // c = 0xffxxx...x
            let c := not(xor(a, b))
            // Generate `offset` number of 0x`f`s at the front.
            offset := sub(64, offset)
            let lastMask := not(sub(shl(shl(2, offset), 1), 1)) // ~((1 << (offset << 2)) - 1)
            if lt(c, lastMask) {
                mstore(0x00, 0xea08b33a) // `WrongOffset()`.
                revert(0x1c, 0x04)
            }
            for {} true {} {
                offset := sub(offset, 1)
                // Append 0xf to the last mask
                // lastMask + (0xf << (offset << 2))
                let mask := add(lastMask, shl(shl(2, offset), 0xf))
                // If c < mask, then a and b have different hex digits.
                // 0xffffxxx...xx < 0xfffff00...00
                if lt(c, mask) {
                    branch := and(a, lastMask)
                    // Find the length of the common prefix.
                    // `offset` cannot be 64, because a != b.
                    length := sub(63, offset)
                    break
                }
                lastMask := mask
            }
        }
        // Sanity check
        require(branch <= a && branch <= b);
    }

    function _slot(RadixSegmentTree storage tree, uint256 addr) private pure returns (bytes32 slot) {
        assembly {
            slot := tree.slot
        }
        slot = keccak256(abi.encodePacked(ROOT, slot, addr));
    }

    function _loadRootNode(RadixSegmentTree storage tree) private view returns (Node memory root) {
        uint256 data;
        uint256 slot;
        assembly {
            data := sload(tree.slot)
            slot := tree.slot
        }
        root.children = uint16(data & 0xffff);
        root.entry = _decodeValue(data >> 16);
        root.addr = slot;
    }

    function _loadNode(RadixSegmentTree storage tree, Value memory addr) private view returns (Node memory node) {
        node.addr = _encodeValue(addr);
        bytes32 slot = _slot(tree, node.addr);
        uint256 data;
        assembly {
            data := sload(slot)
        }
        node.children = uint16(data & 0xffff);
        node.entry = _decodeValue(data >> 16);
    }

    function _storeNode(RadixSegmentTree storage tree, Node memory node) private {
        bytes32 slot = _slot(tree, node.addr);
        uint256 data = _encodeValue(node.entry) << 16 | node.children;
        assembly {
            sstore(slot, data)
        }
    }

    function _encodeValue(Value memory v) private pure returns (uint256) {
        return v.value << 8 | v.length;
    }

    function _decodeValue(uint256 v) private pure returns (Value memory) {
        return Value(uint8(v & 0xff), v >> 8);
    }
}
