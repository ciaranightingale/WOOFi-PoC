// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface IWooPPV2
{
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        address to,
        address rebateTo
    ) external returns (uint256 realToAmount);
}
