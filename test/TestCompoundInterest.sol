pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {CompoundInterestPricing} from "src/pricing/CompoundInterestPricing.sol";

import "./AstariaV1Test.sol";

contract TestCompoundInterestImpl is CompoundInterestPricing {
    constructor(Starport SP_) Pricing(SP_) {}
}

contract TestCompoundInterest is AstariaV1Test {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    TestCompoundInterestImpl compoundInterest;

    function setUp() public override {
        super.setUp();
        compoundInterest = new TestCompoundInterestImpl(SP);
    }

    function testRateMax() public {
        assertLt(uint256(compoundInterest.MAX_RATE()), uint256(type(int256).max));
        assertEq(
            compoundInterest.MAX_RATE(),
            uint256(
                int256(compoundInterest.MAX_COMBINED_RATE_AND_DURATION()).lnWad()
                    / int256(compoundInterest.MAX_DURATION())
            )
        );

        defaultPricingData =
            abi.encode(BasePricing.Details({carryRate: 0, rate: uint256(compoundInterest.MAX_RATE()) + 1}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(CompoundInterestPricing.LoanAmountExceedsMaxRate.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testAmountMax() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = compoundInterest.MAX_AMOUNT() + 1;
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(CompoundInterestPricing.LoanAmountExceedsMaxAmount.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testRateTooLowZero() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(CompoundInterestPricing.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    function testRateTooLowOne() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 1}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(CompoundInterestPricing.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);
    }

    // function testPrecision() public {
    //   uint256 result = StarportLib.calculateCompoundInterest(uint256(compoundInterest.MAX_DURATION), compoundInterest.MAX_AMOUNT, uint256(compoundInterest.MAX_RATE)) + compoundInterest.MAX_AMOUNT;
    //   assertEq(result, compoundInterest.MAX_UNSIGNED_INT, "Precision bounds not matching");
    // }
}
