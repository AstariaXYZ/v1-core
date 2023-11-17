pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";
import "./AstariaV1Test.sol";

contract TestV1LenderEnforcer is AstariaV1Test, AstariaV1LenderEnforcer {
    function testV1LenderEnforcerAmount() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1LenderEnforcer.V1LenderDetails memory details = AstariaV1LenderEnforcer.V1LenderDetails({
            matchIdentifier: true,
            details: LenderEnforcer.Details(loanCopy(loan))
        });

        //test excessive amount
        loan.debt[0].amount = details.details.loan.debt[0].amount + 1;
        vm.expectRevert(LoanAmountExceedsCaveatAmount.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        //test malleable amount
        loan.debt[0].amount = details.details.loan.debt[0].amount - 1;
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1LenderEnforcerRate() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1LenderEnforcer.V1LenderDetails memory details = AstariaV1LenderEnforcer.V1LenderDetails({
            matchIdentifier: true,
            details: LenderEnforcer.Details(loanCopy(loan))
        });

        //test malleable rate
        AstariaV1Lib.setBasePricingRate(
            loan.terms.pricingData, AstariaV1Lib.getBasePricingRate(details.details.loan.terms.pricingData) + 1
        );
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        //test insufficient rate
        AstariaV1Lib.setBasePricingRate(
            loan.terms.pricingData, AstariaV1Lib.getBasePricingRate(details.details.loan.terms.pricingData) - 1
        );
        vm.expectRevert(LoanRateLessThanCaveatRate.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    //test matchIdentifier
    function testV1LenderEnforcerMatchIdentifier() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1LenderEnforcer.V1LenderDetails memory details = AstariaV1LenderEnforcer.V1LenderDetails({
            matchIdentifier: false,
            details: LenderEnforcer.Details(loanCopy(loan))
        });
        loan.debt[0].identifier += 1;

        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
        details.matchIdentifier = true;

        vm.expectRevert(LenderEnforcer.InvalidLoanTerms.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1LenderEnforcerAdditionalTransfers() external {
        //test invalid additional transfer from lender
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
        AstariaV1LenderEnforcer.V1LenderDetails memory details =
            AstariaV1LenderEnforcer.V1LenderDetails({matchIdentifier: false, details: LenderEnforcer.Details(loan)});

        vm.expectRevert(LenderEnforcer.InvalidAdditionalTransfer.selector);
        lenderEnforcer.validate(additionalTransfers, loan, abi.encode(details));

        //test valid additional transfer from other party
        additionalTransfers[0].from = borrower.addr;
        lenderEnforcer.validate(additionalTransfers, loan, abi.encode(details));
    }

    function testV1LenderEnforcerDebtBundlesNotSupported() external {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        SpentItem[] memory debt = new SpentItem[](2);
        debt[0] = loan.debt[0];
        debt[1] = _getERC721SpentItem(TestERC721(loan.debt[0].token), loan.debt[0].identifier + 1);
        loan.debt = debt;

        AstariaV1LenderEnforcer.V1LenderDetails({matchIdentifier: false, details: LenderEnforcer.Details(loan)});

        vm.expectRevert(DebtBundlesNotSupported.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(LenderEnforcer.Details({loan: loan})));
    }
}
