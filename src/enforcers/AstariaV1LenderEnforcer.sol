pragma solidity ^0.8.17;

import {LenderEnforcer} from "starport-core/enforcers/LenderEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";

contract AstariaV1LenderEnforcer is LenderEnforcer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    error LoanAmountExceedsMaxAmount();
    error LoanAmountExceedsMaxRate();
    error InterestAccrualRoundingMinimum();
    error DebtBundlesNotSupported();

    uint256 constant MAX_AMOUNT = 1e27; // 1_000_000_000 ether
    uint256 constant MAX_COMBINED_RATE_AND_DURATION = type(uint256).max / MAX_AMOUNT;
    uint256 constant MAX_DURATION = 3 * 365 days; // 3 years

    // int256(MAX_COMBINED_RATE_AND_DURATION).lnWad() / MAX_DURATION;
    // 780371100103 (IPR),  24.609783012848208000 (WAD), 2460.9783012848208000% (Percentage APY)
    uint256 constant MAX_RATE = uint256(int256(780371100103));

    function validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        bytes calldata caveatData
    ) public view virtual override {
        if (loan.debt.length > 1) {
            revert DebtBundlesNotSupported();
        }

        uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;
        if (loanRate > MAX_RATE) {
            //Loan rate is greater than the max rate
            revert LoanAmountExceedsMaxRate();
        }
        uint256 loanAmount = loan.debt[0].amount;
        if (StarportLib.calculateCompoundInterest(1 seconds, loanAmount, loanRate) == 0) {
            // Interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }

        LenderEnforcer.Details memory details = abi.decode(caveatData, (LenderEnforcer.Details));
        SpentItem memory caveatDebt = details.loan.debt[0];

        if (loanAmount > MAX_AMOUNT || loanAmount > caveatDebt.amount) {
            //Debt amount is greater than the max amount or the caveatDebt amount
            revert LoanAmountExceedsMaxAmount();
        }

        caveatDebt.amount = loanAmount;
        _validate(additionalTransfers, loan, details);
    }
}
