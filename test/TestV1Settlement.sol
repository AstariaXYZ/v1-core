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

import {CaveatEnforcer} from "starport-core/enforcers/CaveatEnforcer.sol";
import {StarportLib, Actions} from "starport-core/lib/StarportLib.sol";

import {DeepEq} from "starport-test/utils/DeepEq.sol";
import {SpentItemLib} from "seaport-sol/src/lib/SpentItemLib.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {Validation} from "starport-core/lib/Validation.sol";

contract TestAstariaV1Settlement is AstariaV1Test, DeepEq {
    using Cast for *;
    using FixedPointMathLib for uint256;

    using {StarportLib.getId} for Starport.Loan;

    function testGetSettlementConsideration() public {
        BaseRecall.Details memory details = abi.decode(defaultStatusData, (BaseRecall.Details));
        defaultStatusData = abi.encode(
            BaseRecall.Details({
                recallWindow: details.recallWindow,
                honeymoon: details.honeymoon,
                recallMax: details.recallMax
            })
        );

        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        (ReceivedItem[] memory settlementConsideration, address authorized) =
            Settlement(loan.terms.settlement).getSettlementConsideration(loan);
        assertEq(settlementConsideration.length, 0, "Settlement consideration should be empty");
        assertEq(authorized, address(loan.issuer), "Authorized address should be loan.issuer");
    }

    function testV1SettlementHandlerValidate() public {
        Starport.Terms memory terms = Starport.Terms({
            status: address(status),
            settlement: address(settlement),
            pricing: address(pricing),
            pricingData: defaultPricingData,
            settlementData: defaultSettlementData,
            statusData: defaultStatusData
        });
        Starport.Loan memory loan =
            _createLoan721Collateral20Debt({lender: lender.addr, borrowAmount: 1e18, terms: terms});

        assertEq(AstariaV1Settlement(loan.terms.settlement).validate(loan), Validation.validate.selector);
    }

    function testV1SettlementValidateValid() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        assert(Validation(loan.terms.settlement).validate(loan) == Validation.validate.selector);
    }

    function testV1SettlementValidateInvalid() public {
        Starport.Loan memory loan = generateDefaultLoanTerms();
        loan.terms.settlementData = abi.encode(new bytes(1));
        assert(Validation(loan.terms.settlement).validate(loan) == bytes4(0xFFFFFFFF));
    }
}
