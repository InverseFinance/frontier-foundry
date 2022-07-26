// SPDX-License-Identifier: Unlicense
pragma solidity ^0.5.16;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Comptroller} from "../contracts/Comptroller.sol";
import {CErc20Immutable} from "../contracts/CErc20Immutable.sol";
import {ERC20} from "../contracts/ERC20.sol";
import {IUSDT} from "../contracts/IUSDT.sol";
import {CToken} from "../contracts/CToken.sol";
import {Unitroller} from "../contracts/Unitroller.sol";
import {CEther} from "../contracts/CEther.sol";
import {IOracle} from "../contracts/IOracle.sol";
import {TestingEthOracle} from "../contracts/TestingEthOracle.sol";

contract ComptrollerUpgrade is DSTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    //Anchor
    Comptroller public comptroller;
    Comptroller public unitroller =
        Comptroller(0x4dCf7407AE5C07f8681e1659f626E114A7667339);
    address payable public unitrollerAddress =
        0x4dCf7407AE5C07f8681e1659f626E114A7667339;

    address anchorOracle = 0xE8929AFd47064EfD36A7fB51dA3F8C5eb40c4cb4;
    address governance = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B;

    //EOAs
    address anEtherHolder = 0x6fC34A8B9B4973b5E6b0B6a984Bb0bEcC9Ca2b29;
    address freshEOA = 0x420b5055fC1Daa677aE5c9428a8d803512E66120;
    address user = address(0x69);

    //Tokens
    address payable anDolaAddress = 0x7Fcb7DAC61eE35b3D4a51117A7c58D53f0a8a670;
    address payable anEtherAddress = 0x697b4acAa24430F254224eB794d2a85ba1Fa1FB8;
    address dolaAddress = 0x865377367054516e17014CcdED1e7d814EDC9ce4;
    address payable anYfiAddress = 0xde2af899040536884e062D3a334F2dD36F34b4a4;
    address yfiAddress = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
    address daiAddr = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address usdcAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IUSDT USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    uint256 usdtAmount = 1_000_000 * 10**6;
    uint256 usdcAmount = 1_000_000 * 10**6;
    uint256 daiAmount = 1_000_000 * 10**18;
    uint256 crvDolaAmount = 1_000_000 * 10**18;
    uint256 amount18Decimals = 1_000_000 * 10**18;

    TestingEthOracle testingEthOracle;

    function setUp() public {
        vm.startPrank(governance);
        unitroller._setBorrowPaused(CToken(anDolaAddress), false);
        unitroller._setCollateralPaused(CToken(anYfiAddress), false);
        vm.stopPrank();
    }

    function upgradeComptroller() public {
        vm.startPrank(governance);

        //Deploy new Comptroller implementation
        comptroller = new Comptroller();

        //Upgrade Unitroller to new Comptroller implementation
        Unitroller(unitrollerAddress)._setPendingImplementation(
            address(comptroller)
        );
        comptroller._become(Unitroller(unitrollerAddress));

        unitroller._setBorrowPaused(CToken(anDolaAddress), false);
        unitroller._setCollateralPaused(CToken(anYfiAddress), false);
        vm.stopPrank();
    }

    function testTransferCTokensSuccessToTransferWhitelistedRecipientWhileTransferPaused()
        public
    {
        upgradeComptroller();
        vm.startPrank(governance);
        unitroller._setTransferAllowedWhitelist(governance, true);

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();

        CToken(anYfiAddress).transfer(governance, 1e8);
    }

    function testTransferCTokensToDifferentAddyAfterWhitelistingOne() public {
        upgradeComptroller();
        vm.startPrank(governance);
        unitroller._setTransferAllowedWhitelist(governance, true);

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();

        vm.expectRevert(bytes("transfer is paused"));
        CToken(anYfiAddress).transfer(address(69), 1e8);
    }

    function testTransferCTokensFailsWhileTransferPausedAndRecipientNotWhitelisted()
        public
    {
        upgradeComptroller();
        vm.startPrank(governance);

        //Just wanna make sure it works :P
        unitroller._setTransferAllowedWhitelist(governance, true);
        unitroller._setTransferAllowedWhitelist(governance, false);

        unitroller._setTransferPaused(true);

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();

        vm.expectRevert(bytes("transfer is paused"));
        CToken(anYfiAddress).transfer(governance, 1e8);
    }

    function testSuccessfulRedeemWhileEnteredInCollateralPausedMarkets()
        public
    {
        upgradeComptroller();
        vm.startPrank(anEtherHolder);

        //Give anEtherAddress some ETH so anTokens can actually be redeemed
        vm.deal(anEtherAddress, 5 ether);

        //Attempt to redeem collateral paused tokens, should succeed since the call to
        //`getHypotheticalAccountLiquidityInternal()` has 0 borrowAmount
        uint256 prevBal = anEtherHolder.balance;
        CErc20Immutable(anEtherAddress).redeem(1 * 10**8);

        //Ensure redeem was successful by comparing prev ETH balance to current ETH balance
        assertLt(prevBal, anEtherHolder.balance, "Redeem failed");
    }

    function testSuccessfulRedeemWhileEnteredInCollateralPausedMarketsOld()
        public
    {
        vm.startPrank(anEtherHolder);

        //Give anEtherAddress some ETH so anTokens can actually be redeemed
        vm.deal(anEtherAddress, 5 ether);

        //Attempt to redeem collateral paused tokens, should succeed since the call to
        //`getHypotheticalAccountLiquidityInternal()` has 0 borrowAmount
        uint256 prevBal = anEtherHolder.balance;
        CErc20Immutable(anEtherAddress).redeem(1 * 10**8);

        //Ensure redeem was successful by comparing prev ETH balance to current ETH balance
        assertLt(prevBal, anEtherHolder.balance, "Redeem failed");
    }

    function testLiquidateWhileTransferPaused() public {
        upgradeComptroller();
        vm.startPrank(governance);

        //Switch ETH oracle so price is v low ($1k) and anEtherHolder is liquidatable
        testingEthOracle = new TestingEthOracle();
        IOracle(anchorOracle).setFeed(
            anEtherAddress,
            address(testingEthOracle),
            18
        );

        unitroller._setTransferPaused(true);

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();
        gibYFI();

        uint256 prevFreshEOABal = ERC20(anEtherAddress).balanceOf(freshEOA);
        uint256 prevAnEtherHolderBal = ERC20(anEtherAddress).balanceOf(
            anEtherHolder
        );

        //Liquidate anEtherHolder, should succeed since the call to `getHypotheticalAccountLiquidityInternal()'
        //has 0 borrowAmount
        ERC20(yfiAddress).approve(anYfiAddress, 60 * 10**18);
        CErc20Immutable(anYfiAddress).liquidateBorrow(
            anEtherHolder,
            1 * 10**18,
            CToken(anEtherAddress)
        );

        //Assert that liquidation was successful by comparing prev anETH bals to post-liquidation bals
        assertLt(
            prevFreshEOABal,
            ERC20(anEtherAddress).balanceOf(freshEOA),
            "Liquidation failed"
        );
        assertGt(
            prevAnEtherHolderBal,
            ERC20(anEtherAddress).balanceOf(anEtherHolder),
            "Liquidation failed"
        );
    }

    function testLiquidateWhileTransferPausedOld() public {
        vm.startPrank(governance);

        //Switch ETH oracle so price is v low ($1k) and anEtherHolder is liquidatable
        testingEthOracle = new TestingEthOracle();
        IOracle(anchorOracle).setFeed(
            anEtherAddress,
            address(testingEthOracle),
            18
        );

        unitroller._setTransferPaused(true);

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();
        gibYFI();

        uint256 prevFreshEOABal = ERC20(anEtherAddress).balanceOf(freshEOA);
        uint256 prevAnEtherHolderBal = ERC20(anEtherAddress).balanceOf(
            anEtherHolder
        );

        //Liquidate anEtherHolder, should succeed since the call to `getHypotheticalAccountLiquidityInternal()'
        //has 0 borrowAmount
        ERC20(yfiAddress).approve(anYfiAddress, 60 * 10**18);
        CErc20Immutable(anYfiAddress).liquidateBorrow(
            anEtherHolder,
            1 * 10**18,
            CToken(anEtherAddress)
        );

        //Assert that liquidation was successful by comparing prev anETH bals to post-liquidation bals
        assertLt(
            prevFreshEOABal,
            ERC20(anEtherAddress).balanceOf(freshEOA),
            "Liquidation failed"
        );
        assertGt(
            prevAnEtherHolderBal,
            ERC20(anEtherAddress).balanceOf(anEtherHolder),
            "Liquidation failed"
        );
    }

    function testLiquidate() public {
        upgradeComptroller();
        vm.startPrank(governance);

        //Switch ETH oracle so price is v low ($1k) and anEtherHolder is liquidatable
        testingEthOracle = new TestingEthOracle();
        IOracle(anchorOracle).setFeed(
            anEtherAddress,
            address(testingEthOracle),
            18
        );

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();
        gibYFI();

        uint256 prevFreshEOABal = ERC20(anEtherAddress).balanceOf(freshEOA);
        uint256 prevAnEtherHolderBal = ERC20(anEtherAddress).balanceOf(
            anEtherHolder
        );

        //Liquidate anEtherHolder, should succeed since the call to `getHypotheticalAccountLiquidityInternal()'
        //has 0 borrowAmount
        ERC20(yfiAddress).approve(anYfiAddress, 60 * 10**18);
        CErc20Immutable(anYfiAddress).liquidateBorrow(
            anEtherHolder,
            1 * 10**18,
            CToken(anEtherAddress)
        );

        //Assert that liquidation was successful by comparing prev anETH bals to post-liquidation bals
        assertLt(
            prevFreshEOABal,
            ERC20(anEtherAddress).balanceOf(freshEOA),
            "Liquidation unsuccessful"
        );
        assertGt(
            prevAnEtherHolderBal,
            ERC20(anEtherAddress).balanceOf(anEtherHolder),
            "Liquidation Unsuccessful"
        );
    }

    function testLiquidateOld() public {
        vm.startPrank(governance);

        //Switch ETH oracle so price is v low ($1k) and anEtherHolder is liquidatable
        testingEthOracle = new TestingEthOracle();
        IOracle(anchorOracle).setFeed(
            anEtherAddress,
            address(testingEthOracle),
            18
        );

        vm.stopPrank();
        vm.startPrank(freshEOA);
        gibAnTokens();
        gibYFI();

        uint256 prevFreshEOABal = ERC20(anEtherAddress).balanceOf(freshEOA);
        uint256 prevAnEtherHolderBal = ERC20(anEtherAddress).balanceOf(
            anEtherHolder
        );

        //Liquidate anEtherHolder, should succeed since the call to `getHypotheticalAccountLiquidityInternal()'
        //has 0 borrowAmount
        ERC20(yfiAddress).approve(anYfiAddress, 60 * 10**18);
        CErc20Immutable(anYfiAddress).liquidateBorrow(
            anEtherHolder,
            1 * 10**18,
            CToken(anEtherAddress)
        );

        //Assert that liquidation was successful by comparing prev anETH bals to post-liquidation bals
        assertLt(
            prevFreshEOABal,
            ERC20(anEtherAddress).balanceOf(freshEOA),
            "Liquidation unsuccessful"
        );
        assertGt(
            prevAnEtherHolderBal,
            ERC20(anEtherAddress).balanceOf(anEtherHolder),
            "Liquidation Unsuccessful"
        );
    }

    function testSuccessfulBorrowAfterExitingCollateralPausedMarkets() public {
        upgradeComptroller();
        vm.startPrank(anEtherHolder);

        //This account has 36000113451542105469 YFI borrowed

        //Get storage slot for `balances[anEtherHolder]` on YFI contract
        address _anEtherHolder = anEtherHolder;
        bytes32 slot;
        assembly {
            mstore(0, _anEtherHolder)
            mstore(0x20, 0x0)
            slot := keccak256(0, 0x40)
        }

        //Give anEtherHolder enough tokens to cover debt
        vm.store(yfiAddress, slot, bytes32(uint256(36000113451542105469)));

        //Repay debt so it's possible to exit market, will fail otherwise
        CErc20Immutable(anYfiAddress).repayBorrow(36000113451542105469);

        //Exit anEther market
        unitroller.exitMarket(anEtherAddress);

        //Attempt to borrow DOLA
        uint256 prevBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        assertEq(prevBal + 100 * 10**8, postBal, "Borrow failed");
    }

    function testSuccessfulBorrowAfterExitingCollateralPausedMarketsOld()
        public
    {
        vm.startPrank(anEtherHolder);

        //This account has 36000113451542105469 YFI borrowed

        //Get storage slot for `balances[anEtherHolder]` on YFI contract
        address _anEtherHolder = anEtherHolder;
        bytes32 slot;
        assembly {
            mstore(0, _anEtherHolder)
            mstore(0x20, 0x0)
            slot := keccak256(0, 0x40)
        }

        //Give anEtherHolder enough tokens to cover debt
        vm.store(yfiAddress, slot, bytes32(uint256(36000113451542105469)));

        //Repay debt so it's possible to exit market, will fail otherwise
        CErc20Immutable(anYfiAddress).repayBorrow(36000113451542105469);

        //Exit anEther market
        unitroller.exitMarket(anEtherAddress);

        //Attempt to borrow DOLA
        uint256 prevBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        assertEq(prevBal + 100 * 10**8, postBal, "Borrow failed");
    }

    function testBorrowFailsWhileEnteredInCollateralPausedMarkets() public {
        upgradeComptroller();
        vm.startPrank(anEtherHolder);

        //This account has 36000113451542105469 YFI borrowed
        //This account is also entered in the anYFI & anETH markets
        //  anETH is paused in the `setup()` function

        //Get storage slot for `balances[anEtherHolder]` on YFI contract
        address _anEtherHolder = anEtherHolder;
        bytes32 slot;
        assembly {
            mstore(0, _anEtherHolder)
            mstore(0x20, 0x0)
            slot := keccak256(0, 0x40)
        }

        //Give anEtherHolder enough tokens to cover debt
        vm.store(yfiAddress, slot, bytes32(uint256(36000113451542105469)));

        //Repay debt so it's possible to exit market, will fail otherwise
        CErc20Immutable(anYfiAddress).repayBorrow(36000113451542105469);

        //Attempt to borrow DOLA
        uint256 prevBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        assertGt(
            prevBal + 100 * 10**8,
            postBal,
            "Borrow was successful & should have failed"
        );
    }

    function testBorrowFailsWhileEnteredInCollateralPausedMarketsOld() public {
        vm.startPrank(anEtherHolder);

        //This account has 36000113451542105469 YFI borrowed
        //This account is also entered in the anYFI & anETH markets
        //  anETH is paused in the `setup()` function

        //Get storage slot for `balances[anEtherHolder]` on YFI contract
        address _anEtherHolder = anEtherHolder;
        bytes32 slot;
        assembly {
            mstore(0, _anEtherHolder)
            mstore(0x20, 0x0)
            slot := keccak256(0, 0x40)
        }

        //Give anEtherHolder enough tokens to cover debt
        vm.store(yfiAddress, slot, bytes32(uint256(36000113451542105469)));

        //Repay debt so it's possible to exit market, will fail otherwise
        CErc20Immutable(anYfiAddress).repayBorrow(36000113451542105469);

        //Attempt to borrow DOLA
        uint256 prevBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(anEtherHolder);

        assertGt(
            prevBal + 100 * 10**8,
            postBal,
            "Borrow was successful & should have failed"
        );
    }

    function testSuccessfulBorrowAfterExitingCollateralPausedMarketsFreshAddress()
        public
    {
        upgradeComptroller();
        vm.startPrank(freshEOA);

        //Enter anETH & anYFI markets
        address[] memory addrs = new address[](2);
        addrs[0] = anEtherAddress;
        addrs[1] = anYfiAddress;

        unitroller.enterMarkets(addrs);

        //Exit anEther market
        unitroller.exitMarket(anEtherAddress);

        gibAnTokens();

        //Attempt to borrow DOLA
        uint256 prevBal = ERC20(dolaAddress).balanceOf(freshEOA);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(freshEOA);

        assertEq(prevBal + 100 * 10**8, postBal, "Borrow failed");
    }

    function testBorrowFailsWhileEnteredInCollateralPausedMarketsFreshAddress()
        public
    {
        upgradeComptroller();
        vm.startPrank(freshEOA);
        gibAnTokens();

        //Enter anETH & anYFI markets
        address[] memory addrs = new address[](2);
        addrs[0] = anEtherAddress;
        addrs[1] = anYfiAddress;

        unitroller.enterMarkets(addrs);

        //Attempt to borrow DOLA (Should fail since account is entered in anETH, which is paused during setup)
        uint256 prevBal = ERC20(dolaAddress).balanceOf(freshEOA);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(freshEOA);

        assertGt(
            postBal + 100 * 10**8,
            prevBal,
            "Borrow succeeded & should have failed"
        );
    }

    function testSuccessfulBorrowAfterExitingCollateralPausedMarketsFreshAddressOld()
        public
    {
        vm.startPrank(freshEOA);

        //Enter anETH & anYFI markets
        address[] memory addrs = new address[](2);
        addrs[0] = anEtherAddress;
        addrs[1] = anYfiAddress;

        unitroller.enterMarkets(addrs);

        //Exit anEther market
        unitroller.exitMarket(anEtherAddress);

        gibAnTokens();

        //Attempt to borrow DOLA
        uint256 prevBal = ERC20(dolaAddress).balanceOf(freshEOA);

        CErc20Immutable(anDolaAddress).borrow(100 * 10**8);

        uint256 postBal = ERC20(dolaAddress).balanceOf(freshEOA);

        assertEq(prevBal + 100 * 10**8, postBal, "Borrow failed");
    }

    function gibAnTokens() public {
        //Calculate accountTokens[freshEOA] slot hash for CToken contracts
        address _freshEOA = freshEOA;
        bytes32 slot;
        assembly {
            mstore(0, _freshEOA)
            mstore(0x20, 0xE)
            slot := keccak256(0, 0x40)
        }

        //Give freshEOA 100 anYFI
        vm.store(anYfiAddress, slot, bytes32(uint256(100 * 10**8)));
        vm.store(anEtherAddress, slot, bytes32(uint256(100 * 10**8)));
    }

    function gibYFI() public {
        //Give freshEOA 60 YFI to liquidate anEtherHolder
        address _freshEOA = freshEOA;
        bytes32 slot;
        assembly {
            mstore(0, _freshEOA)
            mstore(0x20, 0x0)
            slot := keccak256(0, 0x40)
        }

        vm.store(yfiAddress, slot, bytes32(uint256(60 * 10**18)));
    }
}
