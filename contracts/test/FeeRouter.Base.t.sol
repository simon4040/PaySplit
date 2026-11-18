// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {FeeRouter} from "../FeeRouter.sol";
import {SplitFactory} from "../SplitFactory.sol";
import {StrPoints} from "../StrPoints.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";
import {MockTokenMessengerV2} from "../test-helpers/MockTokenMessengerV2.sol";

/// @dev Shared fixtures for FeeRouter unit tests. No test functions here.
abstract contract FeeRouterTestBase is Test {
    uint16 internal constant STOCK_BPS = 3000; // 30%
    uint256 internal constant UNIT = 1e6;

    address internal owner = makeAddr("owner");
    address internal feeWallet = makeAddr("feeWallet");
    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal stranger = makeAddr("stranger");

    MockERC20 internal usdc;
    FeeRouter internal router;

    function setUp() public virtual {
        usdc = new MockERC20("Mock USDC", "mUSDC", 6);
        router = new FeeRouter(address(usdc), owner, feeWallet, treasury, STOCK_BPS);
    }

    /// @dev Simulates fee arrival as a plain USDC transfer to the router.
    function _sendFees(uint256 amt) internal {
        usdc.mint(address(router), amt);
    }

    function _flush() internal returns (uint256 toStock, uint256 toFee) {
        vm.prank(stranger);
        (toStock, toFee) = router.flush();
    }

    /// @dev Counts logs whose topic0 equals `sig`.
    function _count(Vm.Log[] memory logs, bytes32 sig) internal pure returns (uint256 n) {
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == sig) ++n;
        }
    }

    bytes32 internal constant SIG_STOCK = keccak256("FeeRoutedToStockTreasury(address,uint256)");
    bytes32 internal constant SIG_FEE = keccak256("FeeRoutedToFeeRecipient(address,uint256)");
}

/// @dev Adds a real SplitFactory + StrPoints stack whose feeRecipient is the router,
///      plus a reference stack with a plain-wallet feeRecipient. No test functions here.
abstract contract FeeRouterStackBase is FeeRouterTestBase {
    uint16 internal constant FACTORY_FEE_BPS = 50; // 0.5%
    uint256 internal constant DAY = 86400;
    uint32 internal constant DOMAIN = 6;

    address internal factoryOwner = makeAddr("factoryOwner");
    address internal plainWallet = makeAddr("plainWallet"); // factory's original feeRecipient
    address internal refWallet = makeAddr("refWallet"); // reference stack feeRecipient

    SplitFactory internal factory;
    StrPoints internal sp;
    MockTokenMessengerV2 internal messenger;
    uint256 internal splitId;

    SplitFactory internal refFactory;
    StrPoints internal refSp;
    MockTokenMessengerV2 internal refMessenger;
    uint256 internal refSplitId;

    function setUp() public virtual override {
        super.setUp();
        vm.warp(1000 * DAY);

        factory = new SplitFactory(address(usdc), factoryOwner, plainWallet, FACTORY_FEE_BPS);
        messenger = new MockTokenMessengerV2();
        sp = new StrPoints(address(factory), address(usdc), DAY, address(messenger), DOMAIN);
        vm.prank(factoryOwner);
        factory.setFeeRecipient(address(router));

        refFactory = new SplitFactory(address(usdc), factoryOwner, refWallet, FACTORY_FEE_BPS);
        refMessenger = new MockTokenMessengerV2();
        refSp = new StrPoints(address(refFactory), address(usdc), DAY, address(refMessenger), DOMAIN);

        splitId = _createSplit(factory);
        refSplitId = _createSplit(refFactory);
    }

    function _createSplit(SplitFactory f) internal returns (uint256 id) {
        address[] memory a = new address[](2);
        a[0] = bob;
        a[1] = carol;
        uint96[] memory b = new uint96[](2);
        b[0] = 6000;
        b[1] = 4000;
        vm.prank(alice);
        id = f.createSplit(a, b);
    }

    /// @dev Mint `amt` to `who` and approve both stacks' factories and StrPoints.
    function _fundUser(address who, uint256 amt) internal {
        usdc.mint(who, amt);
        vm.startPrank(who);
        usdc.approve(address(factory), type(uint256).max);
        usdc.approve(address(sp), type(uint256).max);
        usdc.approve(address(refFactory), type(uint256).max);
        usdc.approve(address(refSp), type(uint256).max);
        vm.stopPrank();
    }

    function _depFactory(SplitFactory f, uint256 id, address who, uint256 amt) internal {
        uint256 v = f.splitVersion(id);
        vm.prank(who);
        f.deposit(id, amt, v);
    }

    function _depSp(StrPoints p, SplitFactory f, uint256 id, address who, uint256 amt) internal {
        uint256 v = f.splitVersion(id);
        vm.prank(who);
        p.depositToSplit(id, amt, v);
    }

    function _bridge(StrPoints p, address who, uint256 amt) internal {
        vm.prank(who);
        p.bridge(amt, 0, 1000, who, 500);
    }

    function _feeOf(uint256 amt) internal view returns (uint256) {
        return amt * factory.feeBps() / 10_000;
    }
}
