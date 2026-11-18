// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FeeRouter} from "../FeeRouter.sol";
import {FeeRouterStackBase} from "./FeeRouter.Base.t.sol";

contract FeeRouterFuzzTest is FeeRouterStackBase {
    address internal t2 = makeAddr("t2");
    address internal r2 = makeAddr("r2");
    address internal r3 = makeAddr("r3");

    function setUp() public override {
        super.setUp();
        _fundUser(dave, 1e24);
    }

    // ─────────────── single flush ───────────────

    function testFuzz_Flush_SplitsAndConserves(uint256 bal, uint16 bps, bool useTreasury) public {
        bal = bound(bal, 1, 2 ** 96);
        bps = uint16(bound(bps, 0, 10_000));
        vm.startPrank(owner);
        router.setStockFeeBps(bps);
        router.setStockTreasury(useTreasury ? treasury : address(0));
        vm.stopPrank();
        _sendFees(bal);

        (uint256 pb, uint256 ps, uint256 pf) = router.pending();
        (uint256 s, uint256 f) = _flush();

        assertEq(pb, bal);
        assertEq(s, ps, "pending stock");
        assertEq(f, pf, "pending fee");
        assertEq(s + f, bal, "conservation");
        assertLe(s, bal * bps / 10_000, "stock bounded by bps share");
        assertEq(s, useTreasury ? bal * bps / 10_000 : 0, "exact floor share");
        assertEq(usdc.balanceOf(address(router)), 0, "router empty");
        assertEq(usdc.balanceOf(treasury), s);
        assertEq(usdc.balanceOf(feeWallet), f);
        assertEq(router.totalRoutedToStock(), s);
        assertEq(router.totalRoutedToFeeRecipient(), f);
    }

    function testFuzz_Flush_RepeatedTotalsMatch(uint256 a, uint256 b, uint16 bps) public {
        a = bound(a, 1, 2 ** 96);
        b = bound(b, 1, 2 ** 96);
        bps = uint16(bound(bps, 0, 10_000));
        vm.prank(owner);
        router.setStockFeeBps(bps);
        _sendFees(a);
        _flush();
        _sendFees(b);
        _flush();
        assertEq(router.totalRoutedToStock() + router.totalRoutedToFeeRecipient(), a + b);
        assertEq(usdc.balanceOf(treasury), router.totalRoutedToStock());
        assertEq(usdc.balanceOf(feeWallet), router.totalRoutedToFeeRecipient());
        assertEq(usdc.balanceOf(address(router)), 0);
    }

    function testFuzz_SetStockFeeBps_AboveMaxReverts(uint16 bps) public {
        bps = uint16(bound(bps, 10_001, type(uint16).max));
        vm.prank(owner);
        vm.expectRevert(FeeRouter.StockFeeTooHigh.selector);
        router.setStockFeeBps(bps);
    }

    function testFuzz_Pending_NeverExceedsBalance(uint256 bal, uint16 bps, bool useTreasury) public {
        bal = bound(bal, 0, 2 ** 96);
        bps = uint16(bound(bps, 0, 10_000));
        vm.startPrank(owner);
        router.setStockFeeBps(bps);
        router.setStockTreasury(useTreasury ? treasury : address(0));
        vm.stopPrank();
        _sendFees(bal);
        (uint256 b, uint256 s, uint256 f) = router.pending();
        assertEq(b, bal);
        assertEq(s + f, bal);
    }

    // ─────────────── random sequences over the real stack ───────────────

    function _sumRecipients() internal view returns (uint256) {
        return usdc.balanceOf(treasury) + usdc.balanceOf(t2) + usdc.balanceOf(feeWallet) + usdc.balanceOf(r2)
            + usdc.balanceOf(r3);
    }

    function testFuzz_Sequence_ConservesFunds(uint256 seed) public {
        uint256 fees;
        uint256 netCredited;
        uint256 burned;
        address[3] memory feeTargets = [feeWallet, r2, r3];

        for (uint256 i = 0; i < 24; ++i) {
            uint256 r = uint256(keccak256(abi.encode(seed, i)));
            uint256 op = r % 9;
            uint256 arg = r >> 8;
            uint256 bps = factory.feeBps();

            if (op == 0) {
                uint256 amt = bound(arg, 1, 1e12);
                fees += amt * bps / 10_000;
                netCredited += amt - amt * bps / 10_000;
                _depFactory(factory, splitId, dave, amt);
            } else if (op == 1) {
                uint256 amt = bound(arg, 1, 1e12);
                fees += amt * bps / 10_000;
                netCredited += amt - amt * bps / 10_000;
                _depSp(sp, factory, splitId, dave, amt);
            } else if (op == 2) {
                uint256 amt = bound(arg, 1, 1e12);
                fees += amt * bps / 10_000;
                burned += amt - amt * bps / 10_000;
                _bridge(sp, dave, amt);
            } else if (op == 3) {
                if (usdc.balanceOf(address(router)) > 0) router.flush();
            } else if (op == 4) {
                vm.prank(owner);
                router.setStockFeeBps(uint16(bound(arg, 0, 10_000)));
            } else if (op == 5) {
                address[3] memory ts = [treasury, t2, address(0)];
                vm.prank(owner);
                router.setStockTreasury(ts[arg % 3]);
            } else if (op == 6) {
                vm.prank(owner);
                router.setFeeRecipient(feeTargets[arg % 3]);
            } else if (op == 7) {
                vm.prank(factoryOwner);
                factory.setFeeBps(uint16(bound(arg, 0, 500)));
            } else {
                uint256 amt = bound(arg, 1, 1e9);
                fees += amt; // direct donation counts as a fee
                usdc.mint(stranger, amt);
                vm.prank(stranger);
                usdc.transfer(address(router), amt);
            }

            // Invariant after every step: nothing created or lost.
            assertEq(_sumRecipients() + usdc.balanceOf(address(router)), fees, "fees conserved");
            assertEq(
                router.totalRoutedToStock() + router.totalRoutedToFeeRecipient() + usdc.balanceOf(address(router)),
                fees,
                "totals + pending"
            );
        }

        // Router never touches split funds or burn funds.
        assertEq(factory.splitBalance(splitId), netCredited);
        assertEq(messenger.totalBurned(), burned);

        if (usdc.balanceOf(address(router)) > 0) router.flush();
        assertEq(usdc.balanceOf(address(router)), 0);
        assertEq(_sumRecipients(), fees, "all fees delivered");
    }
}
