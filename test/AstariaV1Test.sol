pragma solidity ^0.8.17;

import "forge-std/console2.sol";

import "starport-test/StarportTest.sol";

import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {AstariaV1Pricing} from "src/pricing/AstariaV1Pricing.sol";

import {AstariaV1Status} from "src/status/AstariaV1Status.sol";

import {BaseRecall} from "src/status/BaseRecall.sol";

import {AstariaV1Settlement} from "src/settlement/AstariaV1Settlement.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {BorrowerEnforcer} from "starport-core/enforcers/BorrowerEnforcer.sol";
// import "forge-std/console2.sol";
import {CaveatEnforcer} from "starport-core/enforcers/CaveatEnforcer.sol";

contract AstariaV1Test is StarportTest {
    Account recaller;

    function setUp() public virtual override {
        super.setUp();

        recaller = makeAndAllocateAccount("recaller");

        // erc20s[1].mint(recaller.addr, 10000);

        pricing = new AstariaV1Pricing(SP);
        settlement = new AstariaV1Settlement(SP);
        status = new AstariaV1Status(SP);

        lenderEnforcer = new AstariaV1LenderEnforcer();

        vm.startPrank(recaller.addr);
        erc20s[0].approve(address(status), 1e18);
        vm.stopPrank();

        // // 1% interest rate per second
        defaultPricingData = abi.encode(
            BasePricing.Details({carryRate: (uint256(1e16) * 10), rate: (uint256(1e16) * 150) / (365 * 1 days)})
        );

        // defaultSettlementData = new bytes(0);

        defaultStatusData = abi.encode(
            BaseRecall.Details({
                honeymoon: 1 days,
                recallWindow: 3 days,
                recallStakeDuration: 30 days,
                // 1000% APR
                recallMax: (uint256(1e16) * 1000) / (365 * 1 days),
                // 10%, 0.1
                recallerRewardRatio: uint256(1e16) * 10
            })
        );
    }

    function getRefinanceDetails(Starport.Loan memory loan, bytes memory pricingData, address transactor)
        public
        view
        returns (LenderEnforcer.Details memory)
    {
        (SpentItem[] memory considerationPayment, SpentItem[] memory carryPayment,) =
            Pricing(loan.terms.pricing).getRefinanceConsideration(loan, pricingData, transactor);

        loan = SP.applyRefinanceConsiderationToLoan(loan, considerationPayment, carryPayment, pricingData);
        loan.issuer = transactor;
        loan.start = 0;
        loan.originator = address(0);

        return LenderEnforcer.Details({loan: loan});
    }
}