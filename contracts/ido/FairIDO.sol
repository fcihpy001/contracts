// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interface/IFairIDO.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/access/Ownable.sol";

error InvalidBuyAmount();

contract FairIDO is IFairIDO, Ownable {

    struct IDOUserInfo {
        uint256 amount;
        uint256 claimed;
    }

    struct IDOConfig {
        address idoToken;
        address buyToken;
        uint256 softCap;
        uint256 hardCap;
        uint256 minBuyAmount;
        uint256 maxBuyAmount;
        uint32 refundType;
        uint32 startTs;
        uint32 endTs;
        // If I spend 1 BNB how many xx tokens will I receive?
        uint32 presaleRate;
    }

    struct IDOWhiteList {
        uint32 l1ColdDown;
        uint32 l2ColdDown;
        mapping (address => uint32) l1WhiteList;
        mapping (address => uint32) l2WhiteList;
    }

    struct IDORelease {
        bool linearRelease;
        uint32 firstClaimPercent;
        uint32 cyclePercent;
        uint32 releaseDays;
    }

    struct IDOLiquidity {
        // public
        address exchange; // pancake

        // liquidity lockup
        uint32 lockupMinutes;  // liquidityLockTime must be greater than or equal to 5
        uint32 liquidityPercent;  // After the presale is completed, the corresponding BNB amount will be added to the liquidity pool, with a minimum of 51%
        // Enter the percentage of raised funds that should be allocated to Liquidity on (Min 51%, Max 100%).
        // If I spend 1 BNB on how many xx tokens will I receive? Usually this amount is lower than presale
        // rate to allow for a higher listing price on
        uint32 listingRate;
    }

    address public vault;
    IDOStatus public status; // ido status
    WhiteList public whiteListType;

    IDOConfig public idoConfig;
    IDOWhiteList public idoWhiteList;
    IDOLiquidity public idoLiquidity;
    bool invitePromotion;

    mapping (address => IDOUserInfo) presaleBuyers;
    string public ipfsURI;

    constructor(
        address admin, // owner of the contract
        address _vault,
        IDOConfig memory config,
        string memory _ipfs
    ) Ownable(admin) {
        idoConfig = config;
        vault = _vault;
        ipfsURI = _ipfs;
    }

    function cancel() external onlyOwner {

    }

    function finish() external onlyOwner {

    }

    function updateProjectInfo(string calldata _ipfs) external onlyOwner {
        ipfsURI = _ipfs;
    }

    function setWhiteList(
        WhiteList wlType,
        uint32 l1ColdDown,
        uint32 l2ColdDown) external onlyOwner {
        whiteListType = wlType;
        idoWhiteList.l1ColdDown = l1ColdDown;
        idoWhiteList.l2ColdDown = l2ColdDown;
    }

    function updateL1WhiteListMember(bool _add, address addr) external onlyOwner {
        require(whiteListType == WhiteList.NoWhiteList, "no whitelist");
        if (_add) {
            idoWhiteList.l1WhiteList[addr] = uint32(block.timestamp);
        } else {
            delete idoWhiteList.l1WhiteList[addr];
        }
    }

    function updateL2WhiteListMember(bool _add, address addr) external onlyOwner {
        require(whiteListType == WhiteList.L2WhiteList, "wrong whitelist");

        if (_add) {
            idoWhiteList.l2WhiteList[addr] = uint32(block.timestamp);
        } else {
            delete idoWhiteList.l2WhiteList[addr];
        }
    }

    function setStartEndTime(uint32 _start, uint32 _end) external onlyOwner {
        require(_start > uint32(block.timestamp) + 300, "invalid start time");
        require(_end > _start + 3600, "invalid end time");

        idoConfig.startTs = _start;
        idoConfig.endTs = _end;
    }

    function setInvitationPromotion() external onlyOwner {

    }

    function buy(uint256 amount) public payable {
        _validateIDOable(msg.sender);

        IDOUserInfo storage investInfo = presaleBuyers[msg.sender];
        uint256 total = investInfo.amount + amount;
        if (total < idoConfig.minBuyAmount || total > idoConfig.maxBuyAmount) {
            revert InvalidBuyAmount();
        }
    
        if (idoConfig.buyToken == address(0x0)) {
            require(msg.value == amount, "amount invalid");
        } else {
            SafeERC20.safeTransferFrom(IERC20(idoConfig.buyToken), msg.sender, address(this), amount);
        }

        investInfo.amount += amount;
    }

    function claimToken() public {
        _updateIDOStatus();

        require(status != IDOStatus.Running, "still running");
        IDOUserInfo storage investInfo = presaleBuyers[msg.sender];
        require(investInfo.amount > 0 && investInfo.claimed == 0, "no invest or claimed");

        if (status == IDOStatus.Failed) {
            // claim back 
            if (idoConfig.buyToken == address(0)) {
                (bool sent,) = msg.sender.call{value: investInfo.amount}("");
                require(sent, "Failed to send Ether");
            } else {
                SafeERC20.safeTransfer(IERC20(idoConfig.buyToken), msg.sender, investInfo.amount);
            }
        } else {
            // claim token
            uint256 amt = idoConfig.presaleRate * investInfo.amount;

            SafeERC20.safeTransfer(IERC20(idoConfig.idoToken), msg.sender, amt);
        }
        investInfo.claimed = 1;
    }

    function _validateIDOable(address addr) private view {
        uint32 ts = uint32(block.timestamp);
        require(ts < idoConfig.endTs, "ended");

        // level 1 whitelist
        if (whiteListType == WhiteList.NoWhiteList) {
            return;
        }
        // todo
    }

    function _updateIDOStatus() private {
        if (status == IDOStatus.Running) {
            uint32 ts = uint32(block.timestamp);
            require(ts > idoConfig.endTs, "not ended");

            if (idoConfig.buyToken == address(0)) {
                if (address(this).balance < idoConfig.softCap) {
                    status = IDOStatus.Failed;
                } else {
                    status = IDOStatus.Succeed;
                }
            } else {
                //
                if (IERC20(idoConfig.buyToken).balanceOf(address(this)) < idoConfig.softCap) {
                    status = IDOStatus.Failed;
                } else {
                    status = IDOStatus.Succeed;
                }
            }
        }
    }
}
