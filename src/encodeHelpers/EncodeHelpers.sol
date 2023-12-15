pragma solidity ^0.8.0;

import {Starport} from "starport-core/Starport.sol";
contract EncodeHelpers {
    function encodeLoan(Starport.Loan memory loan) public pure returns (Starport.Loan memory) {
        return loan;
    }
}
