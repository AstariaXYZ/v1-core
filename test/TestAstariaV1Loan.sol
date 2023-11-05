pragma solidity ^0.8.17;

import "test/AstariaV1Test.sol";

import {BaseRecall} from "src/status/BaseRecall.sol";
import "forge-std/console2.sol";
import {StarportLib, Actions} from "starport-core/lib/StarportLib.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract TestAstariaV1Loan is AstariaV1Test {
    using FixedPointMathLib for uint256;
    using {StarportLib.getId} for Starport.Loan;
    using Cast for *;

    Starport.Loan activeLoan;

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
            CaveatEnforcer.CaveatWithApproval memory lenderCaveat = CaveatEnforcer.CaveatWithApproval({
                v: 0,
                r: bytes32(0),
                s: bytes32(0),
                salt: bytes32(uint256(1)),
                caveat: new CaveatEnforcer.Caveat[](1)
            });
            lenderCaveat.caveat[0] = CaveatEnforcer.Caveat({
                enforcer: address(lenderEnforcer),
                deadline: block.timestamp + 1 days,
                data: abi.encode(uint256(0))
            });

            refinanceLoan(
                loan,
                abi.encode(BasePricing.Details({rate: (uint256(1e16) * 100) / (365 * 1 days), carryRate: 0})),
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
                details.recallStakeDuration, loan.debt[0].amount, pricingDetails.rate
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
            CaveatEnforcer.CaveatWithApproval memory lenderCaveat = CaveatEnforcer.CaveatWithApproval({
                v: 0,
                r: bytes32(0),
                s: bytes32(0),
                salt: bytes32(uint256(1)),
                caveat: new CaveatEnforcer.Caveat[](1)
            });

            lenderCaveat.caveat[0] = CaveatEnforcer.Caveat({
                enforcer: address(lenderEnforcer),
                deadline: block.timestamp + 1 days,
                data: abi.encode(uint256(0))
            });
            refinanceLoan(
                loan,
                abi.encode(BasePricing.Details({rate: (uint256(1e16) * 100) / (365 * 1 days), carryRate: 0})),
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

            bytes memory pricingData = abi.encode(BasePricing.Details({rate: details.recallMax / 2, carryRate: 0}));
            {
                LenderEnforcer.Details memory refinanceDetails = getRefinanceDetails(loan, pricingData, refinancer.addr);
                console.log("here");
                CaveatEnforcer.CaveatWithApproval memory refinancerCaveat =
                    getLenderSignedCaveat(refinanceDetails, refinancer, bytes32(uint256(1)), address(lenderEnforcer));
                // vm.startPrank(refinancer.addr);
                console.logBytes32(
                    SP.hashCaveatWithSaltAndNonce(refinancer.addr, bytes32(uint256(1)), refinancerCaveat.caveat)
                );

                vm.startPrank(refinancer.addr);
                erc20s[0].approve(address(SP), refinanceDetails.loan.debt[0].amount);
                vm.stopPrank();

                erc20s[0].approve(address(SP), stake);
                refinanceLoan(loan, pricingData, address(this), refinancerCaveat, refinancer.addr);
                console.log("here2", stake);
            }

            uint256 delta_t = block.timestamp - loan.start;
            BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            uint256 interest =
                BasePricing(address(pricing)).calculateInterest(delta_t, loan.debt[0].amount, pricingDetails.rate);

            {
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
            uint256 recallContractBalanceBefore = erc20s[0].balanceOf(address(status));
            BaseRecall recallContract = BaseRecall(address(status));

            // attempt a withdraw after the loan has been successfully refinanced
            //            recallContract.withdraw(loan, payable(address(this)));

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
        uint256 loanId = loan.getId();

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

            uint256 balanceAfter = erc20s[0].balanceOf(lender.addr);
            uint256 recallContractBalanceAfter = erc20s[0].balanceOf(address(status));

            BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            stake = BasePricing(address(pricing)).calculateInterest(
                details.recallStakeDuration, loan.debt[0].amount, pricingDetails.rate
            );
            // lender is not required to provide a stake to recall
            assertEq(balanceBefore, balanceAfter, "Recaller balance not transfered correctly");
            assertEq(
                recallContractBalanceBefore,
                recallContractBalanceAfter,
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
                Settlement(loan.terms.settlement).getSettlement(loan);

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
                extraData: abi.encode(Actions.Settlement, loan),
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
        uint256 loanId = loan.getId();

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
                details.recallStakeDuration, loan.debt[0].amount, pricingDetails.rate
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
                Settlement(loan.terms.settlement).getSettlement(loan);

            assertEq(
                settlementConsideration.length,
                3,
                "Settlement consideration length for a dutch auction should be 3 (carry, recaller, and the lender)"
            );
            assertEq(restricted, address(0), "SettlementConsideration should be unrestricted");
            AdditionalTransfer[] memory extraPayment;
            {
                BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
                uint256 interest =
                    StarportLib.calculateCompoundInterest(elapsedTime, loan.debt[0].amount, pricingDetails.rate);
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
                    activeLoan, 1e18, activeLoan.terms.status, address(this)
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

            uint256 balanceBefore = erc20s[0].balanceOf(address(this));
            OrderParameters memory op = _buildContractOrder(address(loan.custodian), repayOffering, consider);

            AdvancedOrder memory settlementOrder = AdvancedOrder({
                numerator: 1,
                denominator: 1,
                parameters: op,
                extraData: abi.encode(Actions.Settlement, activeLoan),
                signature: ""
            });

            consideration.fulfillAdvancedOrder({
                advancedOrder: settlementOrder,
                criteriaResolvers: new CriteriaResolver[](0),
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });
            uint256 balanceAfter = erc20s[0].balanceOf(address(this));
            address owner = erc721s[0].ownerOf(1);
            assertEq(
                balanceBefore - 500 ether + extraPayment[0].amount,
                balanceAfter,
                "balance of buyer not decremented correctly"
            );
            assertEq(owner, address(this), "Test address should be the owner of the NFT after settlement");
        }
    }
}