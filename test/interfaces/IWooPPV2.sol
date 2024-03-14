// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface IWooPPV2
{
    struct TokenInfo {
        uint192 reserve; // balance reserve
        uint16 feeRate; // 1 in 100000; 10 = 1bp = 0.01%; max = 65535
    }

    function tokenInfos(address token) external view returns (TokenInfo memory);
    
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        address to,
        address rebateTo
    ) external returns (uint256 realToAmount);
}
