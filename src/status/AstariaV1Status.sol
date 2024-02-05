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

import {Starport} from "starport-core/Starport.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";
import {Validation} from "starport-core/lib/Validation.sol";
import {BasePricing} from "v1-core/pricing/BasePricing.sol";
import {BaseRecall} from "v1-core/status/BaseRecall.sol";
import {BaseStatus} from "v1-core/status/BaseStatus.sol";

contract AstariaV1Status is BaseStatus, BaseRecall {
    using {StarportLib.getId} for Starport.Loan;

    error InvalidPricingContract();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(Starport SP_, address owner_) BaseRecall(SP_, owner_) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // @inheritdoc Status
    function isActive(Starport.Loan calldata loan, bytes calldata) external view override returns (bool) {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        uint256 loanId = loan.getId();
        uint64 start = recalls[loanId].start;
        return !(start > 0 && start + details.recallWindow < block.timestamp);
    }

    // @inheritdoc BaseStatus
    function isRecalled(Starport.Loan calldata loan) external view override returns (bool) {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        uint256 loanId = loan.getId();
        uint64 start = recalls[loanId].start;
        return (start + details.recallWindow > block.timestamp) && start != 0;
    }

    // @inheritdoc Validation
    function validate(Starport.Loan calldata loan) external view override returns (bytes4) {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        BasePricing.Details memory pDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
        bool valid = true;
        if (details.recallMax > 10 * 10 ** pDetails.decimals || details.recallMax == 0 || details.recallWindow == 0) {
            valid = false;
        }

        return valid ? Validation.validate.selector : bytes4(0xFFFFFFFF);
    }
}
