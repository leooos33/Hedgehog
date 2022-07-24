// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IEulerDToken {
    function borrow(uint256 subAccountId, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function repay(uint256 subAccountId, uint256 amount) external;
}

interface IExec {
    function deferLiquidityCheck(address account, bytes memory data) external;
}

interface IEulerMarkets {
    function activateMarket(address underlying) external returns (address);

    function underlyingToEToken(address underlying) external view returns (address);

    function underlyingToDToken(address underlying) external view returns (address);

    function enterMarket(uint256 subAccountId, address newMarket) external;

    function exitMarket(uint256 subAccountId, address oldMarket) external;
}
