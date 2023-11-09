pragma solidity ^0.8.17;

import {BorrowerEnforcer} from "starport-core/enforcers/BorrowerEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";
import {console} from "forge-std/console.sol";

contract AstariaV1BorrowerEnforcer is BorrowerEnforcer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    error LoanAmountLessThanCurrentAmount();
    error LoanAmountExceedsMaxAmount();
    error LoanRateExceedsCurrentRate();
    error LoanRateExceedsMaxRate();
    error InterestAccrualRoundingMinimum();
    error DebtBundlesNotSupported();

    struct V1BorrowerDetails {
        uint256 startTime;
        uint256 endTime;
        uint256 startRate;
        uint256 startAmount;
        BorrowerEnforcer.Details details;
    }

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
            revert LoanRateExceedsMaxRate();
        }

        uint256 loanAmount = loan.debt[0].amount;
        if (StarportLib.calculateCompoundInterest(1 seconds, loanAmount, loanRate) == 0) {
            // Interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }
        if (loanAmount > MAX_AMOUNT) {
            //Debt amount is greater than the max amount
            revert LoanAmountExceedsMaxAmount();
        }

        V1BorrowerDetails memory v1Details = abi.decode(caveatData, (V1BorrowerDetails));
        BorrowerEnforcer.Details memory details = v1Details.details;
        BasePricing.Details memory pricingData = abi.decode(details.loan.terms.pricingData, (BasePricing.Details));

        (uint256 currentRate, uint256 currentAmount) = _locateCurrentRateAndAmount(v1Details, pricingData);

        if (loanAmount < currentAmount) {
            //Debt amount is less than the current caveat amount
            revert LoanAmountLessThanCurrentAmount();
        }

        if (loanRate > currentRate) {
            //Loan rate is greater than the current caveat rate
            revert LoanRateExceedsCurrentRate();
        }

        if (loanRate < pricingData.rate) {
            //Loan rate is less than the current rate
            pricingData.rate = loanRate;
            details.loan.terms.pricingData = abi.encode(pricingData);
        }

        details.loan.debt[0].amount = loanAmount;
        _validate(additionalTransfers, loan, details);
    }

    function _locateCurrentRateAndAmount(V1BorrowerDetails memory v1Details, BasePricing.Details memory pricingData)
        internal
        view
        returns (uint256 currentRate, uint256 currentAmount)
    {
        //if past endTime, use the final rate and amount
        if (block.timestamp > v1Details.endTime) {
            return (pricingData.rate, v1Details.details.loan.debt[0].amount);
        }

        //will revert if startTime > endTime
        uint256 duration = v1Details.endTime - v1Details.startTime;
        uint256 elapsed;
        uint256 remaining;
        unchecked {
            //block.timestamp <= endTime && startTime <= endTime, can't overflow
            elapsed = block.timestamp - v1Details.startTime;
            //block.timestamp <= endTime, can't underflow
            remaining = duration - elapsed;
        }

        //calculate rate with a linear growth
        //weight startRate by the remaining time, and maxRate by the elapsed time
        currentRate = _locateCurrent(v1Details.startRate, pricingData.rate, remaining, elapsed, duration);

        //calculate amount with a linear decay
        //weight startAmount by the remaining time, and minAmount by the elapsed time
        currentAmount =
            _locateCurrent(v1Details.startAmount, v1Details.details.loan.debt[0].amount, remaining, elapsed, duration);
    }

    function _locateCurrent(uint256 a, uint256 b, uint256 wtA, uint256 wtB, uint256 totalWt)
        internal
        pure
        returns (uint256 current)
    {
        // Only modify if values are not equal.
        if (b != a) {
            // Aggregate new amounts weighted by time.
            uint256 totalBeforeDivision = (a * wtA) + (b * wtB);
            assembly {
                current := div(totalBeforeDivision, totalWt)
            }
            return current;
        }

        //minVal == maxVal,
        return a;
    }
}
