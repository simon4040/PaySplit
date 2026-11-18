// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SplitFactory} from "../SplitFactory.sol";
import {StrPoints} from "../StrPoints.sol";
import {MockTokenMessengerV2} from "../test-helpers/MockTokenMessengerV2.sol";
import {FeeRouterStackBase} from "./FeeRouter.Base.t.sol";

/// @dev FeeRouter wired as the feeRecipient of a real SplitFactory (+ StrPoints).
contract FeeRouterIntegrationTest is FeeRouterStackBase {
    function setUp() public override {
        super.setUp();
        _fundUser(dave, 10_000_000 * UNIT);
        _fundUser(carol, 10_000_000 * UNIT);
    }

    /// @dev Same action sequence on one stack; returns total fees it should have charged.
    function _runOps(SplitFactory f, StrPoints p, uint256 id) internal returns (uint256 fees) {
        uint256 bps = f.feeBps();
        _depFactory(f, id, dave, 100 * UNIT);
        _depSp(p, f, id, dave, 250 * UNIT);
        _bridge(p, carol, 1000 * UNIT);
        _depSp(p, f, id, carol, 7 * UNIT + 13);
        _bridge(p, dave, 333_333_333);
        _depFactory(f, id, carol, 3);
        fees = (100 * UNIT) * bps / 10_000 + (250 * UNIT) * bps / 10_000 + (1000 * UNIT) * bps / 10_000
            + (7 * UNIT + 13) * bps / 10_000 + 333_333_333 * bps / 10_000 + uint256(3) * bps / 10_000;
    }

    // (1) factory.deposit sends exactly the fee to the router

    function test_FactoryDeposit_Fee50Bps_GoesToRouter() public {
        vm.expectEmit(true, true, false, true, address(factory));
        emit SplitFactory.Deposited(splitId, dave, 995 * UNIT, 5 * UNIT);
        _depFactory(factory, splitId, dave, 1000 * UNIT);

        assertEq(usdc.balanceOf(address(router)), 5 * UNIT);
        assertEq(factory.splitBalance(splitId), 995 * UNIT);
        assertEq(usdc.balanceOf(address(factory)), 995 * UNIT);
        assertEq(usdc.balanceOf(plainWallet), 0);
        assertEq(usdc.balanceOf(treasury), 0, "no auto-routing before flush");
        assertEq(usdc.balanceOf(feeWallet), 0);
    }

    function test_FactoryDeposit_Fee500Bps_GoesToRouter() public {
        vm.prank(factoryOwner);
        factory.setFeeBps(500);
        _depFactory(factory, splitId, dave, 1000 * UNIT);

        assertEq(usdc.balanceOf(address(router)), 50 * UNIT);
        assertEq(factory.splitBalance(splitId), 950 * UNIT);
        assertEq(usdc.balanceOf(address(factory)), 950 * UNIT);
    }

    // (2) StrPoints.depositToSplit

    function test_StrPointsDeposit_FeeGoesToRouter() public {
        _depSp(sp, factory, splitId, dave, 200 * UNIT);

        assertEq(usdc.balanceOf(address(router)), 1 * UNIT);
        assertEq(factory.splitBalance(splitId), 199 * UNIT);
        assertEq(sp.pointsOf(dave), 75, "tier-3 deposit points");
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(usdc.balanceOf(plainWallet), 0);
    }

    // (3) StrPoints.bridge

    function test_Bridge_PlatformFeeGoesToRouter_RestBurned() public {
        _bridge(sp, dave, 400 * UNIT);

        assertEq(usdc.balanceOf(address(router)), 2 * UNIT, "fee at router");
        assertEq(messenger.callCount(), 1);
        assertEq(messenger.lastAmount(), 398 * UNIT);
        assertEq(messenger.totalBurned(), 398 * UNIT);
        assertEq(usdc.balanceOf(address(messenger)), 398 * UNIT);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(usdc.balanceOf(plainWallet), 0);
        assertEq(sp.pointsOf(dave), 100, "bridge points on gross");
    }

    function test_Bridge_ReadsFeeRecipientLive() public {
        // Bridge once to the router, repoint the factory, bridge again.
        _bridge(sp, dave, 400 * UNIT);
        vm.prank(factoryOwner);
        factory.setFeeRecipient(plainWallet);
        _bridge(sp, dave, 400 * UNIT);

        assertEq(usdc.balanceOf(address(router)), 2 * UNIT);
        assertEq(usdc.balanceOf(plainWallet), 2 * UNIT);
    }

    // (4) conservation across many deposits/bridges then a single flush

    function test_Flush_AfterManyActions_PaysExactSharesOfTotalFees() public {
        uint256 fees = _runOps(factory, sp, splitId);
        assertGt(fees, 0);
        assertEq(usdc.balanceOf(address(router)), fees, "router collected every fee");

        (uint256 b, uint256 ps, uint256 pf) = router.pending();
        assertEq(b, fees);
        assertEq(ps + pf, fees);

        uint256 expStock = fees * STOCK_BPS / 10_000;
        (uint256 s, uint256 f) = router.flush();
        assertEq(s, expStock);
        assertEq(f, fees - expStock);
        assertEq(usdc.balanceOf(treasury), expStock);
        assertEq(usdc.balanceOf(feeWallet), fees - expStock);
        assertEq(usdc.balanceOf(treasury) + usdc.balanceOf(feeWallet), fees, "conservation");
        assertEq(usdc.balanceOf(address(router)), 0);
        assertEq(router.totalRoutedToStock() + router.totalRoutedToFeeRecipient(), fees);
    }

    function test_Flush_FlushMidwayThenMoreFees_ConservesTotal() public {
        _depFactory(factory, splitId, dave, 1000 * UNIT);
        router.flush();
        _bridge(sp, carol, 777 * UNIT + 7);
        _depSp(sp, factory, splitId, dave, 55 * UNIT);
        router.flush();
        uint256 fees = 5 * UNIT + (777 * UNIT + 7) * 50 / 10_000 + 55 * UNIT * 50 / 10_000;
        assertEq(usdc.balanceOf(treasury) + usdc.balanceOf(feeWallet), fees);
        assertEq(usdc.balanceOf(address(router)), 0);
    }

    // (5) switching feeRecipient away from the router bypasses it

    function test_SwitchFeeRecipientBack_FeesBypassRouter() public {
        _depFactory(factory, splitId, dave, 1000 * UNIT);
        vm.prank(factoryOwner);
        factory.setFeeRecipient(plainWallet);

        _depFactory(factory, splitId, dave, 1000 * UNIT);
        _depSp(sp, factory, splitId, dave, 200 * UNIT);
        _bridge(sp, dave, 400 * UNIT);

        assertEq(usdc.balanceOf(address(router)), 5 * UNIT, "only the first fee");
        assertEq(usdc.balanceOf(plainWallet), 5 * UNIT + 1 * UNIT + 2 * UNIT);
    }

    // (6) router changes nothing except where the fee goes

    function test_RouterChangesNothingExceptFeeDestination() public {
        uint256 feesA = _runOps(factory, sp, splitId);
        uint256 feesB = _runOps(refFactory, refSp, refSplitId);
        assertEq(feesA, feesB);

        assertEq(sp.pointsOf(dave), refSp.pointsOf(dave), "dave points");
        assertEq(sp.pointsOf(carol), refSp.pointsOf(carol), "carol points");
        assertGt(sp.pointsOf(dave), 0);
        assertEq(factory.splitBalance(splitId), refFactory.splitBalance(refSplitId), "net credited");
        assertEq(usdc.balanceOf(address(factory)), usdc.balanceOf(address(refFactory)));
        assertEq(messenger.totalBurned(), refMessenger.totalBurned(), "burn total");
        assertEq(messenger.lastAmount(), refMessenger.lastAmount(), "last burn");
        assertEq(messenger.callCount(), refMessenger.callCount());
        assertEq(usdc.balanceOf(address(router)), usdc.balanceOf(refWallet), "fee only relocates");
        assertEq(usdc.balanceOf(refWallet), feesB);
    }

    function test_RouterStack_FlushedFeesEqualReferenceWalletFees() public {
        _runOps(factory, sp, splitId);
        _runOps(refFactory, refSp, refSplitId);
        router.flush();
        assertEq(usdc.balanceOf(treasury) + usdc.balanceOf(feeWallet), usdc.balanceOf(refWallet));
    }

    // (7) bps 0 / zero treasury == no-router outcome for the fee recipient

    function test_ZeroStockBps_FeeRecipientEqualsNoRouterResult() public {
        vm.prank(owner);
        router.setStockFeeBps(0);
        _runOps(factory, sp, splitId);
        _runOps(refFactory, refSp, refSplitId);
        router.flush();
        assertEq(usdc.balanceOf(feeWallet), usdc.balanceOf(refWallet));
        assertEq(usdc.balanceOf(treasury), 0);
    }

    function test_ZeroTreasury_FeeRecipientEqualsNoRouterResult() public {
        vm.prank(owner);
        router.setStockTreasury(address(0));
        _runOps(factory, sp, splitId);
        _runOps(refFactory, refSp, refSplitId);
        router.flush();
        assertEq(usdc.balanceOf(feeWallet), usdc.balanceOf(refWallet));
        assertEq(usdc.balanceOf(treasury), 0);
    }

    function test_FactoryZeroFee_RouterReceivesNothing() public {
        vm.prank(factoryOwner);
        factory.setFeeBps(0);
        _depFactory(factory, splitId, dave, 1000 * UNIT);
        _bridge(sp, dave, 1000 * UNIT);
        assertEq(usdc.balanceOf(address(router)), 0);
        vm.expectRevert();
        router.flush();
    }

    function test_FlushDoesNotTouchSplitFunds() public {
        _depFactory(factory, splitId, dave, 1000 * UNIT);
        router.flush();
        assertEq(factory.splitBalance(splitId), 995 * UNIT);
        assertEq(usdc.balanceOf(address(factory)), 995 * UNIT);
    }
}
