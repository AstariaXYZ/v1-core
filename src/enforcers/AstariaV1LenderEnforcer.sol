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

    error InterestAccrualRoundingMinimum();

    uint256 constant MAX_DURATION = uint256(3 * 365 * 1 days); // 3 years

    function validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        bytes calldata caveatData
    ) public view virtual override {
        BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));

        // check to validate that the MAX_DURATION does not overflow interest calculation
        // creates a maximum safe duration for a loan
        StarportLib.calculateCompoundInterest(MAX_DURATION, loan.debt[0].amount, pricingDetails.rate);

        // calculate interest for 1 second of time
        uint256 interest = StarportLib.calculateCompoundInterest(1, loan.debt[0].amount, pricingDetails.rate);
        if (interest == 0) {
            // interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }
        super.validate(additionalTransfers, loan, caveatData);
    }
}
