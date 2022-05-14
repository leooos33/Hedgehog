// SPDX-License-Identifier: Unlicense

pragma solidity =0.8.4;
pragma abicoder v2;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVault} from "../interfaces/IVault.sol";
import {IVaultMath} from "../interfaces/IVaultMath.sol";
import {IVaultTreasury} from "../interfaces/IVaultTreasury.sol";
import {IVaultStorage} from "../interfaces/IVaultStorage.sol";

import {SharedEvents} from "../libraries/SharedEvents.sol";
import {Constants} from "../libraries/Constants.sol";
import {PRBMathUD60x18} from "../libraries/math/PRBMathUD60x18.sol";
import {Faucet} from "../libraries/Faucet.sol";

import {VaultAuction} from "./VaultAuction.sol";

import "hardhat/console.sol";

contract Vault is IVault, IERC20, ERC20, ReentrancyGuard, Faucet {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice strategy constructor
     */
    constructor() ERC20("Hedging DL", "HDL") {}

    function deposit(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth,
        address to,
        uint256 _amountEthMin,
        uint256 _amountUsdcMin,
        uint256 _amountOsqthMin
    ) external override nonReentrant returns (uint256) {
        require(_amountEth > 0 || (_amountUsdc > 0 || _amountOsqth > 0), "ZA"); //Zero amount
        require(to != address(0) && to != address(this), "WA"); //Wrong address

        //Poke positions so vault's current holdings are up to date
        IVaultTreasury(vaultTreasury).pokeEthUsdc();
        IVaultTreasury(vaultTreasury).pokeEthOsqth();

        //Calculate shares to mint
        (uint256 _shares, uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = calcSharesAndAmounts(
            _amountEth,
            _amountUsdc,
            _amountOsqth,
            totalSupply()
        );

        require(amountEth >= _amountEthMin, "Amount ETH min");
        require(amountUsdc >= _amountUsdcMin, "Amount USDC min");
        require(amountOsqth >= _amountOsqthMin, "Amount oSQTH min");

        //Pull in tokens
        if (amountEth > 0) Constants.weth.transferFrom(msg.sender, vaultTreasury, amountEth);
        if (amountUsdc > 0) Constants.usdc.transferFrom(msg.sender, vaultTreasury, amountUsdc);
        if (amountOsqth > 0) Constants.osqth.transferFrom(msg.sender, vaultTreasury, amountOsqth);

        //Mint shares to user
        _mint(to, _shares);
        //Check deposit cap
        require(totalSupply() <= IVaultStorage(vaultStotage).cap(), "Cap is reached");

        emit SharedEvents.Deposit(to, _shares);
        return _shares;
    }

    /**
    @notice withdraws tokens in proportion to the vault's holdings.
    @dev provide strategy tokens, returns set of wETH, USDC, and oSQTH
    @param shares shares burned by sender
    @param amountEthMin revert if resulting amount of wETH is smaller than this
    @param amountUsdcMin revert if resulting amount of USDC is smaller than this
    @param amountOsqthMin revert if resulting amount of oSQTH is smaller than this
    */
    function withdraw(
        uint256 shares,
        uint256 amountEthMin,
        uint256 amountUsdcMin,
        uint256 amountOsqthMin
    ) external override nonReentrant {
        require(shares > 0, "0");

        uint256 totalSupply = totalSupply();

        //Burn shares
        _burn(msg.sender, shares);

        //Get token amounts to withdraw
        (uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = _getWithdrawAmounts(shares, totalSupply);

        require(amountEth >= amountEthMin, "amountEthMin");
        require(amountUsdc >= amountUsdcMin, "amountUsdcMin");
        require(amountOsqth >= amountOsqthMin, "amountOsqthMin");

        //send tokens to user
        if (amountEth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.weth, msg.sender, amountEth);
        if (amountUsdc > 0) IVaultTreasury(vaultTreasury).transfer(Constants.usdc, msg.sender, amountUsdc);
        if (amountOsqth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.osqth, msg.sender, amountOsqth);

        emit SharedEvents.Withdraw(msg.sender, shares, amountEth, amountUsdc, amountOsqth);
    }

    /**
     * @notice Used to collect accumulated protocol fees.
     * @param amountEth amount of wETH to withdraw
     * @param amountUsdc amount of USDC to withdraw
     * @param amountOsqth amount of oSQTH to withdraw
     * @param to recipient address
     */
    function collectProtocol(
        uint256 amountEth,
        uint256 amountUsdc,
        uint256 amountOsqth,
        address to
    ) external override nonReentrant onlyGovernance {
        IVaultStorage(vaultStotage).updateAccruedFees(amountUsdc, amountEth, amountOsqth);

        if (amountUsdc > 0) IVaultTreasury(vaultTreasury).transfer(Constants.usdc, to, amountUsdc);
        if (amountEth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.weth, to, amountEth);
        if (amountOsqth > 0) IVaultTreasury(vaultTreasury).transfer(Constants.osqth, to, amountOsqth);
    }

    /**
     * @notice Calculate shares and token amounts for deposit
     * @param _amountEth desired amount of wETH to deposit
     * @param _amountUsdc desired amount of USDC to deposit
     * @param _amountOsqth desired amount of oSQTH to deposit
     * @return shares to mint
     * @return required amount of wETH to deposit
     * @return required amount of USDC to deposit
     * @return required amount of oSQTH to deposit
     */
    function calcSharesAndAmounts(
        uint256 _amountEth,
        uint256 _amountUsdc,
        uint256 _amountOsqth,
        uint256 _totalSupply
    )
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        //Get total amounts of token balances
        (uint256 ethAmount, uint256 usdcAmount, uint256 osqthAmount) = IVaultMath(vaultMath).getTotalAmounts();

        //Get current prices
        (uint256 ethUsdcPrice, uint256 osqthEthPrice) = IVaultMath(vaultMath).getPrices();

        //Calculate total depositor value
        uint256 depositorValue = IVaultMath(vaultMath).getValue(
            _amountEth,
            _amountUsdc,
            _amountOsqth,
            ethUsdcPrice,
            osqthEthPrice
        );

        if (_totalSupply == 0) {
            //deposit in a 50.79% eth, 24.35% usdc, 24.86% osqth proportion
            return (
                depositorValue,
                depositorValue.mul(507924136843192000).div(ethUsdcPrice),
                depositorValue.mul(243509747368953000).div(uint256(1e30)),
                depositorValue.mul(248566115787854000).div(osqthEthPrice).div(ethUsdcPrice)
            );
        } else {
            //Calculate total strategy value
            uint256 totalValue = IVaultMath(vaultMath).getValue(
                ethAmount,
                usdcAmount,
                osqthAmount,
                ethUsdcPrice,
                osqthEthPrice
            );

            return (
                _totalSupply.mul(depositorValue).div(totalValue),
                ethAmount.mul(depositorValue).div(totalValue),
                usdcAmount.mul(depositorValue).div(totalValue),
                osqthAmount.mul(depositorValue).div(totalValue)
            );
        }
    }

    /**
     * @notice Calculate tokens amounts to withdraw
     * @param shares amount of shares to burn
     * @param totalSupply current supply of shares
     * @return amount of wETH to withdraw
     * @return amount of USDC to withdraw
     * @return amount of oSQTH to withdraw
     */
    function _getWithdrawAmounts(uint256 shares, uint256 totalSupply)
        internal
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        //Get unused token amounts (deposited, but yet not placed to pools)
        uint256 unusedAmountEth = (_getBalance(Constants.weth).sub(IVaultStorage(vaultStotage).accruedFeesEth()))
            .mul(shares)
            .div(totalSupply);
        uint256 unusedAmountUsdc = (_getBalance(Constants.usdc).sub(IVaultStorage(vaultStotage).accruedFeesUsdc()))
            .mul(shares)
            .div(totalSupply);
        uint256 unusedAmountOsqth = (_getBalance(Constants.osqth).sub(IVaultStorage(vaultStotage).accruedFeesOsqth()))
            .mul(shares)
            .div(totalSupply);

        //withdraw user share of tokens from the lp positions in current proportion
        (uint256 amountEth, uint256 amountUsdc, uint256 amountOsqth) = burnSharesInPools(shares, totalSupply);

        // Sum up total amounts owed to recipient
        return (unusedAmountEth.add(amountEth), unusedAmountUsdc.add(amountUsdc), unusedAmountOsqth.add(amountOsqth));
    }

    function burnSharesInPools(uint256 shares, uint256 totalSupply)
        internal
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 amountUsdc, uint256 amountEth0) = IVaultMath(vaultMath).burnLiquidityShare(
            Constants.poolEthUsdc,
            IVaultStorage(vaultStotage).orderEthUsdcLower(),
            IVaultStorage(vaultStotage).orderEthUsdcUpper(),
            shares,
            totalSupply
        );
        (uint256 amountEth1, uint256 amountOsqth) = IVaultMath(vaultMath).burnLiquidityShare(
            Constants.poolEthOsqth,
            IVaultStorage(vaultStotage).orderOsqthEthLower(),
            IVaultStorage(vaultStotage).orderOsqthEthUpper(),
            shares,
            totalSupply
        );

        return (amountEth0.add(amountEth1), amountUsdc, amountOsqth);
    }
}
