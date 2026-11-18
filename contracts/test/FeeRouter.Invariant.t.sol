// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FeeRouter} from "../FeeRouter.sol";
import {SplitFactory} from "../SplitFactory.sol";
import {StrPoints} from "../StrPoints.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";
import {FeeRouterStackBase} from "./FeeRouter.Base.t.sol";

/// @dev Drives deposits / bridges / donations / flushes / reconfigurations, tracking ghost totals.
contract FeeRouterHandler is Test {
    MockERC20 public usdc;
    FeeRouter public router;
    SplitFactory public factory;
    StrPoints public sp;
    uint256 public splitId;
    address public routerOwner;
    address public factoryOwner;

    uint256 public ghostReceived; // fees that arrived at the router
    uint256 public ghostRouted; // sum of flush() return values
    uint256 public flushes;

    address[3] public treasuries;
    address[3] public recipients;

    constructor(
        MockERC20 _usdc,
        FeeRouter _router,
        SplitFactory _factory,
        StrPoints _sp,
        uint256 _splitId,
        address _routerOwner,
        address _factoryOwner
    ) {
        usdc = _usdc;
        router = _router;
        factory = _factory;
        sp = _sp;
        splitId = _splitId;
        routerOwner = _routerOwner;
        factoryOwner = _factoryOwner;
        treasuries = [makeAddr("hT1"), makeAddr("hT2"), address(0)];
        recipients = [makeAddr("hR1"), makeAddr("hR2"), makeAddr("hR3")];
        usdc.approve(address(_factory), type(uint256).max);
        usdc.approve(address(_sp), type(uint256).max);
    }

    function _fee(uint256 amt) internal view returns (uint256) {
        return amt * factory.feeBps() / 10_000;
    }

    function deposit(uint256 amt) external {
        amt = bound(amt, 1, 1e12);
        usdc.mint(address(this), amt);
        ghostReceived += _fee(amt);
        factory.deposit(splitId, amt, factory.splitVersion(splitId));
    }

    function depositViaPoints(uint256 amt) external {
        amt = bound(amt, 1, 1e12);
        usdc.mint(address(this), amt);
        ghostReceived += _fee(amt);
        sp.depositToSplit(splitId, amt, factory.splitVersion(splitId));
    }

    function bridge(uint256 amt) external {
        amt = bound(amt, 1, 1e12);
        usdc.mint(address(this), amt);
        ghostReceived += _fee(amt);
        sp.bridge(amt, 0, 1000, address(this), 500);
    }

    function donate(uint256 amt) external {
        amt = bound(amt, 1, 1e9);
        usdc.mint(address(this), amt);
        usdc.transfer(address(router), amt);
        ghostReceived += amt;
    }

    function flush() external {
        if (usdc.balanceOf(address(router)) == 0) return;
        (uint256 s, uint256 f) = router.flush();
        ghostRouted += s + f;
        flushes++;
    }

    function setBps(uint256 bps) external {
        vm.prank(routerOwner);
        router.setStockFeeBps(uint16(bound(bps, 0, 10_000)));
    }

    function setTreasury(uint256 pick) external {
        vm.prank(routerOwner);
        router.setStockTreasury(treasuries[pick % 3]);
    }

    function setRecipient(uint256 pick) external {
        vm.prank(routerOwner);
        router.setFeeRecipient(recipients[pick % 3]);
    }

    function setFactoryFee(uint256 bps) external {
        vm.prank(factoryOwner);
        factory.setFeeBps(uint16(bound(bps, 0, 500)));
    }

    function delivered() external view returns (uint256 sum) {
        for (uint256 i = 0; i < 3; ++i) {
            if (treasuries[i] != address(0)) sum += usdc.balanceOf(treasuries[i]);
            sum += usdc.balanceOf(recipients[i]);
        }
        // Initial destinations from the base fixture are accounted for by the test contract.
    }
}

contract FeeRouterInvariantTest is FeeRouterStackBase {
    FeeRouterHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new FeeRouterHandler(usdc, router, factory, sp, splitId, owner, factoryOwner);
        targetContract(address(handler));
    }

    /// @dev Router balance == fees received - fees routed.
    function invariant_RouterBalanceIsReceivedMinusRouted() public view {
        assertEq(usdc.balanceOf(address(router)), handler.ghostReceived() - handler.ghostRouted());
    }

    /// @dev Lifetime totals equal exactly what flush() reported paying out.
    function invariant_TotalsMatchRouted() public view {
        assertEq(router.totalRoutedToStock() + router.totalRoutedToFeeRecipient(), handler.ghostRouted());
    }

    /// @dev Everything routed is sitting with some configured destination.
    function invariant_RoutedFundsAreDelivered() public view {
        uint256 initial = usdc.balanceOf(treasury) + usdc.balanceOf(feeWallet);
        assertEq(handler.delivered() + initial, handler.ghostRouted());
    }

    function invariant_RouterNeverHoldsMoreThanReceived() public view {
        assertLe(usdc.balanceOf(address(router)), handler.ghostReceived());
    }
}
