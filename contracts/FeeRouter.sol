// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Routes accumulated USDC fees on Base between a stock treasury and a fee recipient.
/// @dev Direct USDC transfers to this router are treated as fees on the next flush.
contract FeeRouter is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error StockFeeTooHigh();
    error NothingToRoute();
    error RenounceDisabled();

    event StockTreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event StockFeeBpsUpdated(uint16 oldBps, uint16 newBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeRoutedToStockTreasury(address indexed treasury, uint256 amount);
    event FeeRoutedToFeeRecipient(address indexed recipient, uint256 amount);

    uint16 public constant MAX_BPS = 10_000;

    IERC20 public immutable usdc;
    address public feeRecipient;
    // Adjacent declarations pack the treasury and its share into one storage slot.
    address public stockTreasury;
    uint16 public stockFeeBps;
    uint256 public totalRoutedToStock;
    uint256 public totalRoutedToFeeRecipient;

    /// @notice Initializes USDC, two-step ownership and the fee-routing configuration.
    constructor(
        address _usdc,
        address _owner,
        address _feeRecipient,
        address _stockTreasury,
        uint16 _stockFeeBps
    ) Ownable(_owner) {
        if (_usdc == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_stockFeeBps > MAX_BPS) revert StockFeeTooHigh();

        usdc = IERC20(_usdc);
        feeRecipient = _feeRecipient;
        stockTreasury = _stockTreasury;
        stockFeeBps = _stockFeeBps;

        emit StockTreasuryUpdated(address(0), _stockTreasury);
        emit StockFeeBpsUpdated(0, _stockFeeBps);
        emit FeeRecipientUpdated(address(0), _feeRecipient);
    }

    /// @notice Updates the stock treasury; zero disables the stock share.
    function setStockTreasury(address newTreasury) external onlyOwner {
        address oldTreasury = stockTreasury;
        stockTreasury = newTreasury;
        emit StockTreasuryUpdated(oldTreasury, newTreasury);
    }

    /// @notice Updates the stock share without exceeding 100%.
    function setStockFeeBps(uint16 newBps) external onlyOwner {
        if (newBps > MAX_BPS) revert StockFeeTooHigh();
        uint16 oldBps = stockFeeBps;
        stockFeeBps = newBps;
        emit StockFeeBpsUpdated(oldBps, newBps);
    }

    /// @notice Updates the nonzero address receiving the non-stock share.
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /// @notice Ownership cannot be renounced, preserving fee administration.
    function renounceOwnership() public override {
        revert RenounceDisabled();
    }

    /// @notice Routes the entire USDC balance; either all transfers succeed or the call reverts.
    function flush() external nonReentrant returns (uint256 toStock, uint256 toFeeRecipient) {
        uint256 balance = usdc.balanceOf(address(this));
        if (balance == 0) revert NothingToRoute();
        (toStock, toFeeRecipient) = _shares(balance);

        totalRoutedToStock += toStock;
        totalRoutedToFeeRecipient += toFeeRecipient;

        if (toStock > 0) {
            usdc.safeTransfer(stockTreasury, toStock);
            emit FeeRoutedToStockTreasury(stockTreasury, toStock);
        }
        if (toFeeRecipient > 0) {
            usdc.safeTransfer(feeRecipient, toFeeRecipient);
            emit FeeRoutedToFeeRecipient(feeRecipient, toFeeRecipient);
        }
    }

    /// @notice Returns the current USDC balance and the shares a flush would route now.
    function pending() external view returns (uint256 balance, uint256 stockShare, uint256 feeRecipientShare) {
        balance = usdc.balanceOf(address(this));
        (stockShare, feeRecipientShare) = _shares(balance);
    }

    /// @dev Rounds the stock share down and assigns the entire remainder to the fee recipient.
    function _shares(uint256 balance) internal view returns (uint256 toStock, uint256 toFeeRecipient) {
        if (stockTreasury != address(0) && stockFeeBps > 0) {
            toStock = balance * stockFeeBps / MAX_BPS;
        }
        toFeeRecipient = balance - toStock;
    }
}
