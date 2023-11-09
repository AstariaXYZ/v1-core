pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {AstariaV1BorrowerEnforcer} from "src/enforcers/AstariaV1BorrowerEnforcer.sol";

import "./AstariaV1Test.sol";

contract TestV1BorrowerEnforcer is AstariaV1Test, AstariaV1BorrowerEnforcer {
    uint256 endRate = uint256(1e17) / uint256(365 days);

    function setUp() public override {
        super.setUp();
        borrowerEnforcer = new AstariaV1BorrowerEnforcer();
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate}));
    }

    function testV1BorrowerEnforcerEnd() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10 minutes,
            startRate: endRate / 2,
            startAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loan)
        });
        vm.warp(block.timestamp + 10 minutes);

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        //Test after endTime
        vm.warp(block.timestamp + 10 minutes);
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1BorrowerEnforcerStart() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10 minutes,
            startRate: endRate / 2,
            startAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.debt[0].amount = loan.debt[0].amount * 2;
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate / 2}));

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testLocateCurrentDivBy0() public {
        assertEq(_locateCurrent(0, 1, 1, 1, 0), 0);
        assertEq(_locateCurrent(0, 1, 0, 0, 0), 0);
    }

    function testRevertLocateCurrentRateAndAmount() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp + 10 minutes,
            endTime: block.timestamp,
            startRate: endRate / 2,
            startAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loan)
        });

        //revert if startTime > endTime
        vm.expectRevert(stdError.arithmeticError);
        _locateCurrentRateAndAmount(details);

        details.endTime = block.timestamp + 20 minutes;

        //revert if startTime > current time
        vm.expectRevert(stdError.arithmeticError);
        _locateCurrentRateAndAmount(details);
    }

    function testV1BorrowerEnforcerHalfway() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10 minutes,
            startRate: endRate / 2,
            startAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.debt[0].amount = loan.debt[0].amount + loan.debt[0].amount / 2;
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate * 3 / 4}));

        vm.warp(block.timestamp + 5 minutes);

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }
    //test amount less than current

    function testV1BorrowerEnforcerAmountLTCurrent() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10 minutes,
            startRate: endRate / 2,
            startAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.debt[0].amount = loan.debt[0].amount + loan.debt[0].amount / 2 - 1;
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate * 3 / 4}));

        vm.warp(block.timestamp + 5 minutes);

        vm.expectRevert(LoanAmountLessThanCurrentAmount.selector);

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    //test rate more than current
    function testV1BorrowerEnforcerRateGTCurrent() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10 minutes,
            startRate: endRate / 2,
            startAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.debt[0].amount = loan.debt[0].amount + loan.debt[0].amount / 2;
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate * 3 / 4 + 1}));

        vm.expectRevert(LoanRateExceedsCurrentRate.selector);
        vm.warp(block.timestamp + 5 minutes);

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testYulUpdate() public {
        BorrowerEnforcer.Details memory details = BorrowerEnforcer.Details(generateDefaultLoanTerms());
        bytes memory pricingData = details.loan.terms.pricingData;
        BasePricing.Details memory pricing = abi.decode(pricingData, (BasePricing.Details));
        uint256 rate;
        uint offset;
        assembly {
            offset := sub(pricingData, details)
            rate := mload(add(0x20, pricingData))
        }
        assertEq(rate, pricing.rate);
    }
}
