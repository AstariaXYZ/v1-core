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

import {CaveatEnforcer} from "starport-core/enforcers/CaveatEnforcer.sol";
import {StarportLib, Actions} from "starport-core/lib/StarportLib.sol";
import {PausableNonReentrant} from "starport-core/lib/PausableNonReentrant.sol";

import {DeepEq} from "starport-test/utils/DeepEq.sol";
import {SpentItemLib} from "seaport-sol/src/lib/SpentItemLib.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {Validation} from "starport-core/lib/Validation.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract TestAstariaV1Status is AstariaV1Test, DeepEq {
    using Cast for *;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using {StarportLib.getId} for Starport.Loan;

    event Recalled(uint256 loandId, address recaller, uint256 end);
    event Withdraw(uint256 loanId, address withdrawer);

    function testIsActive() public {
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
        assert(AstariaV1Status(loan.terms.status).isActive(loan, ""));
    }

    function testRecallPauseable() public {
        AstariaV1Status v1Status = AstariaV1Status(address(status));
        v1Status.pause();

        Starport.Loan memory loan;
        vm.expectRevert(PausableNonReentrant.IsPaused.selector);
        v1Status.recall(loan);

        vm.prank(address(0xdead));
        vm.expectRevert(Ownable.Unauthorized.selector);
        v1Status.unpause();

        v1Status.unpause();
    }

    function testIsRecalledInsideWindow() public {
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

        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        erc20s[0].mint(address(this), 10e18);
        erc20s[0].approve(loan.terms.status, 10e18);

        skip(details.honeymoon);
        vm.startPrank(loan.issuer);
        vm.expectEmit();
        emit Recalled(loanId, loan.issuer, block.timestamp + details.recallWindow);
        AstariaV1Status(loan.terms.status).recall(loan);
        vm.stopPrank();
        (address recaller, uint64 recallStart) = AstariaV1Status(loan.terms.status).recalls(loanId);
        skip(details.recallWindow - 1);
        assert(AstariaV1Status(loan.terms.status).isActive(loan, ""));
        assert(AstariaV1Status(loan.terms.status).isRecalled(loan));
    }

    function testRecallAndRefinanceInsideWindow() public {
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

        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        erc20s[0].mint(address(this), 10e18);
        erc20s[0].approve(loan.terms.status, 10e18);

        skip(details.honeymoon);
        vm.expectEmit();
        emit Recalled(loanId, loan.issuer, block.timestamp + details.recallWindow);
        vm.prank(loan.issuer);
        AstariaV1Status(loan.terms.status).recall(loan);
        (address recaller, uint64 recallStart) = AstariaV1Status(loan.terms.status).recalls(loanId);
        skip(details.recallWindow - 1);
        address newLender = address(55);

        BasePricing.Details memory newPricingData = abi.decode(defaultPricingData, (BasePricing.Details));
        newPricingData.rate = newPricingData.rate * 2;

        vm.startPrank(newLender);
        erc20s[0].mint(newLender, 10e18);
        erc20s[0].approve(address(SP), 10e18);
        SP.refinance(newLender, _emptyCaveat(), loan, abi.encode(newPricingData), "");
        assert(erc20s[0].balanceOf(address(loan.terms.status)) == 0);
    }

    function testRecallAndRefinanceWithLenderCaveat() public {
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

        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        skip(details.honeymoon);

        vm.prank(lender.addr);
        AstariaV1Status(loan.terms.status).recall(loan);
        skip(details.recallWindow - 1);

        BasePricing.Details memory newPricingData = abi.decode(defaultPricingData, (BasePricing.Details));
        newPricingData.rate = newPricingData.rate * 2;

        Starport.Loan memory caveatLoan = loanCopy(loan);

        (SpentItem[] memory repayConsideration, SpentItem[] memory carryConsideration,) = AstariaV1Pricing(
            loan.terms.pricing
        ).getRefinanceConsideration(loan, abi.encode(newPricingData), address(0xdead));

        caveatLoan.debt = SP.applyRefinanceConsiderationToLoan(repayConsideration, carryConsideration);
        caveatLoan.terms.pricingData = abi.encode(newPricingData);
        caveatLoan.issuer = refinancer.addr;
        caveatLoan.originator = address(0);
        caveatLoan.start = 0;

        CaveatEnforcer.SignedCaveats memory signedCaveats =
            _generateSignedCaveatLender(caveatLoan, refinancer, bytes32(uint256(2)), true);

        vm.startPrank(refinancer.addr);
        erc20s[0].mint(refinancer.addr, caveatLoan.debt[0].amount);
        erc20s[0].approve(address(SP), caveatLoan.debt[0].amount);
        vm.stopPrank();

        vm.prank(address(0xdead));
        SP.refinance(refinancer.addr, signedCaveats, loan, abi.encode(newPricingData), "");
    }

    function testInvalidRecallLoanDoesNotExist() public {
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

        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        erc20s[0].mint(address(this), 10e18);
        erc20s[0].approve(loan.terms.status, 10e18);

        skip(details.honeymoon);
        vm.mockCall(address(SP), abi.encodeWithSelector(SP.closed.selector, loan.getId()), abi.encode(true));
        vm.prank(loan.issuer);
        vm.expectRevert(abi.encodeWithSelector(BaseRecall.LoanDoesNotExist.selector));
        AstariaV1Status(loan.terms.status).recall(loan);
    }

    function testCannotRecallTwice() public {
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

        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        erc20s[0].mint(address(this), 10e18);
        erc20s[0].approve(loan.terms.status, 10e18);

        skip(details.honeymoon);
        vm.startPrank(loan.issuer);
        AstariaV1Status(loan.terms.status).recall(loan);
        vm.expectRevert(abi.encodeWithSelector(BaseRecall.RecallAlreadyExists.selector));
        AstariaV1Status(loan.terms.status).recall(loan);
        vm.stopPrank();
    }

    function testIsRecalledOutsideWindow() public {
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
        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        erc20s[0].mint(address(this), 10e18);
        erc20s[0].approve(loan.terms.status, 10e18);

        skip(details.honeymoon);
        vm.prank(loan.issuer);
        AstariaV1Status(loan.terms.status).recall(loan);
        (address recaller, uint64 recallStart) = AstariaV1Status(loan.terms.status).recalls(loanId);
        skip(details.recallWindow + 1);
        assert(!AstariaV1Status(loan.terms.status).isActive(loan, ""));
        assert(!AstariaV1Status(loan.terms.status).isRecalled(loan));
    }

    function testRecallRateEmptyRecall() public {
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
        BaseRecall.Details memory hookDetails = abi.decode(loan.terms.statusData, (BaseRecall.Details));
        uint256 recallRate = AstariaV1Status(loan.terms.status).getRecallRate(loan);
        uint256 computedRecallRate =
            hookDetails.recallMax.mulWad((block.timestamp - 0).divWad(hookDetails.recallWindow));
        assertEq(recallRate, computedRecallRate);
    }

    function testRecallRateActiveRecall() public {
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
        BaseRecall.Details memory hookDetails = abi.decode(loan.terms.statusData, (BaseRecall.Details));

        erc20s[0].mint(address(this), 10e18);
        erc20s[0].approve(loan.terms.status, 10e18);

        skip(hookDetails.honeymoon);
        vm.prank(loan.issuer);
        AstariaV1Status(loan.terms.status).recall(loan);
        (address recaller, uint64 recallStart) = AstariaV1Status(loan.terms.status).recalls(loanId);
        uint256 recallRate = AstariaV1Status(loan.terms.status).getRecallRate(loan);
        uint256 computedRecallRate =
            hookDetails.recallMax.mulWad((block.timestamp - recallStart).divWad(hookDetails.recallWindow));
        assertEq(recallRate, computedRecallRate);
    }

    function testV1StatusValidateValid() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        assert(Validation(loan.terms.status).validate(loan) == Validation.validate.selector);
    }

    function testV1StatusValidateInValid() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory defaultDetailsData = loan.terms.statusData;
        BaseRecall.Details memory details = abi.decode(loan.terms.statusData, (BaseRecall.Details));
        details.recallMax = 1e19 + 1;
        loan.terms.statusData = abi.encode(details);
        assert(Validation(loan.terms.status).validate(loan) == bytes4(0xFFFFFFFF));
        details = abi.decode(defaultDetailsData, (BaseRecall.Details));
        details.recallMax = 1000 ** 19;
        loan.terms.statusData = abi.encode(details);
        assert(Validation(loan.terms.status).validate(loan) == bytes4(0xFFFFFFFF));
    }
}
