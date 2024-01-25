//  SPDX-License-Identifier: Apache-2.0
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

import "test/AstariaV1Test.sol";

import {Starport} from "starport-core/Starport.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract TestCompoundInterest is AstariaV1Test {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    function testRateTooLowZero() public {
        vm.expectRevert(AstariaV1Lib.RateTooLow.selector);
        AstariaV1Lib.validateCompoundInterest(1e18, 0, 10e18, 18);
    }

    function testDecimalsTooHigh() public {
        vm.expectRevert(AstariaV1Lib.UnsupportedDecimalValue.selector);
        AstariaV1Lib.validateCompoundInterest(1e18, 1, 10e18, 19);
    }

    function testRateExceedsMaxRecallRate() public {
        vm.expectRevert(AstariaV1Lib.RateExceedMaxRecallRate.selector);
        AstariaV1Lib.validateCompoundInterest(1e18, 10e18 + 1, 10e18, 18);
    }

    function testMaxAmountDecimals() public {
        uint256 i = 1;

        for (; i < AstariaV1Lib.WAD + 1;) {
            maxAmountDecimals(i);

            unchecked {
                ++i;
            }
        }
    }

    function maxAmountDecimals(uint256 decimals) internal {
        uint256 MAX_RATE = 10 ** (decimals + 1);
        uint256 baseAdjustment = (10 ** (AstariaV1Lib.WAD - decimals));

        int256 exponent = int256(((MAX_RATE * baseAdjustment * AstariaV1Lib.MAX_DURATION) / 365 days));

        uint256 MAX_AMOUNT = (type(uint256).max / (uint256(exponent.expWad()) * baseAdjustment));

        uint256 result =
            AstariaV1Lib.calculateCompoundInterest(AstariaV1Lib.MAX_DURATION, MAX_AMOUNT, MAX_RATE, decimals);

        vm.expectRevert(FixedPointMathLib.MulWadFailed.selector);
        AstariaV1Lib.calculateCompoundInterest(AstariaV1Lib.MAX_DURATION, MAX_AMOUNT + 1, MAX_RATE, decimals);
    }

    function testInterestAccrual() public {
        uint256 i = 1;

        for (; i < AstariaV1Lib.WAD + 1;) {
            interestAccrual(i);

            unchecked {
                ++i;
            }
        }
    }

    function interestAccrual(uint256 decimals) public {
        uint256 INTEREST = 1_718_281_828_459_045_235 / (10 ** (AstariaV1Lib.WAD - decimals));
        uint256 AMOUNT = 10 ** decimals; // 1 in the provided decimal base
        uint256 RATE = 10 ** decimals; // 100% in the provided decimal base

        uint256 result = AstariaV1Lib.calculateCompoundInterest(365 days, AMOUNT, RATE, decimals);
        assertEq(result, INTEREST, "Interest accrual calculation incorrect");
    }
}
