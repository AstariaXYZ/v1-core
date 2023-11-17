// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import "test/AstariaV1Test.sol";

import {StarportLib, Actions} from "starport-core/lib/StarportLib.sol";
import {BaseRecall} from "v1-core/status/BaseRecall.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract TestAstariaV1Loan is AstariaV1Test {
    using FixedPointMathLib for uint256;
    using {StarportLib.getId} for Starport.Loan;
    using Cast for *;

    Starport.Loan activeLoan;

    function testNewLoanERC721CollateralDefaultTermsRecallAuctionFailLenderClaim() public {
        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        BaseRecall.Details memory statusDetails = abi.decode(loan.terms.statusData, (BaseRecall.Details));
        skip(statusDetails.honeymoon);

        uint256 recallerBalanceBefore = ERC20(loan.debt[0].token).balanceOf(recaller.addr);
        vm.prank(recaller.addr);
        BaseRecall(address(status)).recall(loan);

        AstariaV1Settlement.Details memory settlementDetails =
            abi.decode(loan.terms.settlementData, (DutchAuctionSettlement.Details));

        skip(statusDetails.recallWindow + settlementDetails.window + 2);

        uint256 balanceBefore = ERC20(loan.debt[0].token).balanceOf(lender.addr);

        OrderParameters memory op = _buildContractOrder(
            address(loan.custodian),
            _SpentItemsToOfferItems(loan.collateral),
            _toConsiderationItems(new ReceivedItem[](0))
        );

        AdvancedOrder memory x = AdvancedOrder({
            parameters: op,
            numerator: 1,
            denominator: 1,
            signature: "0x",
            extraData: abi.encode(Custodian.Command(Actions.Settlement, loan, ""))
        });

        vm.prank(lender.addr);
        consideration.fulfillAdvancedOrder({
            advancedOrder: x,
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(lender.addr)
        });

        assertEq(
            ERC20(loan.debt[0].token).balanceOf(recaller.addr),
            recallerBalanceBefore,
            "recaller balance should not change"
        );
        assertEq(ERC20(loan.debt[0].token).balanceOf(lender.addr), balanceBefore, "lender balance should not change");
        assertEq(
            ERC721(loan.collateral[0].token).ownerOf(loan.collateral[0].identifier),
            lender.addr,
            "lender should receive collateral"
        );
    }

    function testNewLoanERC721CollateralDefaultTermsRecallAuctionFailLenderClaimRandomFulfiller() public {
        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        BaseRecall.Details memory statusDetails = abi.decode(loan.terms.statusData, (BaseRecall.Details));
        skip(statusDetails.honeymoon);

        uint256 recallerBalanceBefore = ERC20(loan.debt[0].token).balanceOf(recaller.addr);
        vm.prank(recaller.addr);
        BaseRecall(address(status)).recall(loan);

        AstariaV1Settlement.Details memory settlementDetails =
            abi.decode(loan.terms.settlementData, (DutchAuctionSettlement.Details));

        skip(statusDetails.recallWindow + settlementDetails.window + 2);

        uint256 fulfillerBalanceBefore = ERC20(loan.debt[0].token).balanceOf(address(this));

        OrderParameters memory op = _buildContractOrder(
            address(loan.custodian),
            _SpentItemsToOfferItems(new SpentItem[](0)),
            _toConsiderationItems(new ReceivedItem[](0))
        );

        AdvancedOrder memory x = AdvancedOrder({
            parameters: op,
            numerator: 1,
            denominator: 1,
            signature: "0x",
            extraData: abi.encode(Custodian.Command(Actions.Settlement, loan, ""))
        });

        consideration.fulfillAdvancedOrder({
            advancedOrder: x,
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(this) //recipient should be ignored
        });

        assertEq(
            ERC20(loan.debt[0].token).balanceOf(address(this)),
            fulfillerBalanceBefore,
            "fulfiller balance should not change"
        );
        assertEq(
            ERC20(loan.debt[0].token).balanceOf(recaller.addr),
            recallerBalanceBefore,
            "recaller balance should not change"
        );

        assertEq(
            ERC721(loan.collateral[0].token).ownerOf(loan.collateral[0].identifier),
            lender.addr,
            "lender should receive collateral"
        );
    }

    function testNewLoanERC721CollateralDefaultTermsRecallBase() public {
        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        skip(1);
        {
            vm.startPrank(recaller.addr);
            vm.expectRevert(BaseRecall.RecallBeforeHoneymoonExpiry.selector);
            // attempt recall before honeymoon period has ended
            BaseRecall(address(status)).recall(loan);
            vm.stopPrank();
        }
        {
            // refinance with before recall is initiated
            CaveatEnforcer.SignedCaveats memory lenderCaveat = CaveatEnforcer.SignedCaveats({
                signature: "",
                singleUse: true,
                deadline: block.timestamp + 1 days,
                salt: bytes32(uint256(1)),
                caveats: new CaveatEnforcer.Caveat[](1)
            });
            lenderCaveat.caveats[0] =
                CaveatEnforcer.Caveat({enforcer: address(lenderEnforcer), data: abi.encode(uint256(0))});

            refinanceLoan(
                loan,
                abi.encode(BasePricing.Details({rate: (uint256(1e16) * 100), carryRate: 0, decimals: 18})),
                refinancer.addr,
                lenderCaveat,
                refinancer.addr,
                abi.encodeWithSelector(Pricing.InvalidRefinance.selector)
            );
        }
        uint256 stake;
        {
            uint256 balanceBefore = erc20s[0].balanceOf(recaller.addr);
            uint256 recallContractBalanceBefore = erc20s[0].balanceOf(address(status));
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            vm.warp(block.timestamp + details.honeymoon);
            vm.startPrank(recaller.addr);

            BaseRecall recallContract = BaseRecall(address(status));
            recallContract.recall(loan);
            vm.stopPrank();

            uint256 balanceAfter = erc20s[0].balanceOf(recaller.addr);
            uint256 recallContractBalanceAfter = erc20s[0].balanceOf(address(status));

            BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            stake = BasePricing(address(pricing)).calculateInterest(
                details.recallStakeDuration, loan.debt[0].amount, pricingDetails.rate, pricingDetails.decimals
            );
            assertEq(balanceBefore - stake, balanceAfter, "Recaller balance not transfered correctly");
            assertEq(
                recallContractBalanceBefore + stake,
                recallContractBalanceAfter,
                "Balance not transfered to recall contract correctly"
            );
        }
        {
            uint256 loanId = loan.getId();
            BaseRecall recallContract = BaseRecall(address(status));
            address recallerAddr;
            uint64 start;
            (recallerAddr, start) = recallContract.recalls(loanId);

            assertEq(recaller.addr, recallerAddr, "Recaller address logged incorrectly");
            assertEq(start, block.timestamp, "Recall start logged incorrectly");
        }
        {
            BaseRecall recallContract = BaseRecall(address(status));
            vm.expectRevert(BaseRecall.LoanHasNotBeenRefinanced.selector);
            // attempt a withdraw without the loan being refinanced
            recallContract.withdraw(loan, payable(address(this)));
        }
        {
            // refinance with incorrect terms
            CaveatEnforcer.SignedCaveats memory lenderCaveat = CaveatEnforcer.SignedCaveats({
                signature: "",
                singleUse: true,
                deadline: block.timestamp + 1 days,
                salt: bytes32(uint256(1)),
                caveats: new CaveatEnforcer.Caveat[](1)
            });

            lenderCaveat.caveats[0] =
                CaveatEnforcer.Caveat({enforcer: address(lenderEnforcer), data: abi.encode(uint256(0))});
            refinanceLoan(
                loan,
                abi.encode(BasePricing.Details({rate: (uint256(1e16) * 100), carryRate: 0, decimals: 18})),
                refinancer.addr,
                lenderCaveat,
                refinancer.addr,
                abi.encodeWithSelector(AstariaV1Pricing.InsufficientRefinance.selector)
            );
        }
        {
            // refinance with correct terms
            uint256 newLenderBefore = erc20s[0].balanceOf(refinancer.addr);
            uint256 oldLenderBefore = erc20s[0].balanceOf(lender.addr);
            uint256 oldOriginatorBefore = erc20s[0].balanceOf(loan.originator);
            uint256 recallerBefore = erc20s[0].balanceOf(recaller.addr);
            uint256 newFullfillerBefore = erc20s[0].balanceOf(address(this));
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            vm.warp(block.timestamp + (details.recallWindow / 2));

            bytes memory pricingData =
                abi.encode(BasePricing.Details({rate: details.recallMax / 2, carryRate: 0, decimals: 18}));
            {
                Starport.Loan memory refinancableLoan = getRefinanceDetails(loan, pricingData, refinancer.addr).loan;
                CaveatEnforcer.SignedCaveats memory refinancerCaveat =
                    _generateSignedCaveatLender(refinancableLoan, refinancer, bytes32(uint256(1)), true);

                vm.startPrank(refinancer.addr);
                erc20s[0].approve(address(SP), refinancableLoan.debt[0].amount);
                vm.stopPrank();

                erc20s[0].approve(address(SP), stake);
                refinanceLoan(loan, pricingData, address(this), refinancerCaveat, refinancer.addr);
            }

            BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            uint256 interest;
            {
                uint256 delta_t = block.timestamp - loan.start;
                interest = BasePricing(address(pricing)).calculateInterest(
                    delta_t, loan.debt[0].amount, pricingDetails.rate, pricingDetails.decimals
                );

                uint256 oldLenderAfter = erc20s[0].balanceOf(lender.addr);
                assertEq(
                    oldLenderAfter,
                    oldLenderBefore + loan.debt[0].amount + interest.mulWadUp(1e18 - pricingDetails.carryRate),
                    "Payment to old lender calculated incorrectly"
                );
            }

            {
                uint256 newLenderAfter = erc20s[0].balanceOf(refinancer.addr);
                assertEq(
                    newLenderAfter,
                    newLenderBefore - (loan.debt[0].amount + interest),
                    "Payment from new lender calculated incorrectly"
                );
            }
            assertEq(
                recallerBefore + stake, erc20s[0].balanceOf(recaller.addr), "Recaller did not recover stake as expected"
            );

            {
                assertEq(
                    erc20s[0].balanceOf(loan.originator),
                    oldOriginatorBefore + interest.mulWad(pricingDetails.carryRate),
                    "Carry payment to old originator calculated incorrectly"
                );
            }

            {
                assertEq(
                    erc20s[0].balanceOf(address(this)),
                    newFullfillerBefore,
                    "New fulfiller did not repay recaller stake correctly"
                );
            }

            {
                uint256 loanId = loan.getId();
                assertTrue(SP.inactive(loanId), "LoanId not properly flipped to inactive after refinance");
            }
        }
        {
            uint256 recallContractBalanceAfter = erc20s[0].balanceOf(address(status));
            assertEq(recallContractBalanceAfter, uint256(0), "BaseRecall did get emptied as expected");
        }
    }

    // lender is recaller, liquidation amount is 0
    function testNewLoanERC721CollateralDefaultTermsRecallLender() public {
        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        uint256 stake;
        {
            uint256 balanceBefore = erc20s[0].balanceOf(lender.addr);
            uint256 recallContractBalanceBefore = erc20s[0].balanceOf(address(status));
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            vm.warp(block.timestamp + details.honeymoon);
            vm.startPrank(lender.addr);
            conduitController.updateChannel(lenderConduit, address(status), true);
            BaseRecall recallContract = BaseRecall(address(status));
            erc20s[0].approve(loan.terms.status, 10e18);
            recallContract.recall(loan);
            vm.stopPrank();

            BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            stake = BasePricing(address(pricing)).calculateInterest(
                details.recallStakeDuration, loan.debt[0].amount, pricingDetails.rate, pricingDetails.decimals
            );
            // lender is not required to provide a stake to recall
            assertEq(balanceBefore, erc20s[0].balanceOf(lender.addr), "Recaller balance not transfered correctly");
            assertEq(
                recallContractBalanceBefore,
                erc20s[0].balanceOf(address(status)),
                "Balance not transfered to recall contract correctly"
            );
        }

        {
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            // warp past the end of the recall window
            vm.warp(block.timestamp + details.recallWindow + 1);

            OfferItem[] memory repayOffering = new OfferItem[](
            loan.collateral.length
          );
            uint256 i = 0;
            for (; i < loan.collateral.length;) {
                repayOffering[i] = OfferItem({
                    itemType: loan.collateral[i].itemType,
                    token: address(loan.collateral[i].token),
                    identifierOrCriteria: loan.collateral[i].identifier,
                    endAmount: loan.collateral[i].itemType != ItemType.ERC721 ? loan.collateral[i].amount : 1,
                    startAmount: loan.collateral[i].itemType != ItemType.ERC721 ? loan.collateral[i].amount : 1
                });
                unchecked {
                    ++i;
                }
            }
            (ReceivedItem[] memory settlementConsideration, address restricted) =
                Settlement(loan.terms.settlement).getSettlementConsideration(loan);

            assertEq(
                settlementConsideration.length, 0, "Settlement consideration for a recalling Lender should be zero"
            );
            assertEq(restricted, lender.addr, "SettlementConsideration should be restricted to the lender");
            ConsiderationItem[] memory consider = new ConsiderationItem[](
            settlementConsideration.length
          );
            i = 0;
            for (; i < settlementConsideration.length;) {
                consider[i].token = settlementConsideration[i].token;
                consider[i].itemType = settlementConsideration[i].itemType;
                consider[i].identifierOrCriteria = settlementConsideration[i].identifier;
                consider[i].startAmount = settlementConsideration[i].amount;
                consider[i].endAmount = settlementConsideration[i].amount;
                consider[i].recipient = settlementConsideration[i].recipient;
                unchecked {
                    ++i;
                }
            }

            vm.startPrank(lender.addr);
            OrderParameters memory op = _buildContractOrder(address(loan.custodian), repayOffering, consider);

            AdvancedOrder memory settlementOrder = AdvancedOrder({
                numerator: 1,
                denominator: 1,
                parameters: op,
                extraData: abi.encode(Custodian.Command(Actions.Settlement, loan, "")),
                signature: ""
            });

            consideration.fulfillAdvancedOrder({
                advancedOrder: settlementOrder,
                criteriaResolvers: new CriteriaResolver[](0),
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });
            vm.stopPrank();
        }
        {
            address owner = erc721s[0].ownerOf(1);
            assertEq(owner, lender.addr, "Lender should be the owner of the NFT after settlement");
        }
    }

    // recaller is not the lender, liquidation amount is a dutch auction
    function testNewLoanERC721CollateralDefaultTermsRecallLiquidation() public {
        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});
        // uint256 loanId = loan.getId();

        loan.toStorage(activeLoan);
        uint256 elapsedTime;
        uint256 stake;
        {
            uint256 balanceBefore = erc20s[0].balanceOf(recaller.addr);
            uint256 recallContractBalanceBefore = erc20s[0].balanceOf(address(status));
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            vm.warp(block.timestamp + details.honeymoon);
            elapsedTime += details.honeymoon;
            vm.startPrank(recaller.addr);

            BaseRecall recallContract = BaseRecall(address(status));
            recallContract.recall(loan);
            vm.stopPrank();

            uint256 balanceAfter = erc20s[0].balanceOf(recaller.addr);
            uint256 recallContractBalanceAfter = erc20s[0].balanceOf(address(status));

            BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            stake = BasePricing(address(pricing)).calculateInterest(
                details.recallStakeDuration, loan.debt[0].amount, pricingDetails.rate, pricingDetails.decimals
            );
            assertEq(balanceBefore - stake, balanceAfter, "Recaller balance not transfered correctly");
            assertEq(
                recallContractBalanceBefore + stake,
                recallContractBalanceAfter,
                "Balance not transfered to recall contract correctly"
            );
        }

        {
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            // warp past the end of the recall window
            vm.warp(block.timestamp + details.recallWindow + 1);
            elapsedTime += (details.recallWindow + 1);
            OfferItem[] memory repayOffering = new OfferItem[](
                loan.collateral.length
            );
            uint256 i = 0;
            for (; i < loan.collateral.length;) {
                repayOffering[i] = OfferItem({
                    itemType: loan.collateral[i].itemType,
                    token: address(loan.collateral[i].token),
                    identifierOrCriteria: loan.collateral[i].identifier,
                    endAmount: loan.collateral[i].itemType != ItemType.ERC721 ? loan.collateral[i].amount : 1,
                    startAmount: loan.collateral[i].itemType != ItemType.ERC721 ? loan.collateral[i].amount : 1
                });
                unchecked {
                    ++i;
                }
            }
            (ReceivedItem[] memory settlementConsideration, address restricted) =
                Settlement(loan.terms.settlement).getSettlementConsideration(loan);

            assertEq(
                settlementConsideration.length,
                3,
                "Settlement consideration length for a dutch auction should be 3 (carry, recaller, and the lender)"
            );
            assertEq(restricted, address(0), "SettlementConsideration should be unrestricted");
            AdditionalTransfer[] memory extraPayment;
            {
                BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
                uint256 interest = AstariaV1Lib.calculateCompoundInterest(
                    elapsedTime, loan.debt[0].amount, pricingDetails.rate, pricingDetails.decimals
                );
                uint256 carry = interest.mulWad(pricingDetails.carryRate);
                uint256 settlementPrice = 500 ether - carry;
                uint256 recallerReward = settlementPrice.mulWad(10e16);
                assertEq(settlementConsideration[0].amount, carry, "Settlement consideration for carry incorrect");
                assertEq(
                    settlementConsideration[1].amount, recallerReward, "Settlement consideration for recaller incorrect"
                );
                assertEq(
                    settlementConsideration[2].amount,
                    settlementPrice - recallerReward,
                    "Settlement consideration for lender incorrect"
                );
                extraPayment = AstariaV1Status(activeLoan.terms.status).generateRecallConsideration(
                    activeLoan, 0, activeLoan.terms.status, address(this)
                );
            }
            ConsiderationItem[] memory consider = new ConsiderationItem[](
                settlementConsideration.length
            );
            i = 0;
            for (; i < settlementConsideration.length;) {
                consider[i].token = settlementConsideration[i].token;
                consider[i].itemType = settlementConsideration[i].itemType;
                consider[i].identifierOrCriteria = settlementConsideration[i].identifier;
                consider[i].startAmount = settlementConsideration[i].amount;
                consider[i].endAmount = settlementConsideration[i].amount;
                consider[i].recipient = settlementConsideration[i].recipient;
                unchecked {
                    ++i;
                }
            }

            uint256 balanceBefore = ERC20(loan.debt[0].token).balanceOf(address(this));
            OrderParameters memory op = _buildContractOrder(address(loan.custodian), repayOffering, consider);

            AdvancedOrder memory settlementOrder = AdvancedOrder({
                numerator: 1,
                denominator: 1,
                parameters: op,
                extraData: abi.encode(Custodian.Command(Actions.Settlement, activeLoan, "")),
                signature: ""
            });

            consideration.fulfillAdvancedOrder({
                advancedOrder: settlementOrder,
                criteriaResolvers: new CriteriaResolver[](0),
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });
            uint256 balanceAfter = ERC20(loan.debt[0].token).balanceOf(address(this));
            address owner = erc721s[0].ownerOf(1);

            assertTrue(balanceBefore != balanceAfter, "Balance not transfered to settlement contract correctly");
            assertEq(
                balanceBefore - 500 ether,
                balanceAfter,
                "balance of buyer not decremented correctly"
            );
            assertEq(owner, address(this), "Test address should be the owner of the NFT after settlement");
        }
    }
}
