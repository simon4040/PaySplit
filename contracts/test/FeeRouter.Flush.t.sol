// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeRouter} from "../FeeRouter.sol";
import {MockBlocklistERC20} from "../test-helpers/MockBlocklistERC20.sol";
import {FeeRouterTestBase} from "./FeeRouter.Base.t.sol";

/// @dev flush(), pending(), reconfiguration, blocklisted destinations.
contract FeeRouterFlushTest is FeeRouterTestBase {
    // ───────────────────────── flush basics ─────────────────────────

    function test_Flush_RevertsWhenEmpty() public {
        vm.expectRevert(FeeRouter.NothingToRoute.selector);
        router.flush();
    }

    function test_Flush_Split3000() public {
        _sendFees(1000 * UNIT);
        vm.expectEmit(true, false, false, true, address(router));
        emit FeeRouter.FeeRoutedToStockTreasury(treasury, 300 * UNIT);
        vm.expectEmit(true, false, false, true, address(router));
        emit FeeRouter.FeeRoutedToFeeRecipient(feeWallet, 700 * UNIT);
        (uint256 s, uint256 f) = _flush();

        assertEq(s, 300 * UNIT);
        assertEq(f, 700 * UNIT);
        assertEq(usdc.balanceOf(treasury), 300 * UNIT);
        assertEq(usdc.balanceOf(feeWallet), 700 * UNIT);
        assertEq(usdc.balanceOf(address(router)), 0);
        assertEq(router.totalRoutedToStock(), 300 * UNIT);
        assertEq(router.totalRoutedToFeeRecipient(), 700 * UNIT);
    }

    function test_Flush_FullBps_AllToTreasury_NoFeeRecipientEvent() public {
        vm.prank(owner);
        router.setStockFeeBps(10_000);
        _sendFees(777 * UNIT);
        vm.recordLogs();
        (uint256 s, uint256 f) = _flush();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(s, 777 * UNIT);
        assertEq(f, 0);
        assertEq(usdc.balanceOf(treasury), 777 * UNIT);
        assertEq(usdc.balanceOf(feeWallet), 0);
        assertEq(_count(logs, SIG_STOCK), 1);
        assertEq(_count(logs, SIG_FEE), 0);
    }

    function test_Flush_ZeroTreasury_AllToFeeRecipient() public {
        vm.prank(owner);
        router.setStockTreasury(address(0));
        _sendFees(1000 * UNIT);
        vm.recordLogs();
        (uint256 s, uint256 f) = _flush();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(s, 0);
        assertEq(f, 1000 * UNIT);
        assertEq(usdc.balanceOf(feeWallet), 1000 * UNIT);
        assertEq(usdc.balanceOf(address(0)), 0);
        assertEq(_count(logs, SIG_STOCK), 0);
        assertEq(_count(logs, SIG_FEE), 1);
        assertEq(router.totalRoutedToStock(), 0);
    }

    function test_Flush_ZeroBps_AllToFeeRecipient() public {
        vm.prank(owner);
        router.setStockFeeBps(0);
        _sendFees(1000 * UNIT);
        vm.recordLogs();
        (uint256 s, uint256 f) = _flush();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(s, 0);
        assertEq(f, 1000 * UNIT);
        assertEq(usdc.balanceOf(treasury), 0);
        assertEq(_count(logs, SIG_STOCK), 0);
    }

    function test_Flush_TinyBalance_RoundsStockToZero() public {
        // 3 * 3000 / 10000 = 0
        for (uint256 amt = 1; amt <= 3; ++amt) {
            _sendFees(amt);
            vm.recordLogs();
            (uint256 s, uint256 f) = _flush();
            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(s, 0, "stock");
            assertEq(f, amt, "fee");
            assertEq(_count(logs, SIG_STOCK), 0);
            assertEq(_count(logs, SIG_FEE), 1);
        }
        assertEq(usdc.balanceOf(treasury), 0);
        assertEq(usdc.balanceOf(feeWallet), 6);
        assertEq(usdc.balanceOf(address(router)), 0);
    }

    function test_Flush_SmallestBalanceWithNonZeroStock() public {
        // 4 * 3000 / 10000 = 1 (floor of 1.2)
        _sendFees(4);
        (uint256 s, uint256 f) = _flush();
        assertEq(s, 1);
        assertEq(f, 3);
    }

    function test_Flush_OddAmount_RemainderToFeeRecipient() public {
        // 12345 * 3000 / 10000 = 3703 (3703.5 floored)
        _sendFees(12_345);
        (uint256 s, uint256 f) = _flush();
        assertEq(s, 3703);
        assertEq(f, 8642);
        assertEq(s + f, 12_345);
        assertEq(usdc.balanceOf(address(router)), 0, "nothing stranded");
        assertEq(usdc.balanceOf(treasury) + usdc.balanceOf(feeWallet), 12_345);
    }

    function test_Flush_RepeatedAccumulatesTotals() public {
        _sendFees(1000 * UNIT);
        _flush();
        _sendFees(555);
        (uint256 s2, uint256 f2) = _flush();
        assertEq(s2, 166); // 555*0.3 = 166.5
        assertEq(f2, 389);
        _sendFees(10 * UNIT);
        _flush();

        assertEq(router.totalRoutedToStock(), 300 * UNIT + 166 + 3 * UNIT);
        assertEq(router.totalRoutedToFeeRecipient(), 700 * UNIT + 389 + 7 * UNIT);
        assertEq(usdc.balanceOf(treasury), router.totalRoutedToStock());
        assertEq(usdc.balanceOf(feeWallet), router.totalRoutedToFeeRecipient());
        assertEq(usdc.balanceOf(address(router)), 0);
    }

    function test_Flush_SecondFlushWithoutFundsReverts() public {
        _sendFees(100);
        _flush();
        vm.expectRevert(FeeRouter.NothingToRoute.selector);
        router.flush();
    }

    // ───────────────────────── pending ─────────────────────────

    function test_Pending_EmptyIsZero() public view {
        (uint256 b, uint256 s, uint256 f) = router.pending();
        assertEq(b, 0);
        assertEq(s, 0);
        assertEq(f, 0);
    }

    function test_Pending_MatchesFlush() public {
        _sendFees(12_345);
        (uint256 b, uint256 s, uint256 f) = router.pending();
        assertEq(b, 12_345);
        assertEq(s + f, b);
        (uint256 rs, uint256 rf) = _flush();
        assertEq(rs, s);
        assertEq(rf, f);
    }

    function test_Pending_ReflectsConfigWhenTreasuryZero() public {
        _sendFees(1000);
        vm.prank(owner);
        router.setStockTreasury(address(0));
        (uint256 b, uint256 s, uint256 f) = router.pending();
        assertEq(b, 1000);
        assertEq(s, 0);
        assertEq(f, 1000);
    }

    // ───────────────────────── donations / callers ─────────────────────────

    function test_DirectDonationTreatedAsFee() public {
        usdc.mint(stranger, 1000);
        vm.prank(stranger);
        usdc.transfer(address(router), 1000);
        (uint256 s, uint256 f) = _flush();
        assertEq(s, 300);
        assertEq(f, 700);
        assertEq(usdc.balanceOf(stranger), 0);
        assertEq(usdc.balanceOf(treasury), 300);
        assertEq(usdc.balanceOf(feeWallet), 700);
    }

    function test_AnyoneCanFlush_FundsOnlyGoToConfiguredDestinations() public {
        _sendFees(1000 * UNIT);
        address[3] memory callers = [stranger, dave, address(this)];
        vm.prank(callers[0]);
        router.flush();
        assertEq(usdc.balanceOf(callers[0]), 0);
        assertEq(usdc.balanceOf(treasury), 300 * UNIT);
        assertEq(usdc.balanceOf(feeWallet), 700 * UNIT);

        _sendFees(1000 * UNIT);
        vm.prank(callers[1]);
        router.flush();
        _sendFees(1000 * UNIT);
        router.flush(); // this test contract
        assertEq(usdc.balanceOf(dave), 0);
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(owner), 0);
        assertEq(usdc.balanceOf(treasury), 900 * UNIT);
        assertEq(usdc.balanceOf(feeWallet), 2100 * UNIT);
    }

    // ───────────────────────── reconfiguration before flush ─────────────────────────

    function test_Reconfigure_NewBpsAppliesToExistingBalance() public {
        _sendFees(1000 * UNIT);
        vm.prank(owner);
        router.setStockFeeBps(5000);
        (uint256 s, uint256 f) = _flush();
        assertEq(s, 500 * UNIT);
        assertEq(f, 500 * UNIT);
    }

    function test_Reconfigure_NewTreasuryReceivesStockShare() public {
        address t2 = makeAddr("t2");
        _sendFees(1000 * UNIT);
        vm.prank(owner);
        router.setStockTreasury(t2);
        _flush();
        assertEq(usdc.balanceOf(t2), 300 * UNIT);
        assertEq(usdc.balanceOf(treasury), 0);
    }

    function test_Reconfigure_NewFeeRecipientReceivesRest() public {
        address r2 = makeAddr("r2");
        _sendFees(1000 * UNIT);
        vm.prank(owner);
        router.setFeeRecipient(r2);
        _flush();
        assertEq(usdc.balanceOf(r2), 700 * UNIT);
        assertEq(usdc.balanceOf(feeWallet), 0);
    }

    function test_Reconfigure_TreasuryDisabledSendsAllToFeeRecipient() public {
        _sendFees(1000 * UNIT);
        vm.prank(owner);
        router.setStockTreasury(address(0));
        _flush();
        assertEq(usdc.balanceOf(feeWallet), 1000 * UNIT);
        assertEq(usdc.balanceOf(treasury), 0);
    }

    // ───────────────────────── blocklisted destinations ─────────────────────────

    function _blocklistRouter() internal returns (MockBlocklistERC20 bl, FeeRouter r) {
        bl = new MockBlocklistERC20();
        r = new FeeRouter(address(bl), owner, feeWallet, treasury, STOCK_BPS);
        bl.mint(address(r), 1000 * UNIT);
    }

    function test_Flush_BlockedTreasury_RevertsAtomically_ThenRecovers() public {
        (MockBlocklistERC20 bl, FeeRouter r) = _blocklistRouter();
        bl.setBlocked(treasury, true);

        vm.expectRevert();
        r.flush();
        assertEq(bl.balanceOf(address(r)), 1000 * UNIT, "balance intact");
        assertEq(bl.balanceOf(feeWallet), 0);
        assertEq(r.totalRoutedToStock(), 0);
        assertEq(r.totalRoutedToFeeRecipient(), 0);

        address t2 = makeAddr("t2");
        vm.prank(owner);
        r.setStockTreasury(t2);
        r.flush();
        assertEq(bl.balanceOf(t2), 300 * UNIT);
        assertEq(bl.balanceOf(feeWallet), 700 * UNIT);
        assertEq(bl.balanceOf(address(r)), 0);
        assertEq(r.totalRoutedToStock(), 300 * UNIT);
    }

    function test_Flush_BlockedTreasury_DisablingTreasuryUnblocks() public {
        (MockBlocklistERC20 bl, FeeRouter r) = _blocklistRouter();
        bl.setBlocked(treasury, true);
        vm.prank(owner);
        r.setStockTreasury(address(0));
        r.flush();
        assertEq(bl.balanceOf(feeWallet), 1000 * UNIT);
    }

    function test_Flush_BlockedFeeRecipient_RevertsAtomically_ThenRecovers() public {
        (MockBlocklistERC20 bl, FeeRouter r) = _blocklistRouter();
        bl.setBlocked(feeWallet, true);

        vm.expectRevert();
        r.flush();
        // Treasury transfer happened before the failing one but must be rolled back.
        assertEq(bl.balanceOf(treasury), 0, "treasury rolled back");
        assertEq(bl.balanceOf(address(r)), 1000 * UNIT, "balance intact");
        assertEq(r.totalRoutedToStock(), 0);
        assertEq(r.totalRoutedToFeeRecipient(), 0);

        address r2 = makeAddr("r2");
        vm.prank(owner);
        r.setFeeRecipient(r2);
        r.flush();
        assertEq(bl.balanceOf(r2), 700 * UNIT);
        assertEq(bl.balanceOf(treasury), 300 * UNIT);
        assertEq(bl.balanceOf(address(r)), 0);
    }

    function test_Flush_BlockedThenUnblocked_Succeeds() public {
        (MockBlocklistERC20 bl, FeeRouter r) = _blocklistRouter();
        bl.setBlocked(feeWallet, true);
        vm.expectRevert();
        r.flush();
        bl.setBlocked(feeWallet, false);
        r.flush();
        assertEq(bl.balanceOf(feeWallet), 700 * UNIT);
        assertEq(bl.balanceOf(treasury), 300 * UNIT);
    }

    function test_Flush_FalseReturningTransfer_Reverts() public {
        (MockBlocklistERC20 bl, FeeRouter r) = _blocklistRouter();
        bl.setReturnFalse(treasury, true);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(bl)));
        r.flush();
        assertEq(bl.balanceOf(address(r)), 1000 * UNIT);
        assertEq(r.totalRoutedToStock(), 0);
    }
}
