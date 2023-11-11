pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";

import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";
import "./AstariaV1Test.sol";

contract TestCompoundInterest is AstariaV1Test {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    function testRateTooLowZero() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0, decimals: 18}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, "");
    }

    function testRateTooLowOne() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 1, decimals: 18}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = 1;
        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, "");
    }

    function testExceedMaxRate() public {
        uint256 MAX_RATE_PLUS_ONE = ((((uint256(type(int256).max.lnWad())) / AstariaV1Lib.MAX_DURATION)) + 1) * 365 days;

        defaultStatusData = abi.encode(
            BaseRecall.Details({
                honeymoon: 1 days,
                recallWindow: 3 days,
                recallStakeDuration: 30 days,
                recallMax: MAX_RATE_PLUS_ONE,
                // 10%, 0.1
                recallerRewardRatio: uint256(1e16) * 10
            })
        );

        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: MAX_RATE_PLUS_ONE, decimals: 18}));

        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = 2;

        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;
        vm.expectRevert();
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);

        vm.expectRevert();
        AstariaV1Lib.calculateCompoundInterest(AstariaV1Lib.MAX_DURATION, loan.debt[0].amount, MAX_RATE_PLUS_ONE, 18);
    }

    function testExceedMaxAmount() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0, decimals: 18}));

        BaseRecall.Details memory statusDetails = abi.decode(defaultStatusData, (BaseRecall.Details));
        int256 exponent = int256((statusDetails.recallMax / 365 days) * AstariaV1Lib.MAX_DURATION);

        uint256 MAX_AMOUNT_PLUS_ONE = type(uint256).max / uint256(exponent.expWad()) + 1;
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = MAX_AMOUNT_PLUS_ONE;

        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;
        vm.expectRevert();
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, caveatData);

        vm.expectRevert();
        AstariaV1Lib.calculateCompoundInterest(
            AstariaV1Lib.MAX_DURATION, MAX_AMOUNT_PLUS_ONE, statusDetails.recallMax, 18
        );
    }

    function testMaxRate() public {
        uint256 MAX_RATE = ((((uint256(type(int256).max.lnWad())) / AstariaV1Lib.MAX_DURATION))) * 365 days;

        defaultStatusData = abi.encode(
            BaseRecall.Details({
                honeymoon: 1 days,
                recallWindow: 3 days,
                recallStakeDuration: 30 days,
                // 1000% APR
                recallMax: MAX_RATE,
                // 10%, 0.1
                recallerRewardRatio: uint256(1e16) * 10
            })
        );
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: MAX_RATE, decimals: 18}));
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = 2;

        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, "");

        AstariaV1Lib.calculateCompoundInterest(AstariaV1Lib.MAX_DURATION, loan.debt[0].amount, MAX_RATE, 18);
    }

    function testMaxAmount() public {
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: 0, decimals: 18}));

        BaseRecall.Details memory statusDetails = abi.decode(defaultStatusData, (BaseRecall.Details));
        int256 exponent = int256((statusDetails.recallMax / 365 days) * AstariaV1Lib.MAX_DURATION);

        uint256 MAX_AMOUNT = type(uint256).max / uint256(exponent.expWad());
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.debt[0].amount = MAX_AMOUNT;
        bytes memory caveatData = _generateSignedCaveatLender(loan, lender, 0).caveat[0].data;

        vm.expectRevert(abi.encodeWithSelector(AstariaV1Lib.InterestAccrualRoundingMinimum.selector));
        lenderEnforcer.validate(new AdditionalTransfer[](0), loan, "");

        AstariaV1Lib.calculateCompoundInterest(AstariaV1Lib.MAX_DURATION, loan.debt[0].amount, 0, 18);
    }

    // function testPrecision() public {
    //   uint256 result = AstariaV1Lib.calculateCompoundInterest(uint256(MAX_DURATION), MAX_AMOUNT, uint256(MAX_RATE)) + MAX_AMOUNT;
    //   assertEq(result, MAX_UNSIGNED_INT, "Precision bounds not matching");
    // }
}
