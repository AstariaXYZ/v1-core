// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";

import {BaseRecall} from "v1-core/status/BaseRecall.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

library AstariaV1Lib {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    uint256 constant WAD = 18;
    uint256 constant MAX_DURATION = uint256(3 * 365 * 1 days); // 3 years

    error InterestAccrualRoundingMinimum();
    error UnsupportedDecimalValue();
    error RateExceedMaxRecallRate();

    function validateCompoundInterest(uint256 amount, uint256 rate, uint256 recallMax, uint256 decimals)
        internal
        pure
    {
        // rate should never exceed the recallMax rate
        if (rate > recallMax) {
            revert RateExceedMaxRecallRate();
        }

        // only decimal values of 1-18 are supported
        if (decimals > 18 || decimals == 0) {
            revert UnsupportedDecimalValue();
        }

        // check to validate that the MAX_DURATION does not overflow interest calculation
        // creates a maximum safe duration for a loan, loans can go beyond MAX_DURATION with undefined behavior
        calculateCompoundInterest(MAX_DURATION, amount, recallMax, decimals);

        // calculate interest for 1 second of time
        // loan must produce 1 wei of interest per 1 second of time
        uint256 interest = calculateCompoundInterest(1, amount, rate, decimals);
        if (interest == 0) {
            // interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }
    }

    function getBaseRecallRecallMax(bytes memory statusData) internal pure returns (uint256 recallMax) {
        assembly {
            recallMax := mload(add(0x80, statusData))
        }
    }

    function getBasePricingDecimals(bytes memory pricingData) internal pure returns (uint256 decimals) {
        assembly {
            decimals := mload(add(0x60, pricingData))
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

    function calculateCompoundInterest(uint256 delta_t, uint256 amount, uint256 rate, uint256 decimals)
        public
        pure
        returns (uint256)
    {
        if (decimals < WAD) {
            uint256 baseAdjustment = 10 ** (WAD - decimals);
            int256 exponent = int256((rate * baseAdjustment) / 365 days) * int256(delta_t);
            amount *= baseAdjustment;
            uint256 result = amount.mulWad(uint256(exponent.expWad())) - amount;
            return result /= baseAdjustment;
        }
        int256 exponent = int256(rate / 365 days) * int256(delta_t);
        return amount.mulWad(uint256(exponent.expWad())) - amount;
    }
}
