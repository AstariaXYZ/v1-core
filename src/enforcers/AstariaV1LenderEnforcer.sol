pragma solidity ^0.8.17;

import {LenderEnforcer} from "starport-core/enforcers/LenderEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

contract AstariaV1LenderEnforcer is LenderEnforcer {
    error LoanAmountExceedsCaveatAmount();
    error DebtBundlesNotSupported();

    function validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        bytes calldata caveatData
    ) public view virtual override {
        if (loan.debt.length > 1) {
            revert DebtBundlesNotSupported();
        }

        uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;
        uint256 loanAmount = loan.debt[0].amount;
        AstariaV1Lib.validateCompoundInterest(loanAmount, loanRate);

        LenderEnforcer.Details memory details = abi.decode(caveatData, (LenderEnforcer.Details));
        SpentItem memory caveatDebt = details.loan.debt[0];

        if (loanAmount > caveatDebt.amount) {
            //Debt amount is greater than the max amount or the caveatDebt amount
            revert LoanAmountExceedsCaveatAmount();
        }

        caveatDebt.amount = loanAmount;
        _validate(additionalTransfers, loan, details);
    }
}
