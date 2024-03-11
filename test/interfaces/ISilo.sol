// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface ISilo
{
    function deposit(address _asset, uint256 _amount, bool _collateralOnly) external returns (uint256 collateralAmount, uint256 collateralShare);
    function borrow(address _asset, uint256 _amount) external returns (uint256 debtAmount, uint256 debtShare);
    function liquidity(address _asset) external view returns (uint256);
    function repay(address _asset, uint256 _amount) external returns (uint256 repaidAmount, uint256 burnedShare);
    function withdraw(address _asset, uint256 _amount, bool _collateralOnly) external returns (uint256 withdrawnAmount, uint256 withdrawnShare);
}
