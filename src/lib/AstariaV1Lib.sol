import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

library AstariaV1Lib {
    int256 constant NATURAL_NUMBER_SIGNED_WAD = int256(2718281828459045235);

    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    uint256 constant MAX_DURATION = uint256(3 * 365 * 1 days); // 3 years

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
        // check to validate that the MAX_DURATION does not overflow interest calculation
        // creates a maximum safe duration for a loan
        calculateCompoundInterest(MAX_DURATION, amount, rate);

        if (calculateCompoundInterest(1 seconds, amount, rate) == 0) {
            // Interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }
    }

    function getBasePricingRate(bytes memory pricingData) internal pure returns (uint256 rate) {
        assembly {
            rate := mload(add(0x20, pricingData))
        }
    }

    function setBasePricingRate(bytes memory pricingData, uint256 newRate) internal pure {
        assembly {
            mstore(add(0x20, pricingData), newRate)
        }
    }
}
