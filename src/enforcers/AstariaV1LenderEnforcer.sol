pragma solidity ^0.8.17;

import {LenderEnforcer} from "starport-core/enforcers/LenderEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";
import {BaseRecallPricing} from "src/pricing/BaseRecallPricing.sol";

contract AstariaV1LenderEnforcer is LenderEnforcer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    error LoanAmountExceedsCaveatAmount();
    error PricingValidationFailed();

    function validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        bytes calldata caveatData
    ) public view virtual override {
        LenderEnforcer.Details memory details = abi.decode(caveatData, (LenderEnforcer.Details));

        uint256 debtLength = loan.debt.length;
        for (uint256 i = 0; i < debtLength;) {
            uint256 loanAmount = loan.debt[i].amount;
            if (loanAmount > details.loan.debt[i].amount) {
                //Debt amount is greater than the max amount or the caveat amount
                revert LoanAmountExceedsCaveatAmount();
            }

            details.loan.debt[i].amount = loanAmount;
            unchecked {
                ++i;
            }
        }

        //Update to use BasePricing if we make validate a part of the interface
        if (
            BaseRecallPricing(loan.terms.pricing).validate(loan.debt, loan.terms.pricingData)
                != BaseRecallPricing.validate.selector
        ) {
            revert PricingValidationFailed();
        }

        _validate(additionalTransfers, loan, details);
    }
}
