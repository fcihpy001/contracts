// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IFairIDO {

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