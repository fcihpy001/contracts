// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC721/IERC721Receiver.sol";

error NFTAlreadyLocked();
error NoNFTLocked();
error LockNotExpired();

contract NFTLock is Ownable {
    event NFTLocked (
        address indexed addr,
        IERC721 indexed token,
        uint256[] tokenId,
        uint64 expiredAt
    );

    event NFTUnLocked (
        address indexed addr,
        IERC721 indexed token,
        uint256[] tokenId,
        uint64 ts
    );

    struct LockInfo {
        address addr;
        IERC721 token;
        uint256[] tokenIds;
        uint64 expiredAt;
    }

    mapping (address => mapping (IERC721 => LockInfo)) lockMap;

    constructor() Ownable(msg.sender) {
    }

    function onERC721Received(
            address operator,
            address from,
            uint256 tokenId,
            bytes calldata data
        ) external pure returns (bytes4) {
            operator;
            from;
            tokenId;
            data;
        return IERC721Receiver.onERC721Received.selector;
    }

    function lock(IERC721 token, uint256[] memory tokenIds, uint64 ts) public {
        require(ts > uint64(block.timestamp), "invalid expired ts");
        LockInfo storage info = lockMap[msg.sender][token];
        if (info.addr != address(0)) {
            revert NFTAlreadyLocked();
        }
        for (uint i = 0; i < tokenIds.length; i ++) {
            token.transferFrom(msg.sender, address(this), tokenIds[i]);
        }

        info.tokenIds = tokenIds;
        info.addr = msg.sender;
        info.expiredAt = ts;
        info.token = token;

        emit NFTLocked(msg.sender, token, tokenIds, ts);
    }

    function claim(IERC721 token) public {
        LockInfo storage info = lockMap[msg.sender][token];
        if (info.addr == address(0)) {
            revert NoNFTLocked();
        }
        if (uint64(block.timestamp) < info.expiredAt) {
            revert LockNotExpired();
        }
        for (uint i = 0; i < info.tokenIds.length; i ++) {
            token.transferFrom(address(this), msg.sender, info.tokenIds[i]);
        }
        info.addr = address(0);
        delete lockMap[msg.sender][token];

        emit NFTUnLocked(msg.sender, token, info.tokenIds, uint64(block.timestamp));
    }
}
