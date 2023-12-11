pragma solidity ^0.8.17;

import "starport-test/utils/FuzzStructs.sol" as Fuzz;

import {
    TestFuzzStarport,
    SpentItem,
    ItemType,
    CaveatEnforcer,
    StarportTest,
    DutchAuctionSettlement,
    BasePricing,
    AdditionalTransfer,
    LenderEnforcer,
    Pricing
} from "starport-test/fuzz-testing/TestFuzzStarport.sol";
import {Starport} from "starport-core/Starport.sol";
import {
    AstariaV1Status,
    AstariaV1Pricing,
    AstariaV1Settlement,
    AstariaV1Test,
    BaseRecall,
    AstariaV1LenderEnforcer
} from "test/AstariaV1Test.sol";
import {Validation} from "starport-core/lib/Validation.sol";
import "forge-std/console.sol";

contract TestFuzzV1 is AstariaV1Test, TestFuzzStarport {
    V1LoanBounds dataBounds;

    function setUp() public virtual override (AstariaV1Test, TestFuzzStarport) {
        super.setUp();
    }

    struct FuzzV1 {
        FuzzLoan origination;
    }

    struct V1LoanBounds {
        bytes pricingBoundData;
        bytes statusBoundData;
        bytes settlementBoundData;
    }

    function boundBadLoan(
        Fuzz.SpentItem[10] memory collateral,
        Fuzz.SpentItem[10] memory debt,
        address[3] memory badAddresses
    ) public virtual override returns (Starport.Loan memory loan) {
        uint256 length = _boundMin(0, collateral.length);
        loan.terms = boundFuzzLenderTerms(abi.encode(dataBounds));
        uint256 i = 0;
        SpentItem[] memory ret = new SpentItem[](length);

        for (; i < length; i++) {
            ret[i] = _boundSpentItem(collateral[i]);
        }
        loan.collateral = ret;
        length = _boundMin(0, debt.length);
        i = 0;

        ret = new SpentItem[](length);
        for (; i < length; i++) {
            ret[i] = _boundSpentItem(debt[i]);
        }
        loan.debt = ret;
        loan.borrower = _toAddress(_boundMin(_toUint(badAddresses[0]), 100));
        loan.custodian = _toAddress(_boundMin(_toUint(badAddresses[1]), 100));
        loan.issuer = _toAddress(_boundMin(_toUint(badAddresses[2]), 100));
        return loan;
    }

    function boundStatusData(bytes memory boundStatusData)
        internal
        view
        virtual
        override
        returns (bytes memory statusData)
    {
        //        BaseRecall.Details memory boundDetails =
        //                            AstariaV1Status.Details({loanDuration: _boundMax(1 hours, 1095 days)});
        //        statusData = abi.encode(boundDetails);
        return boundStatusData;
    }

    function boundSettlementData(bytes memory boundSettlementData)
        internal
        view
        virtual
        override
        returns (bytes memory settlementData)
    {
        return boundSettlementData;
    }

    function boundPricingData(bytes memory boundPricingData)
        internal
        view
        virtual
        override
        returns (bytes memory pricingData)
    {
        return boundPricingData;
    }

    function boundFuzzLenderTerms(bytes memory loanBoundsData)
        internal
        view
        override
        returns (Starport.Terms memory terms)
    {
        V1LoanBounds memory loanBounds = abi.decode(loanBoundsData, (V1LoanBounds));
        terms.status = address(status);
        terms.settlement = address(settlement);
        terms.pricing = address(pricing);
        terms.pricingData = boundPricingData(loanBounds.pricingBoundData);
        terms.statusData = boundStatusData(loanBounds.statusBoundData);
        terms.settlementData = boundSettlementData(loanBounds.settlementBoundData);
    }

    function boundFuzzLoan(FuzzLoan memory params, bytes memory loanBoundsData)
        internal
        virtual
        override
        returns (Starport.Loan memory loan)
    {
        uint256 length = _boundMax(1, 4);
        loan.terms = boundFuzzLenderTerms(loanBoundsData);
        uint256 i = 0;
        if (length > params.collateral.length) {
            length = params.collateral.length;
        }
        SpentItem[] memory ret = new SpentItem[](length);

        for (; i < length; i++) {
            ret[i] = _boundSpentItem(params.collateral[i]);
        }
        loan.collateral = ret;
        SpentItem[] memory debt = new SpentItem[](1);
        debt[0] = SpentItem({
            itemType: ItemType.ERC20,
            identifier: 0,
            amount: _boundMax(params.debtAmount, type(uint112).max),
            token: address(erc20s[1])
        });
        BasePricing.Details memory pDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
        while (true) {
            try AstariaV1Pricing(loan.terms.pricing).calculateInterest(
                1, debt[0].amount, pDetails.rate, pDetails.decimals
            ) returns (uint256 interest) {
                break;
            } catch {
                debt[0].amount += 100 ** pDetails.decimals;
                continue;
            }
        }
        loan.debt = debt;
        loan.borrower = borrower.addr;
        loan.custodian = SP.defaultCustodian();
        loan.issuer = lender.addr;
        return loan;
    }

    function _skipToRepayment(Starport.Loan memory goodLoan) internal virtual override {
        skip(_boundMax(1, uint256(3 * 365 days)));
    }

    function willArithmeticOverflow(Starport.Loan memory loan) internal view virtual override returns (bool valid) {
        vm.assume(AstariaV1Pricing(loan.terms.pricing).validate(loan) == Validation.validate.selector);
        try Pricing(loan.terms.pricing).getPaymentConsideration(loan) returns (
            SpentItem[] memory repayConsideration, SpentItem[] memory carryConsideration
        ) {
            unchecked {
                uint256 newSupply = erc20s[0].totalSupply() + repayConsideration[0].amount;
                if (newSupply < erc20s[0].totalSupply() || newSupply < repayConsideration[0].amount) {
                    return true;
                }
            }
            return false;
        } catch {
            return true;
        }
    }

    function _skipToSettlement(Starport.Loan memory goodLoan) internal virtual override {
        BasePricing.Details memory pricingDetails = abi.decode(goodLoan.terms.pricingData, (BasePricing.Details));
        BaseRecall.Details memory details = abi.decode(goodLoan.terms.statusData, (BaseRecall.Details));
        uint256 baseAdjustment = (10 ** pricingDetails.decimals);
        uint256 proportion = baseAdjustment;
        uint256 delta_t = details.honeymoon + 1;
        skip(delta_t);
        SpentItem memory debtItem = goodLoan.debt[0];
        uint256 stake = BasePricing(goodLoan.terms.pricing).calculateInterest(
            delta_t, debtItem.amount, pricingDetails.rate, pricingDetails.decimals
        );
        uint256 mintNeeded = (stake * proportion) / baseAdjustment;
        vm.startPrank(recaller.addr);
        erc20s[1].approve(address(goodLoan.terms.status), type(uint256).max);
        erc20s[1].mint(address(recaller.addr), mintNeeded);

        BaseRecall(goodLoan.terms.status).recall(goodLoan);
        vm.stopPrank();
        DutchAuctionSettlement.Details memory settlementDetails =
            abi.decode(goodLoan.terms.settlementData, (DutchAuctionSettlement.Details));

        skip(_bound(0, details.recallWindow + 1, details.recallWindow + 1 + settlementDetails.window - 1));
    }

    function _skipToRefinance(Starport.Loan memory goodLoan) internal virtual {
        BasePricing.Details memory pricingDetails = abi.decode(goodLoan.terms.pricingData, (BasePricing.Details));
        BaseRecall.Details memory details = abi.decode(goodLoan.terms.statusData, (BaseRecall.Details));
        uint256 baseAdjustment = (10 ** pricingDetails.decimals);
        uint256 proportion = baseAdjustment;
        uint256 delta_t = details.honeymoon + 1;
        skip(delta_t);
        SpentItem memory debtItem = goodLoan.debt[0];
        uint256 stake = BasePricing(goodLoan.terms.pricing).calculateInterest(
            delta_t, debtItem.amount, pricingDetails.rate, pricingDetails.decimals
        );
        uint256 mintNeeded = (stake * proportion) / baseAdjustment;
        vm.startPrank(recaller.addr);
        erc20s[1].approve(address(goodLoan.terms.status), type(uint256).max);
        erc20s[1].mint(address(recaller.addr), mintNeeded);

        BaseRecall(goodLoan.terms.status).recall(goodLoan);
        vm.stopPrank();

        skip(_bound(0, details.recallWindow / 2, details.recallWindow - 1));
        console.log("skipped inside recall");
    }

    function _generateGoodLoan(FuzzLoan memory params) internal virtual override returns (Starport.Loan memory) {
        params.debtAmount = _boundMin(params.debtAmount, 1e16);
        uint256 rate = _boundMax(1e16, 5e16);
        dataBounds.pricingBoundData =
            abi.encode(BasePricing.Details({rate: rate, carryRate: _boundMax(0, 1e18), decimals: 18}));
        dataBounds.statusBoundData = abi.encode(
            BaseRecall.Details({
                honeymoon: _boundMax(1 days, 365 days),
                recallWindow: _boundMax(1 days, 365 days),
                recallStakeDuration: _boundMax(1 days, 365 days),
                recallMax: _bound(0, rate, 10e18),
                recallerRewardRatio: _boundMax(0, 1e18)
            })
        );
        dataBounds.settlementBoundData = abi.encode(
            DutchAuctionSettlement.Details({
                startingPrice: _boundMax(1, 1e18),
                endingPrice: _boundMax(1, 1e18),
                window: _boundMax(1 days, 365 days)
            })
        );
        return fuzzNewLoanOrigination(params, abi.encode(dataBounds));
    }

    function _generateSignedCaveatLender(
        Starport.Loan memory loan,
        Account memory signer,
        bytes32 salt,
        bool invalidate
    ) public view virtual override (AstariaV1Test, StarportTest) returns (CaveatEnforcer.SignedCaveats memory) {
        return super._generateSignedCaveatLender(loan, signer, salt, invalidate);
    }

    function _generateSignedCaveatBorrower(Starport.Loan memory loan, Account memory signer, bytes32 salt)
        public
        view
        virtual
        override (AstariaV1Test, StarportTest)
        returns (CaveatEnforcer.SignedCaveats memory)
    {
        return super._generateSignedCaveatBorrower(loan, signer, salt);
    }

    function _generateRefinanceCaveat(
        Account memory account,
        Starport.Loan memory goodLoan,
        SpentItem[] memory considerationPayment,
        SpentItem[] memory carryPayment,
        bytes memory pricingData
    ) internal virtual returns (CaveatEnforcer.SignedCaveats memory signedCaveats) {
        Starport.Loan memory refiLoan = loanCopy(goodLoan);
        refiLoan.terms.pricingData = pricingData;
        refiLoan.debt = SP.applyRefinanceConsiderationToLoan(considerationPayment, carryPayment);
        LenderEnforcer.Details memory details = LenderEnforcer.Details({loan: refiLoan});

        AstariaV1LenderEnforcer.V1LenderDetails memory lenderDetails =
            AstariaV1LenderEnforcer.V1LenderDetails({matchIdentifier: true, details: details});

        bytes32 salt = bytes32(msg.sig);
        details.loan.issuer = account.addr;
        details.loan.originator = address(0);
        details.loan.start = 0;
        signedCaveats.caveats = new CaveatEnforcer.Caveat[](1);
        signedCaveats.salt = salt;
        signedCaveats.singleUse = true;
        signedCaveats.deadline = block.timestamp + 1 days;
        signedCaveats.caveats[0] =
            CaveatEnforcer.Caveat({enforcer: address(lenderEnforcer), data: abi.encode(lenderDetails)});
        bytes32 hash = SP.hashCaveatWithSaltAndNonce(
            account.addr, signedCaveats.singleUse, salt, signedCaveats.deadline, signedCaveats.caveats
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(account.key, hash);
        signedCaveats.signature = abi.encodePacked(r, s, v);
    }

    function testFuzzRefinance(FuzzRefinanceLoan memory params) public virtual override {
        Starport.Loan memory goodLoan = _generateGoodLoan(params.origination);
        skip(1);
        _skipToRefinance(goodLoan);

        uint256 newRate = BaseRecall(goodLoan.terms.status).getRecallRate(goodLoan);

        BasePricing.Details memory newPricingDetails =
            BasePricing.Details({rate: newRate, carryRate: _boundMax(0, uint256((1e16 * 100))), decimals: 18});
        Account memory account = makeAndAllocateAccount(params.refiKey);

        address refiFulfiller;
        (
            SpentItem[] memory considerationPayment,
            SpentItem[] memory carryPayment,
            AdditionalTransfer[] memory additionalTransfers
        ) = Pricing(goodLoan.terms.pricing).getRefinanceConsideration(
            goodLoan, abi.encode(newPricingDetails), refiFulfiller
        );
        if (params.origination.fulfillerType % 2 == 0) {
            refiFulfiller = goodLoan.borrower;
        } else if (params.origination.fulfillerType % 3 == 0) {
            refiFulfiller = account.addr;
        } else {
            refiFulfiller = _toAddress(_boundMin(params.skipTime, 100));
        }
        Starport.Loan memory goodLoan2 = goodLoan;
        {
            CaveatEnforcer.SignedCaveats memory lenderCaveat = refiFulfiller != account.addr
                ? _generateRefinanceCaveat(
                    account, goodLoan2, considerationPayment, carryPayment, abi.encode(newPricingDetails)
                )
                : _emptyCaveat();
            vm.prank(address(account.addr));
            erc20s[1].approve(address(SP), type(uint256).max);
            assertEq(address(goodLoan2.debt[0].token), address(erc20s[1]), "not equal");
            vm.startPrank(refiFulfiller);
            erc20s[1].mint(address(refiFulfiller), additionalTransfers[0].amount);
            erc20s[1].approve(address(SP), type(uint256).max);
            SP.refinance(account.addr, lenderCaveat, goodLoan2, abi.encode(newPricingDetails), "");
            vm.stopPrank();
        }
    }
}
