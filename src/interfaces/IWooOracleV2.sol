// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface IWooOracleV2
{
    function price(address base) external view returns (uint256 priceNow, bool feasible);
}

