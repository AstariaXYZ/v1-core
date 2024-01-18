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
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {BaseRecall} from "v1-core/status/BaseRecall.sol";
import {BaseStatus} from "v1-core/status/BaseStatus.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract AstariaV1Status is BaseStatus, BaseRecall, Ownable {
    using {StarportLib.getId} for Starport.Loan;

    mapping(address => bool) public isValidPricing;

    error InvalidPricingContract();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(Starport SP_) BaseRecall(SP_) {
        _initializeOwner(msg.sender);
    }

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
        if (
            details.recallerRewardRatio > 10 ** pDetails.decimals || details.recallMax > 10 * 10 ** pDetails.decimals
                || !isValidPricing[loan.terms.pricing] || details.recallMax == 0
        ) {
            valid = false;
        }

        return valid ? Validation.validate.selector : bytes4(0xFFFFFFFF);
    }

    // @inheritdoc BaseRecall
    function validatePricingContract(address pricingContract) internal virtual override {
        if (!isValidPricing[pricingContract]) {
            revert InvalidPricingContract();
        }
    }

    function setValidPricing(address pricing, bool valid) external onlyOwner {
        isValidPricing[pricing] = valid;
    }
}
