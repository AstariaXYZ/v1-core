pragma solidity ^0.8.17;

import {LenderEnforcer} from "starport-core/enforcers/LenderEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";

contract AstariaV1LenderEnforcer is LenderEnforcer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    error LoanAmountExceedsMaxAmount();
    error LoanAmountExceedsMaxRate();
    error InterestAccrualRoundingMinimum();

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
        LenderEnforcer.Details memory details = abi.decode(caveatData, (LenderEnforcer.Details));

        uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;
        if (loanRate > MAX_RATE) {
            //Loan rate is greater than the max rate
            revert LoanAmountExceedsMaxRate();
        }

        uint256 debtLength = loan.debt.length;
        for (uint256 i = 0; i < debtLength;) {
            uint256 loanAmount = loan.debt[i].amount;
            if (loanAmount > MAX_AMOUNT || loanAmount > details.loan.debt[i].amount) {
                //Debt amount is greater than the max amount or the caveat amount
                revert LoanAmountExceedsMaxAmount();
            }

            if (StarportLib.calculateCompoundInterest(1 seconds, loanAmount, loanRate) == 0) {
                // Interest does not accrue at least 1 wei per second
                revert InterestAccrualRoundingMinimum();
            }

            details.loan.debt[i].amount = loanAmount;
            unchecked {
                ++i;
            }
        }

        ////NOTE: Bundles will not be supported by this check
        //uint256 loanAmount = loan.debt[0].amount;
        //if (loanAmount > MAX_AMOUNT || loanAmount > details.loan.debt[0].amount) {
        //    //Debt amount is greater than the max amount or the caveat amount
        //    revert LoanAmountExceedsMaxAmount();
        //}

        //BasePricing.Details memory caveatPricingDetails =
        //    abi.decode(details.loan.terms.pricingData, (BasePricing.Details));

        ////revert if the loan rate is less than the caveat rate
        //        if (loanRate < caveatPricingDetails.rate) {
        //            revert LoanRateInsufficient();
        //        }
        //
        ////update the caveat pricing details if the loan rate is higher
        //if (loanRate > caveatPricingDetails.rate) {
        //    caveatPricingDetails.rate = loanRate;
        //    details.loan.terms.pricingData = abi.encode(caveatPricingDetails);
        //}

        //if (StarportLib.calculateCompoundInterest(1 seconds, loanAmount, loanRate) == 0) {
        //    // Interest does not accrue at least 1 wei per second
        //    revert InterestAccrualRoundingMinimum();
        //}

        ////Update the caveat amount to the loan amount
        //details.loan.debt[0].amount = loanAmount;

        _validate(additionalTransfers, loan, details);
    }
}
