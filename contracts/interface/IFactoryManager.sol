// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IFactoryManager {
  function assignTokensToOwner(address owner, address token, uint8 tokenType) external;
}