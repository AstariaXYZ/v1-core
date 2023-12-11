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

import "./AstariaV1Test.sol";

import {Starport} from "starport-core/Starport.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {AstariaV1BorrowerEnforcer} from "v1-core/enforcers/AstariaV1BorrowerEnforcer.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract TestV1BorrowerEnforcer is AstariaV1Test, AstariaV1BorrowerEnforcer {
    uint256 endRate = uint256(1e17) / uint256(365 days);

    function setUp() public override {
        super.setUp();
        borrowerEnforcer = new AstariaV1BorrowerEnforcer();
        defaultPricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate, decimals: 18}));
    }

    function testV1BorrowerEnforcerEnd() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loan)
        });
        vm.warp(block.timestamp + 10);
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        // Test after endTime
        vm.warp(block.timestamp + 15);
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1BorrowerEnforcerStart() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: endRate / 2, decimals: 18}));

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testRevertLocateCurrentRateAndAmount() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp + 10,
            endTime: block.timestamp,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loan)
        });

        // Revert if startTime > endTime
        vm.expectRevert(stdError.arithmeticError);
        _locateCurrentRate(details);

        details.endTime = block.timestamp + 20;

        //revert if startTime > current block
        vm.expectRevert(stdError.arithmeticError);
        _locateCurrentRate(details);
    }

    function testV1BorrowerEnforcerHalfway() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        uint256 rate = endRate / 2 + endRate / 4;
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: rate, decimals: 18}));

        vm.warp(block.timestamp + 5);

        uint256 actualRate = AstariaV1BorrowerEnforcer(address(borrowerEnforcer)).locateCurrentRate(abi.encode(details));
        assertEq(actualRate, rate, "actualRate != expectedRate");
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1BorrowerEnforcerAmountOOB() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount * 2,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });

        loan.debt[0].amount = details.minAmount - 1;

        vm.expectRevert(LoanAmountOutOfBounds.selector);
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));

        loan.debt[0].amount = details.maxAmount + 1;

        vm.expectRevert(LoanAmountOutOfBounds.selector);
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    // Test rate more than current
    function testV1BorrowerEnforcerRateGTCurrent() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.terms.pricingData =
            abi.encode(BasePricing.Details({carryRate: 0, rate: endRate * 3 / 4 + 1, decimals: 18}));

        vm.expectRevert(LoanRateExceedsCurrentRate.selector);
        vm.warp(block.timestamp + 5);

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1BorrowerEnforcerRateLTCurrent() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();

        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory details = AstariaV1BorrowerEnforcer.V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp + 10,
            startRate: endRate / 2,
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loanCopy(loan))
        });
        loan.terms.pricingData = abi.encode(BasePricing.Details({carryRate: 0, rate: details.startRate, decimals: 18}));

        vm.warp(block.timestamp + 5);

        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(details));
    }

    function testV1BorrowerEnforcerDebtBundlesNotSupported() external {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        SpentItem[] memory debt = new SpentItem[](2);
        debt[0] = loan.debt[0];
        debt[1] = _getERC721SpentItem(TestERC721(loan.debt[0].token), loan.debt[0].identifier + 1);
        loan.debt = debt;

        vm.expectRevert(DebtBundlesNotSupported.selector);
        borrowerEnforcer.validate(new AdditionalTransfer[](0), loan, abi.encode(BorrowerEnforcer.Details({loan: loan})));
    }

    // Test div by 0
    function testFuzzRateMethods(BasePricing.Details memory pricing, uint256 newRate) public {
        bytes memory pricingData = abi.encode(pricing);
        assertEq(AstariaV1Lib.getBasePricingRate(pricingData), pricing.rate);
        AstariaV1Lib.setBasePricingRate(pricingData, newRate);
        assertEq(newRate, abi.decode(pricingData, (BasePricing.Details)).rate);
    }
}
