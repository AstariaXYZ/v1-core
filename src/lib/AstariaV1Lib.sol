//  SPDX-License-Identifier: BUSL-1.1
//   █████╗ ███████╗████████╗ █████╗ ██████╗ ██╗ █████╗     ██╗   ██╗ ██╗
//  ██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██║██╔══██╗    ██║   ██║███║
//  ███████║███████╗   ██║   ███████║██████╔╝██║███████║    ██║   ██║╚██║
//  ██╔══██║╚════██║   ██║   ██╔══██║██╔══██╗██║██╔══██║    ╚██╗ ██╔╝ ██║
//  ██║  ██║███████║   ██║   ██║  ██║██║  ██║██║██║  ██║     ╚████╔╝  ██║
//  ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝      ╚═══╝   ╚═╝
//
//  Astaria v1 Lending
//  Built on Starport https://github.com/astariaXYZ/starport
//  Designed with love by Astaria Labs, Inc

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";
import "forge-std/console2.sol";

import {BaseRecall} from "v1-core/status/BaseRecall.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

library AstariaV1Lib {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 constant WAD = 18;
    uint256 constant MAX_DURATION = uint256(3 * 365 days); // 3 years

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InterestAccrualRoundingMinimum();
    error UnsupportedDecimalValue();
    error RateExceedMaxRecallRate();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function calculateCompoundInterest(uint256 delta_t, uint256 amount, uint256 rate, uint256 decimals)
        internal
        pure
        returns (uint256)
    {
        if (decimals < WAD) {
            uint256 baseAdjustment = 10 ** (WAD - decimals);
            int256 exponent = int256((rate * baseAdjustment * delta_t) / 365 days);
            amount *= baseAdjustment;
            uint256 result = amount.mulWad(uint256(exponent.expWad())) - amount;
            return result /= baseAdjustment;
        }
        int256 exponent = int256((rate * delta_t) / 365 days);
        return amount.mulWad(uint256(exponent.expWad())) - amount;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function validateCompoundInterest(uint256 amount, uint256 rate, uint256 recallMax, uint256 decimals)
        internal
        pure
    {
        // Rate should never exceed the recallMax rate
        if (rate > recallMax) {
            revert RateExceedMaxRecallRate();
        }

        // Only decimal values of 1-18 are supported
        if (decimals > 18 || decimals == 0) {
            revert UnsupportedDecimalValue();
        }

        // Check to validate that the MAX_DURATION does not overflow interest calculation
        // Creates a maximum safe duration for a loan, loans can go beyond MAX_DURATION with undefined behavior
        calculateCompoundInterest(MAX_DURATION, amount, recallMax, decimals);

        // Calculate interest for 1 second of time
        // Loan must produce 1 wei of interest per 1 second of time
        if (calculateCompoundInterest(1, amount, rate, decimals) == 0) {
            // Interest does not accrue at least 1 wei per second
            revert InterestAccrualRoundingMinimum();
        }
    }

    function getBaseRecallMax(bytes memory statusData) internal pure returns (uint256 recallMax) {
        assembly ("memory-safe") {
            recallMax := mload(add(0x80, statusData))
        }
    }

    function getBasePricingDecimals(bytes memory pricingData) internal pure returns (uint256 decimals) {
        assembly ("memory-safe") {
            decimals := mload(add(0x60, pricingData))
        }
    }

    function getBasePricingRate(bytes memory pricingData) internal pure returns (uint256 rate) {
        assembly ("memory-safe") {
            rate := mload(add(0x20, pricingData))
        }
    }

    function setBasePricingRate(bytes memory pricingData, uint256 newRate) internal pure {
        assembly ("memory-safe") {
            mstore(add(0x20, pricingData), newRate)
        }
    }
}
