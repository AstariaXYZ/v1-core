pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

import "./AstariaV1Test.sol";

contract TestCompoundInterest is AstariaV1Test, AstariaV1LenderEnforcer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    function testRateMax() public {
        assertLt(AstariaV1Lib.MAX_RATE, uint256(type(int256).max));
        //        assertEq(MAX_RATE, uint256(int256(MAX_COMBINED_RATE_AND_DURATION).lnWad() / MAX_DURATION));

        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: uint256(AstariaV1Lib.MAX_RATE) + 1}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(AstariaV1Lib.LoanRateExceedsMaxRate.selector);
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testAmountMax() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = AstariaV1Lib.MAX_AMOUNT + 1;
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.LoanAmountExceedsMaxAmount.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testRateTooLowZero() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testRateTooLowOne() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 1}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    // function testPrecision() public {
    //   uint256 result = StarportLib.calculateCompoundInterest(uint256(MAX_DURATION), MAX_AMOUNT, uint256(MAX_RATE)) + MAX_AMOUNT;
    //   assertEq(result, MAX_UNSIGNED_INT, "Precision bounds not matching");
    // }
}
