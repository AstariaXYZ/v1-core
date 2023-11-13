pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

import "./AstariaV1Test.sol";
import "forge-std/console2.sol";

contract TestCompoundInterest is AstariaV1Test, AstariaV1LenderEnforcer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    function testRateTooLowOne() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 1}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;
        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testExceedMaxRate() public {
        uint256 MAX_RATE_PLUS_ONE = uint256(type(int256).max.lnWad() / int256(MAX_DURATION)) + 1;
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: MAX_RATE_PLUS_ONE}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = 2;

        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;
        vm.expectRevert();
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);

        vm.expectRevert();
        AstariaV1Lib.calculateCompoundInterest(MAX_DURATION, loan.debt[0].amount, MAX_RATE_PLUS_ONE);
    }

    function testExceedMaxAmount() public {
        uint256 MAX_AMOUNT_PLUS_ONE = (type(uint256).max / 1e18) + 1;
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0}));

        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = MAX_AMOUNT_PLUS_ONE;

        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;
        vm.expectRevert();
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);

        vm.expectRevert();
        AstariaV1Lib.calculateCompoundInterest(MAX_DURATION, MAX_AMOUNT_PLUS_ONE, 0);
    }

    function testMaxRate() public {
        uint256 MAX_RATE = uint256(type(int256).max.lnWad() / int256(MAX_DURATION));
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: MAX_RATE}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = 2;

        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;
        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);

        AstariaV1Lib.calculateCompoundInterest(MAX_DURATION, loan.debt[0].amount, MAX_RATE);
    }

    function testMaxAmount() public {
        uint256 MAX_AMOUNT = (type(uint256).max / 1e18);
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = MAX_AMOUNT;
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        AstariaV1Lib.calculateCompoundInterest(MAX_DURATION, loan.debt[0].amount, 0);

        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    // function testPrecision() public {
    //   uint256 result = AstariaV1Lib.calculateCompoundInterest(uint256(MAX_DURATION), MAX_AMOUNT, uint256(MAX_RATE)) + MAX_AMOUNT;
    //   assertEq(result, MAX_UNSIGNED_INT, "Precision bounds not matching");
    // }
}
