// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StrPointsTestBase} from "./StrPoints.Base.t.sol";
import {StrPoints} from "../StrPoints.sol";
import {SplitFactory} from "../SplitFactory.sol";

contract StrPointsTest is StrPointsTestBase {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _createDefault();
        _fund(dave, 1_000_000 * UNIT, address(sp));
    }

    // ───────────── constructor ─────────────

    function test_Constructor_StoresConfig() public view {
        assertEq(sp.factory(), address(factory));
        assertEq(address(sp.usdc()), address(usdc));
        assertEq(sp.dayLength(), DAY);
        assertEq(sp.userCount(), 0);
        assertEq(sp.tokenMessenger(), address(messenger));
        assertEq(sp.destinationDomain(), DOMAIN);
    }

    function test_Constructor_RevertsZeroTokenMessenger() public {
        vm.expectRevert(StrPoints.ZeroAddress.selector);
        new StrPoints(address(factory), address(usdc), DAY, address(0), DOMAIN);
    }

    function test_Constructor_ZeroDayLengthBeforeMessengerCheck() public {
        vm.expectRevert(StrPoints.InvalidDayLength.selector);
        new StrPoints(address(factory), address(usdc), 0, address(0), DOMAIN);
    }

    function test_Constructor_AllowsAnyDomain() public {
        StrPoints p = new StrPoints(address(factory), address(usdc), DAY, address(messenger), 26);
        assertEq(p.destinationDomain(), 26);
    }

    function test_Constructor_RevertsZeroFactory() public {
        vm.expectRevert(StrPoints.ZeroAddress.selector);
        new StrPoints(address(0), address(usdc), DAY, address(messenger), DOMAIN);
    }

    function test_Constructor_RevertsZeroUsdc() public {
        vm.expectRevert(StrPoints.ZeroAddress.selector);
        new StrPoints(address(factory), address(0), DAY, address(messenger), DOMAIN);
    }

    function test_Constructor_RevertsZeroDayLength() public {
        vm.expectRevert(StrPoints.InvalidDayLength.selector);
        new StrPoints(address(factory), address(usdc), 0, address(messenger), DOMAIN);
    }

    function test_Constructor_RevertsZeroAddressBeforeDayLengthCheck() public {
        vm.expectRevert(StrPoints.ZeroAddress.selector);
        new StrPoints(address(0), address(0), 0, address(0), DOMAIN);
    }

    // ───────────── depositToSplit ─────────────

    function test_Deposit_HappyPath() public {
        uint256 amt = 1_000 * UNIT;
        _depViaPoints(sp, dave, id, amt);

        uint256 fee = amt * FEE_BPS / 10_000;
        assertEq(usdc.balanceOf(feeRecipient), fee);
        assertEq(factory.splitBalance(id), amt - fee);
        assertEq(usdc.balanceOf(address(factory)), amt - fee);
        assertEq(usdc.balanceOf(dave), 1_000_000 * UNIT - amt);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(usdc.allowance(address(sp), address(factory)), 0);
        assertEq(sp.pointsOf(dave), 150); // 1000 USDC gross -> tier 5
        assertEq(sp.userCount(), 1);
    }

    function test_Deposit_EmitsEvents() public {
        uint256 amt = 200 * UNIT;
        uint256 fee = amt * FEE_BPS / 10_000;
        uint256 v = factory.splitVersion(id);

        vm.expectEmit(true, true, false, true, address(factory));
        emit SplitFactory.Deposited(id, address(sp), amt - fee, fee);
        vm.expectEmit(true, false, false, true, address(sp));
        emit StrPoints.PointsAwarded(dave, 75, 1); // 200 USDC -> tier 3
        vm.prank(dave);
        sp.depositToSplit(id, amt, v);
    }

    function test_Deposit_SameAsDirectDeposit() public {
        uint256 amt = 777_777;
        // direct deposit by eve
        _fund(eve, amt, address(factory));
        uint256 v = factory.splitVersion(id);
        vm.prank(eve);
        factory.deposit(id, amt, v);
        uint256 directBal = factory.splitBalance(id);
        uint256 directFee = usdc.balanceOf(feeRecipient);

        _depViaPoints(sp, dave, id, amt);
        assertEq(factory.splitBalance(id) - directBal, directBal, "net credit equal");
        assertEq(usdc.balanceOf(feeRecipient) - directFee, directFee, "fee equal");
    }

    function test_Deposit_ZeroFee() public {
        vm.prank(owner);
        factory.setFeeBps(0);
        _depViaPoints(sp, dave, id, 100 * UNIT);
        assertEq(usdc.balanceOf(feeRecipient), 0);
        assertEq(factory.splitBalance(id), 100 * UNIT);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(sp.pointsOf(dave), 75);
    }

    function test_Deposit_MaxFee() public {
        vm.prank(owner);
        factory.setFeeBps(500);
        _depViaPoints(sp, dave, id, 100 * UNIT);
        assertEq(usdc.balanceOf(feeRecipient), 5 * UNIT);
        assertEq(factory.splitBalance(id), 95 * UNIT);
        assertEq(usdc.balanceOf(address(sp)), 0);
    }

    function test_Deposit_TinyAmountFeeRoundsToZero_NoPointsBelowOneUsdc() public {
        _depViaPoints(sp, dave, id, 1);
        assertEq(usdc.balanceOf(feeRecipient), 0);
        assertEq(factory.splitBalance(id), 1);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(sp.pointsOf(dave), 0);
        assertEq(sp.userCount(), 0);
    }

    function test_Deposit_RepeatedAccumulatesPoints() public {
        _depViaPoints(sp, dave, id, 10 * UNIT);
        _depViaPoints(sp, dave, id, 10 * UNIT);
        _depViaPoints(sp, dave, id, 10 * UNIT);
        assertEq(sp.pointsOf(dave), 75); // 3 x 25, exactly the tier-1 cap
        assertEq(sp.userCount(), 1);
    }

    function test_Deposit_RevertsZeroAmount() public {
        vm.expectRevert(StrPoints.ZeroAmount.selector);
        vm.prank(dave);
        sp.depositToSplit(id, 0, 1);
        assertEq(sp.pointsOf(dave), 0);
        assertEq(sp.userCount(), 0);
    }

    function test_Deposit_RevertsSplitNotFound() public {
        uint256 bal = usdc.balanceOf(dave);
        vm.expectRevert(SplitFactory.SplitNotFound.selector);
        vm.prank(dave);
        sp.depositToSplit(99, 10 * UNIT, 1);
        _assertNothingMoved(bal);

        vm.expectRevert(SplitFactory.SplitNotFound.selector);
        vm.prank(dave);
        sp.depositToSplit(0, 10 * UNIT, 1);
        _assertNothingMoved(bal);
    }

    function test_Deposit_RevertsStaleVersion() public {
        uint256 staleV = factory.splitVersion(id);
        vm.prank(alice);
        factory.updateSplit(id, _a2(carol, bob), _b2(5000, 5000));
        uint256 bal = usdc.balanceOf(dave);

        vm.expectRevert(SplitFactory.ConfigChanged.selector);
        vm.prank(dave);
        sp.depositToSplit(id, 10 * UNIT, staleV);
        _assertNothingMoved(bal);

        // fresh version works
        _depViaPoints(sp, dave, id, 10 * UNIT);
        assertEq(sp.pointsOf(dave), 25);
    }

    function test_Deposit_RevertsInsufficientAllowance() public {
        _fund(eve, 100 * UNIT, address(0xdead)); // eve funded but never approved StrPoints
        vm.expectRevert();
        vm.prank(eve);
        sp.depositToSplit(id, 10 * UNIT, 1);
        assertEq(sp.pointsOf(eve), 0);
        assertEq(sp.userCount(), 0);
        assertEq(usdc.balanceOf(eve), 100 * UNIT);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(factory.splitBalance(id), 0);
    }

    function test_Deposit_RevertsInsufficientBalance() public {
        address poor = makeAddr("poor");
        _fund(poor, 5 * UNIT, address(sp));
        vm.expectRevert();
        vm.prank(poor);
        sp.depositToSplit(id, 10 * UNIT, 1);
        assertEq(sp.pointsOf(poor), 0);
        assertEq(usdc.balanceOf(poor), 5 * UNIT);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(factory.splitBalance(id), 0);
        assertEq(sp.userCount(), 0);
    }

    function test_Deposit_RevertsWhenTokenTransferReverts() public {
        usdc.setRevertOnTransfer(true);
        vm.expectRevert();
        vm.prank(dave);
        sp.depositToSplit(id, 10 * UNIT, 1);
        assertEq(sp.pointsOf(dave), 0);
        assertEq(usdc.balanceOf(dave), 1_000_000 * UNIT);
    }

    function _assertNothingMoved(uint256 daveBal) internal view {
        assertEq(sp.pointsOf(dave), 0);
        assertEq(sp.userCount(), 0);
        assertEq(usdc.balanceOf(dave), daveBal);
        assertEq(usdc.balanceOf(address(sp)), 0);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(usdc.balanceOf(feeRecipient), 0);
        assertEq(usdc.allowance(address(sp), address(factory)), 0);
    }

    // ───────────── distribute ─────────────

    function test_Distribute_HappyPath_AnyoneGetsPoints() public {
        _depViaPoints(sp, dave, id, 1_000 * UNIT);
        uint256 net = factory.splitBalance(id);

        // eve is neither creator nor depositor
        vm.prank(eve);
        sp.distribute(id);

        assertEq(factory.splitBalance(id), 0);
        assertEq(usdc.balanceOf(bob), net * 6000 / 10_000);
        assertEq(usdc.balanceOf(carol), net * 4000 / 10_000);
        assertEq(sp.pointsOf(eve), 100); // net 995 USDC -> tier 4
        assertEq(sp.pointsOf(alice), 0);
        assertEq(usdc.balanceOf(address(sp)), 0);
    }

    function test_Distribute_EmitsPointsAwarded() public {
        _depViaPoints(sp, dave, id, 100 * UNIT);
        vm.expectEmit(true, false, false, true, address(sp));
        emit StrPoints.PointsAwarded(eve, 50, 2); // net 99.5 USDC -> tier 2
        vm.prank(eve);
        sp.distribute(id);
    }

    function test_Distribute_CreatorGetsPoints() public {
        _depViaPoints(sp, dave, id, 100 * UNIT);
        vm.prank(alice);
        sp.distribute(id);
        assertEq(sp.pointsOf(alice), 50);
    }

    function test_Distribute_RevertsNoBalance() public {
        vm.expectRevert(SplitFactory.NoBalance.selector);
        vm.prank(eve);
        sp.distribute(id);
        assertEq(sp.pointsOf(eve), 0);
        assertEq(sp.userCount(), 0);
    }

    function test_Distribute_RevertsSplitNotFound() public {
        vm.expectRevert(SplitFactory.SplitNotFound.selector);
        vm.prank(eve);
        sp.distribute(42);
        assertEq(sp.pointsOf(eve), 0);
        assertEq(sp.userCount(), 0);
    }

    function test_Distribute_SecondCallRevertsAfterDrain() public {
        _depViaPoints(sp, dave, id, 100 * UNIT);
        vm.prank(eve);
        sp.distribute(id);
        vm.expectRevert(SplitFactory.NoBalance.selector);
        vm.prank(eve);
        sp.distribute(id);
        assertEq(sp.pointsOf(eve), 50);
    }

    // ───────────── accumulation & user registry ─────────────

    function test_Points_AccumulateAcrossActions() public {
        _depViaPoints(sp, dave, id, 100 * UNIT); // +75 (tier 3)
        vm.prank(dave);
        sp.distribute(id); // net 99.5 USDC -> +50 (tier 2)
        _checkIn(sp, dave); // +5
        assertEq(sp.pointsOf(dave), 130);
        assertEq(sp.userCount(), 1);
    }

    function test_Users_OrderAndNoDuplicates() public {
        _checkIn(sp, eve);
        _depViaPoints(sp, dave, id, 10 * UNIT);
        _checkIn(sp, alice);
        _depViaPoints(sp, dave, id, 10 * UNIT); // dave again, no dup
        vm.prank(eve);
        sp.distribute(id); // eve again, no dup

        assertEq(sp.userCount(), 3);
        (address[] memory us, uint256[] memory pts) = sp.getUsers(0, 10);
        assertEq(us.length, 3);
        assertEq(us[0], eve);
        assertEq(us[1], dave);
        assertEq(us[2], alice);
        assertEq(pts[0], 30); // eve: checkin 5 + distribute (net 19.9 USDC -> 25)
        assertEq(pts[1], 50); // dave: 2 deposits x 25
        assertEq(pts[2], 5);
    }

    function test_Users_NotRegisteredOnRevert() public {
        vm.prank(eve);
        vm.expectRevert(SplitFactory.NoBalance.selector);
        sp.distribute(id);
        assertEq(sp.userCount(), 0);
        (address[] memory us, uint256[] memory pts) = sp.getUsers(0, 10);
        assertEq(us.length, 0);
        assertEq(pts.length, 0);
    }

    function test_GetUsers_Pagination() public {
        for (uint256 i = 0; i < 25; ++i) {
            _checkIn(sp, address(uint160(0x1000 + i)));
        }
        assertEq(sp.userCount(), 25);

        (address[] memory a, uint256[] memory p) = sp.getUsers(0, 10);
        assertEq(a.length, 10);
        assertEq(p.length, 10);
        assertEq(a[0], address(uint160(0x1000)));
        assertEq(a[9], address(uint160(0x1009)));
        assertEq(p[3], 5);

        (a, p) = sp.getUsers(10, 10);
        assertEq(a.length, 10);
        assertEq(a[0], address(uint160(0x100A)));

        // clamped tail
        (a, p) = sp.getUsers(20, 100);
        assertEq(a.length, 5);
        assertEq(p.length, 5);
        assertEq(a[4], address(uint160(0x1000 + 24)));

        // exactly at end and beyond: empty
        (a, p) = sp.getUsers(25, 5);
        assertEq(a.length, 0);
        assertEq(p.length, 0);
        (a, p) = sp.getUsers(1000, 5);
        assertEq(a.length, 0);

        // limit 0
        (a, p) = sp.getUsers(3, 0);
        assertEq(a.length, 0);
        assertEq(p.length, 0);

        // huge limit doesn't overflow
        (a, p) = sp.getUsers(0, type(uint256).max);
        assertEq(a.length, 25);
    }

    function test_ManyUsers_MixedActions() public {
        for (uint256 i = 0; i < 60; ++i) {
            address u = address(uint160(0x2000 + i));
            _checkIn(sp, u);
            if (i % 3 == 0) {
                _fund(u, 10 * UNIT, address(sp));
                _depViaPoints(sp, u, id, 10 * UNIT);
            }
        }
        assertEq(sp.userCount(), 60);
        (address[] memory us, uint256[] memory pts) = sp.getUsers(0, 100);
        for (uint256 i = 0; i < 60; ++i) {
            assertEq(us[i], address(uint160(0x2000 + i)));
            assertEq(pts[i], i % 3 == 0 ? 30 : 5);
            assertEq(sp.pointsOf(us[i]), pts[i]);
        }
        assertEq(usdc.balanceOf(address(sp)), 0);
    }

    // ───────────── short dayLength sanity (deposits independent of dayLength) ─────────────

    function test_ShortDayLength_DepositAndDistribute() public {
        StrPoints p = _newPoints(300);
        _fund(dave, 100 * UNIT, address(p));
        _depViaPoints(p, dave, id, 50 * UNIT);
        vm.prank(eve);
        p.distribute(id);
        assertEq(p.pointsOf(dave), 50); // gross 50 USDC -> tier 2
        assertEq(p.pointsOf(eve), 25); // net 49.75 USDC -> tier 1
        assertEq(usdc.balanceOf(address(p)), 0);
    }
}
