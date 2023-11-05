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
    error LoanRateInsufficient();
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

        BasePricing.Details memory caveatPricingDetails =
            abi.decode(details.loan.terms.pricingData, (BasePricing.Details));

        uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;

        if (loan.debt[0].amount > MAX_AMOUNT || loan.debt[0].amount > details.loan.debt[0].amount) {
            revert LoanAmountExceedsMaxAmount();
        }

        if (loanRate > MAX_RATE) {
            revert LoanAmountExceedsMaxRate();
        }

        if (loanRate < caveatPricingDetails.rate) {
            revert LoanRateInsufficient();
        }

        // calculate interest for 1 second of time
        uint256 interest = StarportLib.calculateCompoundInterest(1, loan.debt[0].amount, loanRate);
        if (interest == 0) {
            // interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }

        details.loan.debt[0].amount = loan.debt[0].amount;

        _validate(additionalTransfers, loan, details);
    }
}
