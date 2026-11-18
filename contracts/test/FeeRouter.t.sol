// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {FeeRouter} from "../FeeRouter.sol";
import {FeeRouterTestBase} from "./FeeRouter.Base.t.sol";

/// @dev Constructor, setters, access control, two-step ownership.
contract FeeRouterTest is FeeRouterTestBase {
    // ───────────────────────── constructor ─────────────────────────

    function test_Constructor_SetsState() public view {
        assertEq(address(router.usdc()), address(usdc));
        assertEq(router.owner(), owner);
        assertEq(router.pendingOwner(), address(0));
        assertEq(router.feeRecipient(), feeWallet);
        assertEq(router.stockTreasury(), treasury);
        assertEq(router.stockFeeBps(), STOCK_BPS);
        assertEq(router.totalRoutedToStock(), 0);
        assertEq(router.totalRoutedToFeeRecipient(), 0);
        assertEq(router.MAX_BPS(), 10_000);
    }

    function test_Constructor_EmitsInitialEvents() public {
        vm.expectEmit(true, true, false, false);
        emit FeeRouter.StockTreasuryUpdated(address(0), treasury);
        vm.expectEmit(false, false, false, true);
        emit FeeRouter.StockFeeBpsUpdated(0, STOCK_BPS);
        vm.expectEmit(true, true, false, false);
        emit FeeRouter.FeeRecipientUpdated(address(0), feeWallet);
        new FeeRouter(address(usdc), owner, feeWallet, treasury, STOCK_BPS);
    }

    function test_Constructor_RevertsZeroUsdc() public {
        vm.expectRevert(FeeRouter.ZeroAddress.selector);
        new FeeRouter(address(0), owner, feeWallet, treasury, STOCK_BPS);
    }

    function test_Constructor_RevertsZeroFeeRecipient() public {
        vm.expectRevert(FeeRouter.ZeroAddress.selector);
        new FeeRouter(address(usdc), owner, address(0), treasury, STOCK_BPS);
    }

    function test_Constructor_RevertsBpsTooHigh() public {
        vm.expectRevert(FeeRouter.StockFeeTooHigh.selector);
        new FeeRouter(address(usdc), owner, feeWallet, treasury, 10_001);
    }

    function test_Constructor_AcceptsMaxBps() public {
        FeeRouter r = new FeeRouter(address(usdc), owner, feeWallet, treasury, 10_000);
        assertEq(r.stockFeeBps(), 10_000);
    }

    function test_Constructor_RevertsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new FeeRouter(address(usdc), address(0), feeWallet, treasury, STOCK_BPS);
    }

    function test_Constructor_AcceptsZeroTreasury() public {
        FeeRouter r = new FeeRouter(address(usdc), owner, feeWallet, address(0), STOCK_BPS);
        assertEq(r.stockTreasury(), address(0));
    }

    // ───────────────────────── setStockTreasury ─────────────────────────

    function test_SetStockTreasury_Happy() public {
        address t2 = makeAddr("t2");
        vm.expectEmit(true, true, false, false, address(router));
        emit FeeRouter.StockTreasuryUpdated(treasury, t2);
        vm.prank(owner);
        router.setStockTreasury(t2);
        assertEq(router.stockTreasury(), t2);
    }

    function test_SetStockTreasury_ZeroAllowed() public {
        vm.expectEmit(true, true, false, false, address(router));
        emit FeeRouter.StockTreasuryUpdated(treasury, address(0));
        vm.prank(owner);
        router.setStockTreasury(address(0));
        assertEq(router.stockTreasury(), address(0));
    }

    function test_SetStockTreasury_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        router.setStockTreasury(stranger);
    }

    // ───────────────────────── setStockFeeBps ─────────────────────────

    function test_SetStockFeeBps_Happy() public {
        vm.expectEmit(false, false, false, true, address(router));
        emit FeeRouter.StockFeeBpsUpdated(STOCK_BPS, 1234);
        vm.prank(owner);
        router.setStockFeeBps(1234);
        assertEq(router.stockFeeBps(), 1234);
    }

    function test_SetStockFeeBps_BoundaryValues() public {
        vm.startPrank(owner);
        router.setStockFeeBps(0);
        assertEq(router.stockFeeBps(), 0);
        router.setStockFeeBps(10_000);
        assertEq(router.stockFeeBps(), 10_000);
        vm.stopPrank();
    }

    function test_SetStockFeeBps_RevertsTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.StockFeeTooHigh.selector);
        router.setStockFeeBps(10_001);
        assertEq(router.stockFeeBps(), STOCK_BPS);
    }

    function test_SetStockFeeBps_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        router.setStockFeeBps(1);
    }

    // ───────────────────────── setFeeRecipient ─────────────────────────

    function test_SetFeeRecipient_Happy() public {
        address r2 = makeAddr("r2");
        vm.expectEmit(true, true, false, false, address(router));
        emit FeeRouter.FeeRecipientUpdated(feeWallet, r2);
        vm.prank(owner);
        router.setFeeRecipient(r2);
        assertEq(router.feeRecipient(), r2);
    }

    function test_SetFeeRecipient_RevertsZero() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.ZeroAddress.selector);
        router.setFeeRecipient(address(0));
        assertEq(router.feeRecipient(), feeWallet);
    }

    function test_SetFeeRecipient_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        router.setFeeRecipient(stranger);
    }

    // ───────────────────────── two-step ownership ─────────────────────────

    function test_TransferOwnership_SetsPendingOnly() public {
        vm.expectEmit(true, true, false, false, address(router));
        emit Ownable2Step.OwnershipTransferStarted(owner, alice);
        vm.prank(owner);
        router.transferOwnership(alice);
        assertEq(router.pendingOwner(), alice);
        assertEq(router.owner(), owner);
    }

    function test_TransferOwnership_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        router.transferOwnership(stranger);
    }

    function test_PendingOwnerHasNoPowerUntilAccept() public {
        vm.prank(owner);
        router.transferOwnership(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        router.setStockFeeBps(1);
    }

    function test_AcceptOwnership_WrongAcceptorReverts() public {
        vm.prank(owner);
        router.transferOwnership(alice);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        router.acceptOwnership();
        assertEq(router.owner(), owner);
        assertEq(router.pendingOwner(), alice);
    }

    function test_AcceptOwnership_SwitchesOwnerAndOldOwnerLosesAccess() public {
        vm.prank(owner);
        router.transferOwnership(alice);

        vm.expectEmit(true, true, false, false, address(router));
        emit Ownable.OwnershipTransferred(owner, alice);
        vm.prank(alice);
        router.acceptOwnership();

        assertEq(router.owner(), alice);
        assertEq(router.pendingOwner(), address(0));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        router.setStockFeeBps(5);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        router.setStockTreasury(owner);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        router.setFeeRecipient(owner);

        vm.prank(alice);
        router.setStockFeeBps(5);
        assertEq(router.stockFeeBps(), 5);
    }

    function test_RenounceOwnership_Disabled() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.RenounceDisabled.selector);
        router.renounceOwnership();
        assertEq(router.owner(), owner);
    }

    function test_RenounceOwnership_DisabledForStranger() public {
        vm.prank(stranger);
        vm.expectRevert(FeeRouter.RenounceDisabled.selector);
        router.renounceOwnership();
        assertEq(router.owner(), owner);
    }
}
