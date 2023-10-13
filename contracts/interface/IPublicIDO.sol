// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPublicIDO {
    event Contribute (
        address indexed member,
        address indexed referer,
        uint256 amount
    );

    enum WhiteList {
        NoWhiteList,
        L1WhiteList,
        L2WhiteList
    }

    enum IDOStatus {
        Running,
        Canceled,
        Failed,
        Succeed
    }
}