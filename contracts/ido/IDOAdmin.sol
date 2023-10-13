// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "../interface/IPublicIDO.sol";
import "../interface/IIDO.sol";

import "./PublicIDO.sol";
import "./FairIDO.sol";

contract IDOAdmin is Ownable, IIDO {
    event PublicIDOCreated (
        address indexed addr,
        address indexed owner
    );

    event FairIDOCreated (
        address indexed addr,
        address indexed owner
    );

    event PrivateIDOCreated (
        address indexed addr,
        address indexed owner
    );

    constructor() Ownable(msg.sender) {
    }

    function createPublicIDO(
        address admin, // owner of the contract
        IDOConfig memory _config,
        IDOLiquidity memory _liquidity,
        string memory _ipfs,
        bool invitePromotion
    ) public onlyOwner {
        PublicIDO ido = new PublicIDO(
            admin,
            address(this),
            address(this),
            _config,
            _liquidity,
            _ipfs,
            invitePromotion
        );

        emit PublicIDOCreated(address(ido), admin);
    }

    function createFairIDO() public onlyOwner {

    }

    function createPrivateIDO() public onlyOwner {

    }

    function setIDOEmergency(address ido, bool _val) public onlyOwner {
        IPublicIDO(ido).setEmergencyMode(_val);
    }

    function withdrawIDOToken(address ido, address token, uint256 amt) public onlyOwner {
        IPublicIDO(ido).withdrawToken(token, amt);
    }

    function withdrawToken(address token, uint256 amt) external onlyOwner {
        if (token != address(0)) {
            IERC20(token).transfer(msg.sender, amt);
        } else {
            (bool sent,) = msg.sender.call{value: amt}("");
            require(sent, "Failed to send Ether");
        }
    }
}
