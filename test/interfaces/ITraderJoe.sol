// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface ITraderJoe

{
    function flashLoan(ILBFlashLoanCallback receiver, bytes32 amounts, bytes calldata data) external;
}

interface ILBFlashLoanCallback {
    function LBFlashLoanCallback(
        address sender,
        IERC20 tokenX,
        IERC20 tokenY,
        bytes32 amounts,
        bytes32 totalFees,
        bytes calldata data
    ) external returns (bytes32);
} 
