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

import {Starport} from "starport-core/Starport.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {AstariaV1RatioLenderEnforcer} from "v1-core/enforcers/AstariaV1RatioLenderEnforcer.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {BasePricing} from "v1-core/pricing/BasePricing.sol";

import {console2} from "forge-std/console2.sol";

contract TestV1RatioLenderEnforcer is AstariaV1Test, AstariaV1RatioLenderEnforcer {
    using FixedPointMathLib for uint256;

    function setUp() public virtual override {
        super.setUp();

        lenderEnforcer = new AstariaV1RatioLenderEnforcer();
    }

    function getDefaultV1RatioLenderDetails(Starport.Loan memory loan)
        public
        pure
        returns (AstariaV1RatioLenderEnforcer.Details memory details)
    {
        details = AstariaV1RatioLenderEnforcer.Details({
            matchIdentifier: false,
            minCollateralAmount: loan.collateral[0].amount,
            collateralToDebtRatio: loan.debt[0].amount.divWadUp(loan.collateral[0].amount),
            loan: loanCopy(loan)
        });
    }

    function testV1RatioLenderDefault() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // Test general passing case
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderDebtBundle() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // Test Debt Bundle
        loan.debt = new SpentItem[](2);
        vm.expectRevert(DebtBundlesNotSupported.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderCollateralBundle() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // Test Collateral Bundle
        loan.collateral = new SpentItem[](2);
        vm.expectRevert(CollateralBundlesNotSupported.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderMinCollateralAmount() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // Test below min collateral amount
        loan.collateral[0].amount--;
        vm.expectRevert(BelowMinCollateralAmount.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // Test below min above collateral amount
        loan.collateral[0].amount += 2;
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderDebtAmountExceedsDebtMax() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        //
        loan.debt[0].amount++;
        vm.expectRevert(
            abi.encodeWithSelector(
                DebtAmountExceedsDebtMax.selector,
                loan.collateral[0].amount.mulWad(details.collateralToDebtRatio),
                loan.debt[0].amount
            )
        );
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderMaxDebtOrCollateralToDebtRatioZero() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        loan.debt[0].amount = 0;
        loan.collateral[0].amount = 0;
        details.collateralToDebtRatio = 0;
        details.minCollateralAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(MaxDebtOrCollateralToDebtRatioZero.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderLoanRateLessThanCaveatRate() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
        pricingDetails.rate--;
        loan.terms.pricingData = abi.encode(pricingDetails);
        vm.expectRevert(LoanRateLessThanCaveatRate.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderEnforcerRate() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // Test malleable rate
        AstariaV1Lib.setBasePricingRate(
            loan.terms.pricingData, AstariaV1Lib.getBasePricingRate(details.loan.terms.pricingData) + 1
        );
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // Test insufficient rate
        AstariaV1Lib.setBasePricingRate(
            loan.terms.pricingData, AstariaV1Lib.getBasePricingRate(details.loan.terms.pricingData) - 1
        );
        vm.expectRevert(LoanRateLessThanCaveatRate.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    // Test matchIdentifier
    function testV1RatioLenderEnforcerMatchIdentifier() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        loan.collateral[0].identifier += 1;

        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
        details.matchIdentifier = true;

        vm.expectRevert(LenderEnforcer.InvalidLoanTerms.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1RatioLenderEnforcerAdditionalTransfers() external {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);
        // Test invalid additional transfer from lender
        AdditionalTransfer[] memory additionalTransfers = new AdditionalTransfer[](1);
        additionalTransfers[0] = AdditionalTransfer({
            token: address(0),
            amount: 0,
            to: address(0),
            from: lender.addr,
            identifier: 0,
            itemType: ItemType.ERC20
        });

        vm.expectRevert(LenderEnforcer.InvalidAdditionalTransfer.selector);
        lenderEnforcer.validate(additionalTransfers, loan, abi.encode(details));

        // Test valid additional transfer from other party
        additionalTransfers[0].from = borrower.addr;
        lenderEnforcer.validate(additionalTransfers, loan, abi.encode(details));
    }

    // ensures that a debt copy occurs at the end of validate
    function testV1LenderEnforcerCopyDebtAmount() external {
        Starport.Loan memory loan = generateDefaultERC20LoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = AstariaV1RatioLenderEnforcer.Details({
            matchIdentifier: false,
            minCollateralAmount: 1,
            collateralToDebtRatio: loan.debt[0].amount.divWadUp(loan.collateral[0].amount),
            loan: loanCopy(loan)
        });

        loan.debt[0].amount /= 2;
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    // ensures that a collateral copy occurs at the end of validate
    function testV1LenderEnforcerCopyCollateralAmount() external {
        Starport.Loan memory loan = generateDefaultERC20LoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = AstariaV1RatioLenderEnforcer.Details({
            matchIdentifier: false,
            minCollateralAmount: 1,
            collateralToDebtRatio: loan.debt[0].amount.divWadUp(loan.collateral[0].amount),
            loan: loanCopy(loan)
        });

        loan.collateral[0].amount = 10;
        loan.debt[0].amount = loan.collateral[0].amount.mulWad(details.collateralToDebtRatio);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    // ensures that a borrower copy occurs at the beginning of _validate
    function testV1LenderEnforcerCopyBorrower() external {
        Starport.Loan memory loan = generateDefaultERC20LoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // ensuring that the details.loan.borrower does not match the loan.borrower
        details.loan.borrower = address(uint160(details.loan.borrower) << 1);
        assert(details.loan.borrower != loan.borrower);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    // ensures that a originator copy occurs at the beginning of _validate
    function testV1LenderEnforcerCopyOriginator() external {
        Starport.Loan memory loan = generateDefaultERC20LoanTerms();
        AstariaV1RatioLenderEnforcer.Details memory details = getDefaultV1RatioLenderDetails(loan);

        // ensuring that the details.loan.originator does not match the loan.originator
        details.loan.originator = address(uint160(fulfiller.addr) << 1);
        assert(details.loan.originator != loan.originator);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }
}
