SwiftEstate

===========

Real Estate Escrow and Title Transfer Smart Contract

----------------------------------------------------

SwiftEstate is a decentralized application (dApp) built on the Clarity smart contract language, designed to facilitate secure and transparent real estate transactions. It provides robust escrow services, enabling automated title verification and property transfer upon the fulfillment of predefined conditions. The system supports multi-party approvals, a comprehensive dispute resolution mechanism, and emergency cancellation features to ensure fair and reliable property dealings.

### Features

-   **Property Registration & Verification**: Allows property owners to register their assets with unique identifiers and `title-hash`. The contract owner can then verify these properties, marking them as legitimate for transactions.

-   **Multi-Party Escrow**: Establishes escrow agreements involving sellers, buyers, and optional agents and inspectors, ensuring all parties' approvals are recorded before transfer.

-   **Secure Fund Management**: Manages the secure deposit of funds into escrow, with automated release to the seller and fee distribution to the contract owner upon successful completion.

-   **Automated Title Transfer**: Automatically transfers property ownership on the blockchain once all conditions and approvals are met.

-   **Dispute Resolution System**: Provides a mechanism for any involved party to initiate a dispute, logging the reason and initiator for future resolution.

-   **Emergency Cancellation**: Allows for emergency cancellation of an escrow, especially if deadlines are missed or disputes escalate, with automatic refund of the deposit to the buyer.

-   **Contract Fees**: Implements a configurable contract fee system, directing a small percentage of the transaction value to the contract owner.

-   **Time-Bound Transactions**: Incorporates a `deadline` for each escrow, ensuring transactions proceed within a specified timeframe.

### How It Works

1\.  **Property Registration**: A property owner registers their property, providing details like `title-hash`, `value`, and `location`. The property is initially `unverified`.

2\.  **Property Verification**: The `CONTRACT_OWNER` verifies the registered property, making it eligible for escrow transactions.

3\.  **Escrow Creation**: A verified property's owner (seller) can initiate an escrow, specifying the buyer, optional agent and inspector, the `deposit` amount, and a `deadline` for the transaction.

4\.  **Funding Escrow**: The buyer funds the escrow by transferring the agreed `deposit` amount to the contract. The escrow status changes to `FUNDED`.

5\.  **Multi-Party Approvals**: All involved parties (seller, buyer, and any specified agent/inspector) must approve the transaction. Once all necessary approvals are received, the escrow status changes to `APPROVED`.

6\.  **Escrow Completion**: The `complete-escrow` function can be called by any party once the escrow is `APPROVED` and before the `deadline`. This triggers:

    -   Transfer of the `amount` (minus fees) to the seller.

    -   Transfer of the `contract-fee-rate` to the `CONTRACT_OWNER`.

    -   Transfer of property ownership on the blockchain to the buyer.

    -   The escrow status changes to `COMPLETED`.

7\.  **Dispute & Emergency Cancellation**:

    -   Any participant can `initiate-dispute-and-emergency-cancel` with a `reason`. This sets the escrow status to `STATUS_DISPUTED`.

    -   If `emergency-cancel` is set to `true` or the `deadline` has passed, the deposit is automatically refunded to the buyer, and the escrow is `CANCELLED`. The dispute is then marked as `resolved`.

### Contract Details

**Contract Address**: `CONTRACT_OWNER` (defined as `tx-sender` during contract deployment)

**Constants**:

-   `CONTRACT_OWNER`: The deployer of the contract, authorized for administrative actions.

-   Error codes (`ERR_UNAUTHORIZED`, `ERR_PROPERTY_NOT_FOUND`, etc.)

-   Escrow statuses (`STATUS_PENDING`, `STATUS_FUNDED`, `STATUS_APPROVED`, `STATUS_COMPLETED`, `STATUS_DISPUTED`, `STATUS_CANCELLED`).

**Data Maps**:

-   `properties`: Stores details of registered properties including `owner`, `title-hash`, `value`, `location`, `verified` status, and `active` status.

-   `escrows`: Contains comprehensive data for each escrow transaction, including `property-id`, `seller`, `buyer`, `agent`, `inspector`, `amount`, `deposit`, `deadline`, `status`, approval flags, and `created-at` block height.

-   `disputes`: Logs dispute records with `initiator`, `reason`, `created-at`, `resolved` status, and `resolution` details.

**Data Variables**:

-   `next-property-id`: Increments for unique property identifiers.

-   `next-escrow-id`: Increments for unique escrow identifiers.

-   `contract-fee-rate`: Defines the fee percentage (in basis points) charged by the contract (default: 2.5%).

**Functions**:

-   **Private Functions**:

    -   `(calculate-fee (amount uint))`: Calculates the fee based on the transaction amount and `contract-fee-rate`.

    -   `(all-approvals-received (escrow-data ...))`: Checks if all required parties have approved an escrow.

    -   `(is-escrow-participant (escrow-id uint) (caller principal))`: Verifies if a caller is an authorized participant in a given escrow.

-   **Public Functions**:

    -   `(register-property (title-hash (buff 32)) (value uint) (location (string-ascii 100)))`: Registers a new property.

    -   `(verify-property (property-id uint))`: Marks a property as verified (only callable by `CONTRACT_OWNER`).

    -   `(create-escrow (property-id uint) (buyer principal) (agent (optional principal)) (inspector (optional principal)) (deposit uint) (deadline uint))`: Initiates a new escrow transaction.

    -   `(fund-escrow (escrow-id uint))`: Allows the buyer to deposit funds into the escrow.

    -   `(approve-escrow (escrow-id uint))`: Allows any participant to approve an escrow.

    -   `(complete-escrow (escrow-id uint))`: Finalizes the escrow, transfers funds and property ownership.

    -   `(initiate-dispute-and-emergency-cancel (escrow-id uint) (reason (string-ascii 200)) (emergency-cancel bool))`: Initiates a dispute or performs an emergency cancellation.

### Error Handling

The contract utilizes a set of predefined error codes (`u100` to `u107`) to clearly indicate the reason for transaction failures, such as unauthorized access, missing records, insufficient funds, or invalid states.

### Deployment

To deploy this contract, you will need a Clarity development environment (e.g., Stacks.js, Clarinet, or a compatible IDE).

1\.  Save the contract code as a `.clar` file (e.g., `swift-estate.clar`).

2\.  Use `clarinet console` or your preferred deployment method to deploy the contract to a Stacks blockchain. The `CONTRACT_OWNER` will be the address that deploys the contract.

### Usage Example (Conceptual)

```

;; Assuming contract is deployed at `SP123...swift-estate`

;; 1. Register a property by the seller

(contract-call? 'SP123...swift-estate.swift-estate register-property 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef u100000000 "123 Main St, Anytown")

;; 2. Contract owner verifies the property

(contract-call? 'SP123...swift-estate.swift-estate verify-property u1)

;; 3. Seller creates an escrow for the property

(contract-call? 'SP123...swift-estate.swift-estate create-escrow u1 'SPXYZ...buyer-address (some 'SPABC...agent-address) none u5000000 u100000)

;; 4. Buyer funds the escrow

(contract-call? 'SP123...swift-estate.swift-estate fund-escrow u1)

;; 5. Seller, Buyer, and Agent approve the escrow

(contract-call? 'SP123...swift-estate.swift-estate approve-escrow u1) ;; Called by seller

(contract-call? 'SP123...swift-estate.swift-estate approve-escrow u1) ;; Called by buyer

(contract-call? 'SP123...swift-estate.swift-estate approve-escrow u1) ;; Called by agent

;; 6. Any party completes the escrow after approvals and before deadline

(contract-call? 'SP123...swift-estate.swift-estate complete-escrow u1)

```

### Contribution

Contributions are welcome! If you have suggestions for improvements, find bugs, or want to add new features, please feel free to:

1\.  Fork the repository.

2\.  Create a new branch (`git checkout -b feature/AmazingFeature`).

3\.  Make your changes and ensure they adhere to Clarity best practices.

4\.  Write comprehensive tests for new features or bug fixes.

5\.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).

6\.  Push to the branch (`git push origin feature/AmazingFeature`).

7\.  Open a Pull Request.

### License

This project is licensed under the MIT License - see the `LICENSE` file (if applicable) for details. For the purpose of this README, it is assumed to be MIT.

### Related Projects

-   [Clarity-Lang](https://docs.stacks.co/write-smart-contracts/clarity-language "null"): Official documentation for the Clarity smart contract language.

-   [Stacks Blockchain](https://www.stacks.co/ "null"): The blockchain on which Clarity contracts are deployed.

### Contact

For any questions or inquiries, please reach out to the contract owner or project maintainers.
