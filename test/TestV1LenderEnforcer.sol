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

import {AstariaV1LenderEnforcer} from "v1-core/enforcers/AstariaV1LenderEnforcer.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract TestV1LenderEnforcer is AstariaV1Test, AstariaV1LenderEnforcer {
    function testV1LenderEnforcerAmount() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        uint256 max = loan.debt[0].amount;
        AstariaV1LenderEnforcer.Details memory details = AstariaV1LenderEnforcer.Details({
            matchIdentifier: true,
            minDebtAmount: loan.debt[0].amount / 2,
            loan: loanCopy(loan)
        });

        // Test excessive amount
        loan.debt[0].amount = details.loan.debt[0].amount + 1;
        vm.expectRevert(abi.encodeWithSelector(DebtAmountOOB.selector, details.minDebtAmount, max, loan.debt[0].amount));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // Test insufficient amount
        loan.debt[0].amount = details.minDebtAmount - 1;
        vm.expectRevert(abi.encodeWithSelector(DebtAmountOOB.selector, details.minDebtAmount, max, loan.debt[0].amount));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // on upper bound match
        loan.debt[0].amount = details.loan.debt[0].amount;
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // on lower bound match
        loan.debt[0].amount = details.minDebtAmount;
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // in between upper and lower bound
        loan.debt[0].amount = details.minDebtAmount + 5;
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1LenderEnforcerMinDebtExceedsMax() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1LenderEnforcer.Details memory details = AstariaV1LenderEnforcer.Details({
            matchIdentifier: true,
            minDebtAmount: loan.debt[0].amount + 1,
            loan: loanCopy(loan)
        });

        // Test excessive amount
        vm.expectRevert(MinDebtAmountExceedsMax.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1LenderEnforcerRate() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1LenderEnforcer.Details memory details = AstariaV1LenderEnforcer.Details({
            matchIdentifier: true,
            minDebtAmount: loan.debt[0].amount,
            loan: loanCopy(loan)
        });

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
    function testV1LenderEnforcerMatchIdentifier() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1LenderEnforcer.Details memory details = AstariaV1LenderEnforcer.Details({
            matchIdentifier: false,
            minDebtAmount: loan.debt[0].amount,
            loan: loanCopy(loan)
        });
        loan.collateral[0].identifier += 1;

        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
        details.matchIdentifier = true;

        vm.expectRevert(LenderEnforcer.InvalidLoanTerms.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1LenderEnforcerAdditionalTransfers() external {
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

        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1LenderEnforcer.Details memory details =
            AstariaV1LenderEnforcer.Details({matchIdentifier: false, minDebtAmount: loan.debt[0].amount, loan: loan});

        vm.expectRevert(LenderEnforcer.InvalidAdditionalTransfer.selector);
        lenderEnforcer.validate(additionalTransfers, loan, abi.encode(details));

        // Test valid additional transfer from other party
        additionalTransfers[0].from = borrower.addr;
        lenderEnforcer.validate(additionalTransfers, loan, abi.encode(details));
    }

    function testV1LenderEnforcerDebtBundlesNotSupported() external {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        SpentItem[] memory debt = new SpentItem[](2);
        debt[0] = loan.debt[0];
        debt[1] = _getERC721SpentItem(TestERC721(loan.debt[0].token), loan.debt[0].identifier + 1);
        loan.debt = debt;

        AstariaV1LenderEnforcer.Details({matchIdentifier: false, minDebtAmount: loan.debt[0].amount, loan: loan});

        vm.expectRevert(DebtBundlesNotSupported.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(LenderEnforcer.Details({loan: loan})));
    }
}
