// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

error TokenAlreadyLocked();
error NoTokenLocked();
error LockNotExpired();

contract TokenLock is Ownable {
    using SafeERC20 for IERC20;

    event TokenLocked (
        address indexed addr,
        IERC20 indexed token,
        uint256 amount,
        uint64 expiredAt
    );

    event TokenUnLocked (
        address indexed addr,
        IERC20 indexed token,
        uint256 amount,
        uint64 ts
    );

    struct LockInfo {
        address addr;
        IERC20 token;
        uint256 amount;
        uint64 expiredAt;
    }

    mapping (address => mapping (IERC20 => LockInfo)) lockMap;

    constructor() Ownable(msg.sender) {
    }

    function lock(IERC20 token, uint256 amount, uint64 ts) public {
        require(ts > uint64(block.timestamp), "invalid expired ts");
        LockInfo storage info = lockMap[msg.sender][token];
        if (info.amount > 0) {
            revert TokenAlreadyLocked();
        }
        token.transferFrom(msg.sender, address(this), amount);

        info.amount = amount;
        info.addr = msg.sender;
        info.expiredAt = ts;
        info.token = token;

        emit TokenLocked(msg.sender, token, amount, ts);
    }

    function claim(IERC20 token) public {
        LockInfo storage info = lockMap[msg.sender][token];
        if (info.amount == 0) {
            revert NoTokenLocked();
        }
        if (uint64(block.timestamp) < info.expiredAt) {
            revert LockNotExpired();
        }
        token.transfer(msg.sender, info.amount);
        info.amount = 0;
        delete lockMap[msg.sender][token];

        emit TokenUnLocked(msg.sender, token, info.amount, uint64(block.timestamp));
    }
}
