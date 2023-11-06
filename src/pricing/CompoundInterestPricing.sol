pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {BaseRecallPricing} from "./BaseRecallPricing.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

abstract contract CompoundInterestPricing is BaseRecallPricing {
    error LoanAmountExceedsMaxAmount();
    error LoanAmountExceedsMaxRate();
    error InterestAccrualRoundingMinimum();

    uint256 public constant MAX_AMOUNT = 1e27; // 1_000_000_000 ether
    uint256 public constant MAX_COMBINED_RATE_AND_DURATION = type(uint256).max / MAX_AMOUNT;
    uint256 public constant MAX_DURATION = 3 * 365 days; // 3 years

    // int256(MAX_COMBINED_RATE_AND_DURATION).lnWad() / MAX_DURATION;
    // 780371100103 (IPR),  24.609783012848208000 (WAD), 2460.9783012848208000% (Percentage APY)
    uint256 public constant MAX_RATE = uint256(int256(780371100103));

    function calculateInterest(
        uint256 delta_t,
        uint256 amount,
        uint256 rate // expressed as SPR seconds per rate
    ) public pure override returns (uint256) {
        // return (delta_t * rate).mulWad(amount);
        return StarportLib.calculateCompoundInterest(delta_t, amount, rate);
    }

    function validate(SpentItem[] memory debt, bytes calldata pricingData)
        public
        view
        virtual
        override
        returns (bytes8 selector)
    {
        uint256 loanRate = abi.decode(pricingData, (BasePricing.Details)).rate;
        if (loanRate > MAX_RATE) {
            //Loan rate is greater than the max rate
            revert LoanAmountExceedsMaxRate();
        }

        for (uint256 i = 0; i < debt.length;) {
            uint256 loanAmount = debt[i].amount;
            if (loanAmount > MAX_AMOUNT) {
                //Debt amount is greater than the max amount or the caveat amount
                revert LoanAmountExceedsMaxAmount();
            }

            if (StarportLib.calculateCompoundInterest(1 seconds, loanAmount, loanRate) == 0) {
                // Interest does not accrue at least 1 wei per second
                revert InterestAccrualRoundingMinimum();
            }

            unchecked {
                ++i;
            }
        }
        return BaseRecallPricing.validate.selector;
    }
}
