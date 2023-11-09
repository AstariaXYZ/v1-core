import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

library AstariaV1Lib {
    int256 constant NATURAL_NUMBER_SIGNED_WAD = int256(2718281828459045235);

    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    uint256 constant MAX_AMOUNT = 1e27; // 1_000_000_000 ether
    uint256 constant MAX_COMBINED_RATE_AND_DURATION = type(uint256).max / MAX_AMOUNT;
    uint256 constant MAX_DURATION = 3 * 365 days; // 3 years

    // int256(MAX_COMBINED_RATE_AND_DURATION).lnWad() / MAX_DURATION;
    // 780371100103 (IPR),  24.609783012848208000 (WAD), 2460.9783012848208000% (Percentage APY)
    uint256 constant MAX_RATE = uint256(int256(780371100103));

    error LoanAmountExceedsMaxAmount();
    error LoanRateExceedsMaxRate();
    error InterestAccrualRoundingMinimum();

    function calculateCompoundInterest(
        uint256 delta_t,
        uint256 amount,
        uint256 rate // expressed as SPR seconds per rate
    ) public pure returns (uint256) {
        return amount.mulWad(uint256(NATURAL_NUMBER_SIGNED_WAD.powWad(int256(rate * delta_t)))) - amount;
    }

    function validateCompoundInterest(
        uint256 amount,
        uint256 rate // expressed as SPR seconds per rate
    ) internal pure {
        if (rate > MAX_RATE) {
            //Loan rate is greater than the max rate
            revert LoanRateExceedsMaxRate();
        }

        if (calculateCompoundInterest(1 seconds, amount, rate) == 0) {
            // Interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }
        if (amount > MAX_AMOUNT) {
            //Debt amount is greater than the max amount
            revert LoanAmountExceedsMaxAmount();
        }
    }
}
