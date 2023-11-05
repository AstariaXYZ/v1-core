pragma solidity ^0.8.17;

import {BorrowerEnforcer} from "starport-core/enforcers/BorrowerEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

contract AstariaV1BorrowerEnforcer is BorrowerEnforcer {
    error LoanAmountLessThanCurrentAmount();
    error LoanRateExceedsCurrentRate();
    error DebtBundlesNotSupported();

    struct V1BorrowerDetails {
        uint256 startTime;
        uint256 endTime;
        uint256 startRate;
        uint256 startAmount;
        BorrowerEnforcer.Details details;
    }

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

        V1BorrowerDetails memory v1Details = abi.decode(caveatData, (V1BorrowerDetails));

        (uint256 currentRate, uint256 currentAmount) = _locateCurrentRateAndAmount(v1Details);

        if (loanAmount < currentAmount) {
            //Debt amount is less than the current caveat amount
            revert LoanAmountLessThanCurrentAmount();
        }

        if (loanRate > currentRate) {
            //Loan rate is greater than the current caveat rate
            revert LoanRateExceedsCurrentRate();
        }

        BorrowerEnforcer.Details memory details = v1Details.details;
        AstariaV1Lib.setBasePricingRate(details.loan.terms.pricingData, loanRate);
        details.loan.debt[0].amount = loanAmount;
        _validate(additionalTransfers, loan, details);
    }

    function _locateCurrentRateAndAmount(V1BorrowerDetails memory v1Details)
        internal
        view
        returns (uint256 currentRate, uint256 currentAmount)
    {
        //if past endTime, use the final rate and amount
        if (block.timestamp > v1Details.endTime || v1Details.startTime == v1Details.endTime) {
            return (
                AstariaV1Lib.getBasePricingRate(v1Details.details.loan.terms.pricingData),
                v1Details.details.loan.debt[0].amount
            );
        }

        //will revert if startTime > endTime
        uint256 duration = v1Details.endTime - v1Details.startTime;
        uint256 elapsed;
        uint256 remaining;
        unchecked {
            //block.timestamp <= endTime && startTime < endTime, can't overflow
            elapsed = block.timestamp - v1Details.startTime;
            //block.timestamp <= endTime, can't underflow
            remaining = duration - elapsed;
        }

        //calculate rate with a linear growth
        //weight startRate by the remaining time, and maxRate by the elapsed time
        currentRate = _locateCurrent(
            v1Details.startRate,
            AstariaV1Lib.getBasePricingRate(v1Details.details.loan.terms.pricingData),
            remaining,
            elapsed,
            duration
        );

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
