# Upgrades

## Motivation

- Contract logic being immutable has its disadvantages, it creates inconvenience when upgrading and bug fixes, the old
  version will persist on-chain
- Methodologies: understanding each method's trade-offs
    - Patterns
        - "Not really upgrading" / Parameterize method
            - Not changing logic
            - Cannot add new storage / logic
            - When writing contract, supply getter and setter functions to change certain behavior or parameter in the
              future
            - Pro / con
                - +: Simple, obvious
                - -: Not flexible, administration privileges(single admin centralizes the contract, to avoid, will also
                  need a governance contract)
            - Should it be allowed?
                - -: No matter what we do, we are "changing" the contract
                - -: Developing with upgradability in mind, will introduce complexity and security risks
        - Social migration method
            - Informing the community of the upgrade, telling people that the old one is now deprecated, use at ur own
              peril, and you should go to the new one
            - +: Not changing the contract in any way, the original logic stays the same
            - +: Easy to audit
            - -: New address
            - -: Painful data migration: like if it is a ERC20 token,
        - Proxies
            - +: UX friendly, users interact with proxy contract whose address will stay the same regardless of logic
              contract upgrades
            - -: Uses a lot of low-level interactions
                - E.G: `delegatecall`
                    - Identical to message call apart from the code at the target address being executed in the context
                      of the calling contract and `msg.sender` and `msg.value` do not change
                        - Doing contract B's logic in contract A: A calls B's `setValue(x)`, it gets stored in A
            - +: Proxy address stays the same, use `delegatecall` to point to different target contracts, `delegatecall`
              to the new contract
            - +: Storage stored in proxy contract, data is preserved, to add a new storage, add it in implementation
              contract and proxy will pick it up
            - Terminologies
                - `Implementation contract`
                    - All code of the protocol, upgrading -> launching a brand-new implementation contract
                - `Proxy contract`
                    - Points to which implementation is the "correct" one and routes the function calls with
                      `delegatecall`
                - `The user`
                    - Caller of the proxy contract
                - `The admin`
                    - User(or group) that can upgrade to new implementation contracts
            - Gotchas
                - Still introduce somewhat a centrality
                - Storage clashes
                    - When saving storage, is saving the SAME value to the SAME storage _location_ as contract B
                    - e.g:
                      Implementation logic old version:

                        ```solidity
                        uint256 slot0;

                        function setValue(uint256 param) {
                          slot0 = param;
                        }
                        ```

                        when getting `delegatecalled`, proxy contract stores `slot0` with `param`, but if new logic:

                        ```solidity
                        uint256 newStorage;
                        uint256 slot0; // Now actually at slot 1

                        function setValue(uint256 param) {
                          newStorage = param;
                        }
                        ```

                        in new code, we are still writing to slot 0 in storage, but we are updating different variable
                        with new value, but in proxy, the old value in slot 0 will be overwritten, so considering this, we
                        can only "append" new storage variables in new logic code

                - Function selector clashes
                    - As the name suggests, this occurs when two functions have the same selector(revision: 4 byte hash
                      of the function name and function signature), but it is unlikely that both functions are in logic,
                      this is a problem when logic function is clashing with a admin function in the proxy
                - The proxy methodologies are to address these problems

            - Patterns
                - Transparent Proxy Pattern
                    - Admins are only allowed to call admin functions, cannot call any function in the implementation
                      contract, while users can only call logic functions
                - Universal Upgradable Proxies
                    - Puts the upgrading logic in the implementation contract
                - Diamond pattern
                    - One contract implemented in several subcontracts(multi-implementation)
                    - Allows upgrading a specific aspect of a "contract"

## Proxies

- `Delegatecall`
    - Similar to `call`, with a sense of borrowing a function, example:

    ```solidity
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.26;

    // NOTE: Deploy this contract first
    contract B {
    // NOTE: storage layout must be the same as contract A
    uint256 public num;
    address public sender;
    uint256 public value;

        function setVars(uint256 _num) public payable {
            num = _num;
            sender = msg.sender;
            value = msg.value;
        }
    }

    contract A {
    uint256 public num;
    address public sender;
    uint256 public value;

        event DelegateResponse(bool success, bytes data);
        event CallResponse(bool success, bytes data);

        // Function using delegatecall
        function setVarsDelegateCall(address _contract, uint256 _num)
            public
            payable
        {
            // A's storage is set; B's storage is not modified.
            (bool success, bytes memory data) = _contract.delegatecall(
                abi.encodeWithSignature("setVars(uint256)", _num)
            );

            emit DelegateResponse(success, data);
        }

        // Function using call
        function setVarsCall(address _contract, uint256 _num) public payable {
            // B's storage is set; A's storage is not modified.
            (bool success, bytes memory data) = _contract.call{value: msg.value}(
                abi.encodeWithSignature("setVars(uint256)", _num)
            );

            emit CallResponse(success, data);
        }
    }
    ```

    When directly interacting with B's `setVars`, I set B's `num` to 1, when calling A's `setVarsCall` with B's addr and
    `2`, I am setting B's `num` to `2`, A's `num` is still `0`, this is what I have done before, when calling A's
    `setVarsDelegateCall` with `3`, B's `num` stays the same while A's `num` gets set to `3`, and this updating process is
    ignorant of the variable names of A, it only respects the storage slot, that is to say, in B, the func is updating
    `num` hence storage slot 0, so when getting delegate called, the proxy will also be updating the variable stored in
    slot 0, regardless of the written variable name in A
    - With this being said, even there is no variable at slot 0, the slot's value is still going to be updated
    - What if the types don't match?

        ```solidity
        bool public num;
        ```

        when called with `222`, txn DOES go through and the `num` is now `true`, when passing `0`, `num` will be `false`
        - What happened is that the `bool` slot is actually set to the value of `222`, but when solidity reads the
          value, it does not see `0x0...0`, so it thinks that this value means `num` is `true`

### Proxy sub-lesson

- `Yul`
    - Intermediate language that can be compiled to bytecode for different backends, allowing writing low-level codes
      close to opcodes
    - `:=` is to set value in assembly
- Openzeppelin's `Proxy.sol`
    - `_delegate`
        - Mainly, it goes and does the delegate call
    - There are `fallback` and `receive` functions, when receiving calls that it does not recognize, calls `fallback`,
      `fallback` calls `_delegate`
        - Proxy receiving data for a function that it does not recognize(not a function within itself), it sends to the
          implementation with
          `delegatecall`
        - Function clashing
            - If the implementation has a function with signature like `setImplementation`(the exact same as the proxy),
              then in the proxy, the fallback will not be triggered and hence the function in implementation will not be
              called
    - Should not have any storage in proxy contract so we don't screw things up, but then how to store data?
        - `EIP-1967`: Standard Proxy Storage Slots
            - Specifying specific storage slots for proxies
            - Logic contract address
                - Storage slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` (obtained as
                  `bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)`) holds the address of the
                  implementation
                  contract
            - Admin address
                - Storage slot `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103` (obtained as
                  `bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)`) holds the address that is allowed to upgrade
                  the logic contract address
    - Reading storage
        - If only considering user interaction
            - Reading values like implementation address and admin address, use `sload([the slot])`, cuz the slot is
              fixed by standard
            - Reading normal states, the evm compiles down to the same logic as the implementation contract: mapping
              variable name to slot then value:
                - Public variables' invisible getter behaves the same, the explicit getters defined by creator still
                  returns the "intended" value
                - This is why no matter what, upgrading a contract should never "insert" state variables in the original
                  layout, as it will surely and devastatingly corrupt the data stored on proxy, so when upgrading,
                  suppress the urge to manage code readability, always append state variable, as this is the
                  **_PRICE YOU
                  PAY_** for upgrading
                    - There can be "workarounds":
                        - declare variable like: `uint256[50]` between groups of variables to preserve 50 slots for
                          future
                          use, but I haven't seen implementations, so it's not verified for me
                        - Struct grouping
                            - Manage the storage manually, declare a slot for storage, store a struct variable to store
                              values, also not verified

### Transparent Upgradable Proxy contract

- Ways to deploy transparent proxy
    1. Build the proxy contract myself and deploy
    2. Hardhat proxy(when back in hardhat-deploy) or [
       `Upgradable Contracts`](https://hardhat.org/ignition/docs/guides/upgradeable-proxies) in ignition
    3. Openzeppelin plugins
- Ignition code breakdown
    - `TransparentUpgradeableProxy`
        - `ProxyAdminOwner` will not be able to interact with the proxy, but is able to upgrade it
        - Deploy `TransparentUpgradeableProxy` with `ProxyAdminOwner` as owner(in dev scenario, using hardhat
          signers[0])
            - Upon deploying `TransparentUpgradeableProxy`, it will create a new `ProxyAdmin` contract within its
              constructor, and capture `AdminChanged` event, the `newAdmin` param is the address of this `ProxyAdmin`
              contract
        - Finally, use the things above to get the contract for later interaction
    - Create `Box` module
        - First use `useModule` to get proxy contract, ensuring this happens after proxy deployment
        - Use `Box` abi for the contract at `proxy`, allowing to interact with `Box` through proxy
    - Upgrading
        - Get `ProxyAdmin` contract from `boxModule`
        - Deploy V2
        - Encode the function call with `encodeFunctionCall` to V2
        - Call `upgradeAndCall` from `ProxyAdmin` with:
            1. Proxy contract
            2. V2 contract
            3. encoded data
    - Reason for this approach
