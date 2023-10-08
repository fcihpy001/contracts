// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAntiBot {
  function setTokenOwner(address owner) external;

  function onPreTransferCheck(
    address from,
    address to,
    uint256 amount
  ) external;
}
