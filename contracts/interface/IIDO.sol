// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IIDO {

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
}
