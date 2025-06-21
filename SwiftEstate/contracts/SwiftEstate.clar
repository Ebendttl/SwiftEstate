;; Real Estate Escrow and Title Transfer Contract
;; A decentralized system for secure property transactions with escrow services,
;; Title verification, and automated transfer upon meeting all conditions.
;; Supports multi-party approval, dispute resolution, and emergency mechanisms.

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPERTY_NOT_FOUND (err u101))
(define-constant ERR_ESCROW_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_ALREADY_APPROVED (err u105))
(define-constant ERR_DISPUTE_ACTIVE (err u106))
(define-constant ERR_DEADLINE_PASSED (err u107))

;; Escrow status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_FUNDED u1)
(define-constant STATUS_APPROVED u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_DISPUTED u4)
(define-constant STATUS_CANCELLED u5)

;; Data Maps and Variables

;; Property registry with ownership and details
(define-map properties
  { property-id: uint }
  {
    owner: principal,
    title-hash: (buff 32),
    value: uint,
    location: (string-ascii 100),
    verified: bool,
    active: bool
  }
)

;; Escrow transactions with all parties and conditions
(define-map escrows
  { escrow-id: uint }
  {
    property-id: uint,
    seller: principal,
    buyer: principal,
    agent: (optional principal),
    inspector: (optional principal),
    amount: uint,
    deposit: uint,
    deadline: uint,
    status: uint,
    seller-approved: bool,
    buyer-approved: bool,
    agent-approved: bool,
    inspector-approved: bool,
    created-at: uint
  }
)

;; Dispute records for conflict resolution
(define-map disputes
  { escrow-id: uint }
  {
    initiator: principal,
    reason: (string-ascii 200),
    created-at: uint,
    resolved: bool,
    resolution: (optional (string-ascii 200))
  }
)

;; Contract state variables
(define-data-var next-property-id uint u1)
(define-data-var next-escrow-id uint u1)
(define-data-var contract-fee-rate uint u250) ;; 2.5% in basis points

;; Private Functions

;; Calculate contract fees based on transaction amount
(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get contract-fee-rate)) u10000)
)

;; Verify if all required approvals are obtained
(define-private (all-approvals-received (escrow-data (tuple (property-id uint) (seller principal) (buyer principal) (agent (optional principal)) (inspector (optional principal)) (amount uint) (deposit uint) (deadline uint) (status uint) (seller-approved bool) (buyer-approved bool) (agent-approved bool) (inspector-approved bool) (created-at uint))))
  (and
    (get seller-approved escrow-data)
    (get buyer-approved escrow-data)
    (or (is-none (get agent escrow-data)) (get agent-approved escrow-data))
    (or (is-none (get inspector escrow-data)) (get inspector-approved escrow-data))
  )
)

;; Check if caller is authorized for escrow operations
(define-private (is-escrow-participant (escrow-id uint) (caller principal))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data
    (or
      (is-eq caller (get seller escrow-data))
      (is-eq caller (get buyer escrow-data))
      (match (get agent escrow-data)
        agent (is-eq caller agent)
        false
      )
      (match (get inspector escrow-data)
        inspector (is-eq caller inspector)
        false
      )
    )
    false
  )
)

;; Public Functions

;; Register a new property in the system
(define-public (register-property (title-hash (buff 32)) (value uint) (location (string-ascii 100)))
  (let ((property-id (var-get next-property-id)))
    (map-set properties
      { property-id: property-id }
      {
        owner: tx-sender,
        title-hash: title-hash,
        value: value,
        location: location,
        verified: false,
        active: true
      }
    )
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

;; Verify property title (only contract owner can verify)
(define-public (verify-property (property-id uint))
  (if (is-eq tx-sender CONTRACT_OWNER)
    (match (map-get? properties { property-id: property-id })
      property-data
      (begin
        (map-set properties
          { property-id: property-id }
          (merge property-data { verified: true })
        )
        (ok true)
      )
      ERR_PROPERTY_NOT_FOUND
    )
    ERR_UNAUTHORIZED
  )
)

;; Create new escrow transaction
(define-public (create-escrow (property-id uint) (buyer principal) (agent (optional principal)) (inspector (optional principal)) (deposit uint) (deadline uint))
  (match (map-get? properties { property-id: property-id })
    property-data
    (if (and (get verified property-data) (is-eq tx-sender (get owner property-data)))
      (let ((escrow-id (var-get next-escrow-id)))
        (map-set escrows
          { escrow-id: escrow-id }
          {
            property-id: property-id,
            seller: tx-sender,
            buyer: buyer,
            agent: agent,
            inspector: inspector,
            amount: (get value property-data),
            deposit: deposit,
            deadline: deadline,
            status: STATUS_PENDING,
            seller-approved: false,
            buyer-approved: false,
            agent-approved: false,
            inspector-approved: false,
            created-at: block-height
          }
        )
        (var-set next-escrow-id (+ escrow-id u1))
        (ok escrow-id)
      )
      ERR_UNAUTHORIZED
    )
    ERR_PROPERTY_NOT_FOUND
  )
)

;; Fund escrow with deposit (buyer function)
(define-public (fund-escrow (escrow-id uint))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data
    (if (and (is-eq tx-sender (get buyer escrow-data)) (is-eq (get status escrow-data) STATUS_PENDING))
      (let ((deposit-amount (get deposit escrow-data)))
        (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
        (map-set escrows
          { escrow-id: escrow-id }
          (merge escrow-data { status: STATUS_FUNDED })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_ESCROW_NOT_FOUND
  )
)

;; Approve escrow transaction (for all parties)
(define-public (approve-escrow (escrow-id uint))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data
    (if (and (is-escrow-participant escrow-id tx-sender) (is-eq (get status escrow-data) STATUS_FUNDED))
      (let (
        (updated-escrow
          (if (is-eq tx-sender (get seller escrow-data))
            (merge escrow-data { seller-approved: true })
            (if (is-eq tx-sender (get buyer escrow-data))
              (merge escrow-data { buyer-approved: true })
              (match (get agent escrow-data)
                agent (if (is-eq tx-sender agent)
                  (merge escrow-data { agent-approved: true })
                  (match (get inspector escrow-data)
                    inspector (if (is-eq tx-sender inspector)
                      (merge escrow-data { inspector-approved: true })
                      escrow-data
                    )
                    escrow-data
                  )
                )
                (match (get inspector escrow-data)
                  inspector (if (is-eq tx-sender inspector)
                    (merge escrow-data { inspector-approved: true })
                    escrow-data
                  )
                  escrow-data
                )
              )
            )
          )
        )
      )
        (map-set escrows { escrow-id: escrow-id } updated-escrow)
        (if (all-approvals-received updated-escrow)
          (begin
            (map-set escrows { escrow-id: escrow-id } (merge updated-escrow { status: STATUS_APPROVED }))
            (ok "All approvals received - ready for completion")
          )
          (ok "Approval recorded")
        )
      )
      ERR_UNAUTHORIZED
    )
    ERR_ESCROW_NOT_FOUND
  )
)

;; Complete escrow and transfer property ownership
(define-public (complete-escrow (escrow-id uint))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data
    (if (and (is-eq (get status escrow-data) STATUS_APPROVED) (< block-height (get deadline escrow-data)))
      (let (
        (property-id (get property-id escrow-data))
        (seller (get seller escrow-data))
        (buyer (get buyer escrow-data))
        (total-amount (get amount escrow-data))
        (fee (calculate-fee total-amount))
        (seller-payment (- total-amount fee))
      )
        ;; Transfer remaining funds to seller
        (try! (as-contract (stx-transfer? seller-payment tx-sender seller)))
        ;; Transfer fee to contract owner
        (try! (as-contract (stx-transfer? fee tx-sender CONTRACT_OWNER)))
        ;; Transfer property ownership
        (match (map-get? properties { property-id: property-id })
          property-data
          (map-set properties
            { property-id: property-id }
            (merge property-data { owner: buyer })
          )
          false
        )
        ;; Update escrow status
        (map-set escrows
          { escrow-id: escrow-id }
          (merge escrow-data { status: STATUS_COMPLETED })
        )
        (ok "Escrow completed successfully")
      )
      ERR_INVALID_STATUS
    )
    ERR_ESCROW_NOT_FOUND
  )
)

;; Advanced dispute resolution and emergency cancellation system
;; Allows parties to initiate disputes and provides emergency cancellation
;; with automatic refund mechanisms and detailed logging
(define-public (initiate-dispute-and-emergency-cancel (escrow-id uint) (reason (string-ascii 200)) (emergency-cancel bool))
  (match (map-get? escrows { escrow-id: escrow-id })
    escrow-data
    (if (is-escrow-participant escrow-id tx-sender)
      (let (
        (current-status (get status escrow-data))
        (deposit-amount (get deposit escrow-data))
        (buyer (get buyer escrow-data))
        (seller (get seller escrow-data))
        (deadline-passed (>= block-height (get deadline escrow-data)))
      )
        ;; Record dispute first
        (map-set disputes
          { escrow-id: escrow-id }
          {
            initiator: tx-sender,
            reason: reason,
            created-at: block-height,
            resolved: false,
            resolution: none
          }
        )
        
        ;; Handle emergency cancellation logic
        (if (or emergency-cancel deadline-passed (is-eq current-status STATUS_DISPUTED))
          (begin
            ;; Emergency cancellation - refund deposit to buyer
            (if (> deposit-amount u0)
              (try! (as-contract (stx-transfer? deposit-amount tx-sender buyer)))
              true
            )
            
            ;; Update escrow status to cancelled
            (map-set escrows
              { escrow-id: escrow-id }
              (merge escrow-data { status: STATUS_CANCELLED })
            )
            
            ;; Mark dispute as resolved with emergency cancellation
            (map-set disputes
              { escrow-id: escrow-id }
              {
                initiator: tx-sender,
                reason: reason,
                created-at: block-height,
                resolved: true,
                resolution: (some "Emergency cancellation executed - funds refunded")
              }
            )
            (ok "Emergency cancellation completed - dispute resolved and funds refunded")
          )
          (begin
            ;; Regular dispute - just mark escrow as disputed
            (map-set escrows
              { escrow-id: escrow-id }
              (merge escrow-data { status: STATUS_DISPUTED })
            )
            (ok "Dispute initiated - escrow marked for resolution")
          )
        )
      )
      ERR_UNAUTHORIZED
    )
    ERR_ESCROW_NOT_FOUND
  )
)


