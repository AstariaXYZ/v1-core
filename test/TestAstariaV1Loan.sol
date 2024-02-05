//  SPDX-License-Identifier: Apache-2.0
//   █████╗ ███████╗████████╗ █████╗ ██████╗ ██╗ █████╗     ██╗   ██╗ ██╗
//  ██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██║██╔══██╗    ██║   ██║███║
//  ███████║███████╗   ██║   ███████║██████╔╝██║███████║    ██║   ██║╚██║
//  ██╔══██║╚════██║   ██║   ██╔══██║██╔══██╗██║██╔══██║    ╚██╗ ██╔╝ ██║
//  ██║  ██║███████║   ██║   ██║  ██║██║  ██║██║██║  ██║     ╚████╔╝  ██║
//  ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝      ╚═══╝   ╚═╝
//
//  Astaria v1 Lending
//  Built on Starport https://github.com/astariaXYZ/starport
//  Designed with love by Astaria Labs, Inc

pragma solidity ^0.8.17;

import "test/AstariaV1Test.sol";
import {StarportLib, Actions} from "starport-core/lib/StarportLib.sol";
import {BaseRecall} from "v1-core/status/BaseRecall.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract TestAstariaV1Loan is AstariaV1Test {
    using FixedPointMathLib for uint256;
    using {StarportLib.getId} for Starport.Loan;

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

        vm.prank(loan.issuer);
        BaseRecall(address(status)).recall(loan);

        skip(statusDetails.recallWindow + 1);

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

        assertEq(ERC20(loan.debt[0].token).balanceOf(lender.addr), balanceBefore, "lender balance should not change");
        assertEq(
            ERC721(loan.collateral[0].token).ownerOf(loan.collateral[0].identifier),
            lender.addr,
            "lender should receive collateral"
        );
    }

    function testNewLoanERC721CollateralDefaultTermsRecallLenderClaimRandomFulfiller() public {
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
        vm.prank(loan.issuer);
        BaseRecall(address(status)).recall(loan);

        skip(statusDetails.recallWindow + 1);

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
        // loan setup
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
            // attempt recall before honeymoon period has ended
            vm.startPrank(loan.issuer);
            vm.expectRevert(BaseRecall.RecallBeforeHoneymoonExpiry.selector);
            BaseRecall(address(status)).recall(loan);
            vm.stopPrank();
        }
        {
            // attempt refinance before recall is initiated
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
                abi.encodeWithSelector(AstariaV1Pricing.LoanIsNotRecalled.selector)
            );
        }
        BaseRecall recallContract = BaseRecall(address(status));
        {
            // attempt a recall after the honeymoon
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            vm.warp(block.timestamp + details.honeymoon);
            vm.prank(loan.issuer);
            recallContract.recall(loan);

            uint256 loanId = loan.getId();
            address recallerAddr;
            uint64 start;
            (recallerAddr, start) = recallContract.recalls(loanId);

            assertEq(loan.issuer, recallerAddr, "Recaller address logged incorrectly");
            assertEq(start, block.timestamp, "Recall start logged incorrectly");
        }
        {
            // attempt refinance with incorrect terms
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
            // attempt refinance with correct terms
            uint256 newLenderBefore = erc20s[0].balanceOf(refinancer.addr);
            uint256 oldLenderBefore = erc20s[0].balanceOf(lender.addr);
            uint256 oldOriginatorBefore = erc20s[0].balanceOf(loan.originator);
            uint256 newFullfillerBefore = erc20s[0].balanceOf(address(this));
            BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
            vm.warp(block.timestamp + (details.recallWindow / 2));

            bytes memory pricingData =
                abi.encode(BasePricing.Details({rate: details.recallMax / 2, carryRate: 0, decimals: 18}));
            {
                // refinance the loan address(this) is the fulfiller and refinancer.addr is the lender
                Starport.Loan memory refinancableLoan = getRefinanceDetails(loan, pricingData, refinancer.addr).loan;
                CaveatEnforcer.SignedCaveats memory refinancerCaveat =
                    _generateSignedCaveatLender(refinancableLoan, refinancer, bytes32(uint256(1)), true);

                vm.startPrank(refinancer.addr);
                erc20s[0].approve(address(SP), refinancableLoan.debt[0].amount);
                vm.stopPrank();

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
                assertTrue(SP.closed(loanId), "LoanId not properly flipped to inactive after refinance");
            }
        }
    }

    function testNewLoanERC721CollateralRecallerNotBorrowerOrLender() public {
        BaseRecall.Details memory statusDetails = abi.decode(defaultStatusData, (BaseRecall.Details));

        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: abi.encode(statusDetails)
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        uint256 elapsedTime;
        {
            vm.warp(block.timestamp + statusDetails.honeymoon);
            elapsedTime += statusDetails.honeymoon;
            vm.startPrank(recaller.addr);

            vm.expectRevert(BaseRecall.InvalidRecaller.selector);
            BaseRecall(address(status)).recall(loan);
            vm.stopPrank();
        }
    }

    function testNewLoanERC721CollateralRecallNotBlockedLender() public {
        BaseRecall.Details memory statusDetails = abi.decode(defaultStatusData, (BaseRecall.Details));

        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: abi.encode(statusDetails)
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        uint256 elapsedTime;
        {
            vm.warp(block.timestamp + statusDetails.honeymoon);
            elapsedTime += statusDetails.honeymoon;
            vm.startPrank(loan.issuer);

            BaseRecall recallContract = BaseRecall(address(status));
            recallContract.recall(loan);
            vm.stopPrank();
        }
    }

    function testNewLoanERC721CollateralRecallNotBlockedBorrower() public {
        BaseRecall.Details memory statusDetails = abi.decode(defaultStatusData, (BaseRecall.Details));

        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: abi.encode(statusDetails)
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        uint256 elapsedTime;
        {
            vm.warp(block.timestamp + statusDetails.honeymoon);
            elapsedTime += statusDetails.honeymoon;
            vm.startPrank(loan.borrower);

            BaseRecall recallContract = BaseRecall(address(status));
            recallContract.recall(loan);
            vm.stopPrank();
        }
    }
}
