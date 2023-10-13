// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interface/IPublicIDO.sol";
import "../interface/uniswapv2/IUniswapV2Router01.sol";
import "../interface/uniswapv2/IUniswapV2Factory.sol";

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/access/Ownable.sol";

error InvalidBuyAmount();

contract PublicIDO is IPublicIDO, Ownable {
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
        address router;   // pancake router
        address factory;  // pancake factory

        // liquidity lockup
        uint32 lockupMinutes;  // liquidityLockTime must be greater than or equal to 5
        uint32 liquidityPercent;  // After the presale is completed, the corresponding BNB amount will be added to the liquidity pool, with a minimum of 51%
        // Enter the percentage of raised funds that should be allocated to Liquidity on (Min 51%, Max 100%).
        // If I spend 1 BNB on how many xx tokens will I receive? Usually this amount is lower than presale
        // rate to allow for a higher listing price on
        uint32 listingRate;
    }

    struct IDOInvitation {
        bool invitePromotion;
        uint32[7] rewardRatio;  // level
    }

    bool public emergencyMode; // can only be set by toplink admin contract
    address public topLinkAdmin; // toplink admin contract
    uint32 public listTs;    // list timestamp
    address public vault;    // vault address
    IDOStatus public status; // ido status
    WhiteList public whiteListType;

    IDOConfig public idoConfig;
    IDOWhiteList public idoWhiteList;
    IDOLiquidity public idoLiquidity;
    IDOInvitation public inviteConfig;

    mapping (address => IDOUserInfo) presaleBuyers;
    mapping (address => address) refererRelations;
    mapping (address => uint256) refererRewards;

    string public ipfsURI;

    constructor(
        address admin, // owner of the contract
        address _vault,
        address _topLink,
        IDOConfig memory config,
        IDOLiquidity memory _liquidity,
        string memory _ipfs,
        bool invitePromotion
    ) Ownable(admin) {
        idoConfig = config;
        idoLiquidity = _liquidity;
        vault = _vault;
        ipfsURI = _ipfs;
        topLinkAdmin = _topLink;

        inviteConfig.invitePromotion = invitePromotion;
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////

    function cancel() external onlyOwner {
        status = IDOStatus.Canceled;
    }

    function finish() external onlyOwner {

    }

    function withdrawLP() external onlyOwner {
        require(listTs > 0 && block.timestamp > listTs + 60 * idoLiquidity.lockupMinutes ,
            "cannot withdraw");
        
        address lp = IUniswapV2Factory(idoLiquidity.factory).getPair(
            idoConfig.buyToken, idoConfig.idoToken);
        require(lp != address(0), "pair is 0");

        IERC20(lp).transfer(msg.sender, IERC20(lp).balanceOf(address(this)));
    }

    function withdrawToken(address token, uint256 amt) external onlyOwner {
        require(status == IDOStatus.Canceled ||
            status == IDOStatus.Failed ||
            status == IDOStatus.Succeed, "running");
        require(emergencyMode == true, "only emergency mode");
        IERC20(token).transfer(msg.sender, amt);
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

    function addWhiteLists(
        address[] calldata l1,
        address[] calldata l2
    ) external onlyOwner {
        uint32 ts = uint32(block.timestamp);

        for (uint i = 0; i < l1.length; i ++) {
            idoWhiteList.l1WhiteList[l1[i]] = ts;
        }
        for (uint i = 0; i < l2.length; i ++) {
            idoWhiteList.l2WhiteList[l2[i]] = ts;
        }
    }

    function removeWhiteLists(
        address[] calldata l1,
        address[] calldata l2
    ) external onlyOwner {
        for (uint i = 0; i < l1.length; i ++) {
            delete idoWhiteList.l1WhiteList[l1[i]];
        }
        for (uint i = 0; i < l2.length; i ++) {
            delete idoWhiteList.l2WhiteList[l2[i]];
        }
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

    function setInvitationPromotion(bool invitable, uint32[7] memory rr) external onlyOwner {
        inviteConfig.invitePromotion = invitable;

        if (invitable == false) {
            for (uint i = 0; i < 7; i ++) {
                inviteConfig.rewardRatio[i] = 0;
            }
            return;
        }

        require(rr[0] <= 10, "invitaion reward ratio should less than 10");
        for (uint i = 0; i < 6; i ++) {
            if (rr[i] > 0) {
                require(rr[i] > rr[i+1], "invalid invitation reward percent");
            }
        }
        inviteConfig.rewardRatio = rr;
    }

    function setEmergencyMode(bool emergency) public {
        require(msg.sender == topLinkAdmin, "no auth");
        emergencyMode = emergency;
    }

    ////////////////////////////////////////////////////////////////////////////
    // PUBLIC FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////

    function contribute(uint256 amount, address referer) public payable {
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

        if (referer != address(0)) {
            // todo
            _splitRefererReward(amount, referer, msg.sender);
        }

        investInfo.amount += amount;

        emit Contribute(msg.sender, referer, amount);
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

    ////////////////////////////////////////////////////////////////////////////
    // PRIVATE FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////
    function _validateIDOable(address addr) private view {
        uint32 ts = uint32(block.timestamp);
        require(status == IDOStatus.Running, "not running");
        require(ts < idoConfig.endTs, "ended");

        // no whitelist
        if (whiteListType == WhiteList.NoWhiteList) {
            require(ts >= idoConfig.startTs, "not start");
            return;
        }
        // level 1
        if (whiteListType == WhiteList.L1WhiteList) {
            if(idoWhiteList.l1WhiteList[addr] > 0) {
                require(ts >= idoConfig.startTs, "not start");
            } else {
                // public sales
                require(ts >= idoConfig.startTs + idoWhiteList.l1ColdDown, "not public start");
            }
            return;
        }
        // level 2
        if(idoWhiteList.l1WhiteList[addr] > 0) {
            require(ts >= idoConfig.startTs, "not start");
        } else if (idoWhiteList.l2WhiteList[addr] > 0) {
            // level2 sales
            require(ts >= idoConfig.startTs + idoWhiteList.l1ColdDown, "not level 2 start");
        } else {
            require(ts >= idoConfig.startTs + idoWhiteList.l1ColdDown + idoWhiteList.l2ColdDown, 
                "not public start");
        }
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

    // list token to uniswap/pancakeswap
    function listToken() private {
        uint256 quoteAmt;
        uint256 tokenAmt;
        IERC20 idoToken = IERC20(idoConfig.idoToken);
        IUniswapV2Router01 router = IUniswapV2Router01(idoLiquidity.router);

        if (idoConfig.buyToken == address(0)) {
            quoteAmt = address(this).balance * idoLiquidity.liquidityPercent / 100;
            tokenAmt = quoteAmt * idoLiquidity.listingRate;

            idoToken.approve(address(router), tokenAmt);
            router.addLiquidityETH{value: quoteAmt}(
                idoConfig.idoToken,
                tokenAmt,
                0,
                0,
                address(this),
                block.timestamp + 60
            );
        } else {
            quoteAmt = IERC20(idoConfig.buyToken).balanceOf(address(this)) * idoLiquidity.liquidityPercent / 100;
            tokenAmt = quoteAmt * idoLiquidity.listingRate;

            IERC20(idoConfig.buyToken).approve(address(router), quoteAmt);
            idoToken.approve(address(router), tokenAmt);
            router.addLiquidity(
                idoConfig.buyToken,
                idoConfig.idoToken,
                quoteAmt,
                tokenAmt,
                0,
                0,
                address(this),
                block.timestamp + 60
            );
        }

        // update list ts
        listTs = uint32(block.timestamp);
    }

    function _splitRefererReward(
        uint256 amount,
        address referer,
        address member
    ) private {
        if (refererRelations[member] == address(0)) {
            refererRelations[member] = referer;
        } else {
            require(refererRelations[member] == referer, "referer differ with prev");
        }
        address upper = referer;
        address prevRef;
        for (uint i = 0; i < 7; i ++) {
            if (inviteConfig.rewardRatio[i] == 0) {
                break;
            }
            uint256 rewards = amount * inviteConfig.rewardRatio[i] / 100;
            refererRewards[upper] += rewards;
            if (i > 0) {
                refererRewards[prevRef] -= rewards;
            }
            prevRef = upper;
            upper = refererRelations[prevRef];
            if (upper == address(0)) {
                break;
            }
        }
    }
}
