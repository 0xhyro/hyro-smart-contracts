//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.15;

interface IHyroFactory {

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getWhitelistedTokens() external view returns (address[] calldata);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
