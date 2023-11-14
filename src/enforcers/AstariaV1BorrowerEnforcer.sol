pragma solidity ^0.8.17;

import {BorrowerEnforcer} from "starport-core/enforcers/BorrowerEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

contract AstariaV1BorrowerEnforcer is BorrowerEnforcer {
    error LoanRateExceedsCurrentRate();
    error LoanAmountOutOfBounds();
    error DebtBundlesNotSupported();

    struct V1BorrowerDetails {
        uint256 startTime;
        uint256 endTime;
        uint256 startRate;
        uint256 maxAmount;
        uint256 minAmount;
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

        Starport.Terms calldata loanTerms = loan.terms;
        uint256 loanRate = abi.decode(loanTerms.pricingData, (BasePricing.Details)).rate;
        uint256 loanAmount = loan.debt[0].amount;

        //Validate the loan amount,rate, and recallMax
        AstariaV1Lib.validateCompoundInterest(
            loanAmount,
            loanRate,
            AstariaV1Lib.getBaseRecallRecallMax(loanTerms.statusData), //recallMax
            AstariaV1Lib.getBasePricingDecimals(loanTerms.pricingData) //decimals
        );

        V1BorrowerDetails memory v1Details = abi.decode(caveatData, (V1BorrowerDetails));

        if (loanAmount < v1Details.minAmount || loanAmount > v1Details.maxAmount) {
            //Debt amount is less than the current caveat amount
            revert LoanAmountOutOfBounds();
        }

        uint256 currentRate = _locateCurrentRate(v1Details);
        if (loanRate > currentRate) {
            //Loan rate is greater than the current caveat rate
            revert LoanRateExceedsCurrentRate();
        }

        //Update the caveat loan rate and amount
        Starport.Loan memory caveatLoan = v1Details.details.loan;
        AstariaV1Lib.setBasePricingRate(caveatLoan.terms.pricingData, loanRate);
        caveatLoan.debt[0].amount = loanAmount;

        //Hash match w/ expected issuer
        _validate(additionalTransfers, loan, v1Details.details);
    }

    function _locateCurrentRate(V1BorrowerDetails memory v1Details) internal view returns (uint256 currentRate) {
        uint256 endRate = AstariaV1Lib.getBasePricingRate(v1Details.details.loan.terms.pricingData);

        //if endRate == startRate, or startTime == endTime, or block.timestamp > endTime
        if (
            endRate == v1Details.startRate || v1Details.startTime == v1Details.endTime
                || block.timestamp > v1Details.endTime
        ) {
            return endRate;
        }

        //Will revert if startTime > endTime
        uint256 duration = v1Details.endTime - v1Details.startTime;
        uint256 elapsed;
        uint256 remaining;
        unchecked {
            //block.timestamp <= endTime && startTime < endTime, can't overflow
            elapsed = block.timestamp - v1Details.startTime;
            //block.timestamp <= endTime, can't underflow
            remaining = duration - elapsed;
        }

        //Calculate rate with a linear growth
        //Weight startRate by the remaining time, and endRate by the elapsed time
        uint256 totalBeforeDivision = (v1Details.startRate * remaining) + (endRate * elapsed);
        assembly {
            currentRate := div(totalBeforeDivision, duration)
        }
    }
}
