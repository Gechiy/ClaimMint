;; ClaimMint Token Marketplace Contract

;; Define SIP-010 Fungible Token trait
(define-trait vr-token-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Error Codes
(define-constant VR-ERR-UNAUTHORIZED (err u100))
(define-constant VR-ERR-DUPLICATE-REQUEST (err u101))
(define-constant VR-ERR-ACCESS-DENIED (err u102))
(define-constant VR-ERR-QUANTITY-ERROR (err u103))
(define-constant VR-ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant VR-ERR-PROGRAM-INACTIVE (err u105))
(define-constant VR-ERR-TOKEN-NOT-SET (err u106))
(define-constant VR-ERR-TOKEN-VERIFICATION-FAILED (err u107))
(define-constant VR-ERR-VALUE-OUT-OF_BOUNDS (err u108))
(define-constant VR-ERR-TIME-LIMIT-EXCEEDED (err u109))
(define-constant VR-ERR-INVALID-RECIPIENT (err u110))

;; Constants
(define-constant VR-DISTRIBUTION-CEILING u1000000000)
(define-constant VR-MINIMUM-REWARD u1)
(define-constant VR-DURATION-MAXIMUM u10000)
(define-constant VR-CONTRACT-OWNER (as-contract tx-sender))

;; Core State Variables
(define-data-var vr-controller principal tx-sender)
(define-data-var vr-program-supply uint u0)
(define-data-var vr-rewards-active bool true)
(define-data-var vr-expiration-height uint u0)
(define-data-var vr-individual-allocation uint u0)
(define-data-var vr-selected-token (optional principal) none)

;; Storage Maps
(define-map vr-beneficiary-registry principal uint)
(define-map vr-distribution-ledger principal uint)
(define-map vr-whitelist-registry principal bool)
(define-map vr-approved-tokens principal bool)

;; Internal Validation Functions
(define-private (vr-validate-amount (amount uint))
  (and (>= amount VR-MINIMUM-REWARD) (<= amount VR-DISTRIBUTION-CEILING))
)

(define-private (vr-validate-timeframe (blocks uint))
  (<= blocks VR-DURATION-MAXIMUM)
)

(define-private (vr-validate-participant (participant principal))
  (and (not (is-eq participant VR-CONTRACT-OWNER)) (not (is-eq participant (var-get vr-controller))))
)

(define-private (vr-token-is-approved (token-contract principal))
  (default-to false (map-get? vr-approved-tokens token-contract))
)

(define-private (vr-authenticate-token (token-instance <vr-token-trait>))
  (let ((token-address (contract-of token-instance)))
    (and 
      (vr-token-is-approved token-address)
      (match (contract-call? token-instance get-name)
        success true
        error false)
    )
  )
)

;; Read-only Query Functions
(define-read-only (vr-get-participant-rewards (participant principal))
  (default-to u0 (map-get? vr-distribution-ledger participant))
)

(define-read-only (vr-get-active-token)
  (var-get vr-selected-token)
)

(define-read-only (vr-is-eligible-participant (participant principal))
  (is-some (map-get? vr-beneficiary-registry participant))
)

(define-read-only (vr-get-program-controller)
  (var-get vr-controller)
)

(define-read-only (vr-check-whitelist-status (participant principal))
  (default-to false (map-get? vr-whitelist-registry participant))
)

(define-read-only (vr-get-program-details)
  (ok {
    total-supply: (var-get vr-program-supply),
    program-active: (var-get vr-rewards-active),
    expires-at: (var-get vr-expiration-height),
    reward-amount: (var-get vr-individual-allocation)
  })
)

;; Reward Eligibility Validation
(define-private (vr-can-claim-rewards (participant principal))
  (and 
    (vr-is-eligible-participant participant)
    (< (vr-get-participant-rewards participant) (default-to u0 (map-get? vr-beneficiary-registry participant)))
    (var-get vr-rewards-active)
    (<= stacks-block-height (var-get vr-expiration-height))
  )
)

;; Administrative Functions
(define-public (vr-register-token (token-contract <vr-token-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (match (contract-call? token-contract get-name)
                success true
                error false) VR-ERR-TOKEN-VERIFICATION-FAILED)
    (let ((contract-address (contract-of token-contract)))
      (map-set vr-approved-tokens contract-address true)
      (var-set vr-selected-token (some contract-address))
      (ok true)
    )
  )
)

(define-public (vr-initialize-program (total-tokens uint) (reward-per-claim uint) (program-duration uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (vr-validate-amount total-tokens) VR-ERR-VALUE-OUT-OF_BOUNDS)
    (asserts! (vr-validate-amount reward-per-claim) VR-ERR-VALUE-OUT-OF_BOUNDS)
    (asserts! (vr-validate-timeframe program-duration) VR-ERR-TIME-LIMIT-EXCEEDED)
    (asserts! (>= total-tokens reward-per-claim) VR-ERR-VALUE-OUT-OF_BOUNDS)
    (var-set vr-program-supply total-tokens)
    (var-set vr-individual-allocation reward-per-claim)
    (var-set vr-expiration-height (+ stacks-block-height program-duration))
    (var-set vr-rewards-active true)
    (ok true)
  )
)

(define-public (vr-grant-access (participant principal))
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (vr-validate-participant participant) VR-ERR-INVALID-RECIPIENT)
    (asserts! (not (vr-check-whitelist-status participant)) VR-ERR-DUPLICATE-REQUEST)
    (map-set vr-whitelist-registry participant true)
    (ok true)
  )
)

(define-public (vr-revoke-access (participant principal))
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (vr-validate-participant participant) VR-ERR-INVALID-RECIPIENT)
    (asserts! (vr-check-whitelist-status participant) VR-ERR-ACCESS-DENIED)
    (map-delete vr-whitelist-registry participant)
    (ok true)
  )
)

(define-public (vr-set-participant-quota (participant principal) (reward-limit uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (vr-validate-participant participant) VR-ERR-INVALID-RECIPIENT)
    (asserts! (vr-validate-amount reward-limit) VR-ERR-VALUE-OUT-OF_BOUNDS)
    (map-set vr-beneficiary-registry participant reward-limit)
    (ok true)
  )
)

;; Reward Claiming Interface
(define-public (vr-claim-rewards (reward-token <vr-token-trait>))
  (let (
    (recipient tx-sender)
    (maximum-rewards (default-to u0 (map-get? vr-beneficiary-registry recipient)))
    (claimed-so-far (vr-get-participant-rewards recipient))
    (active-token-address (unwrap! (var-get vr-selected-token) VR-ERR-TOKEN-NOT-SET))
  )
    (asserts! (vr-validate-participant recipient) VR-ERR-INVALID-RECIPIENT)
    (asserts! (vr-authenticate-token reward-token) VR-ERR-TOKEN-VERIFICATION-FAILED)
    (asserts! (is-eq active-token-address (contract-of reward-token)) VR-ERR-TOKEN-VERIFICATION-FAILED)
    (asserts! (vr-can-claim-rewards recipient) VR-ERR-ACCESS-DENIED)
    (asserts! (>= (- maximum-rewards claimed-so-far) (var-get vr-individual-allocation)) VR-ERR-INSUFFICIENT-BALANCE)

    (map-set vr-distribution-ledger recipient (+ claimed-so-far (var-get vr-individual-allocation)))

    (as-contract
      (contract-call? reward-token transfer
        (var-get vr-individual-allocation)
        tx-sender
        recipient
        none
      )
    )
  )
)

(define-public (vr-suspend-program)
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (var-set vr-rewards-active false)
    (ok true)
  )
)

;; Emergency Management Functions
(define-public (vr-update-expiration (new-end-height uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (vr-validate-timeframe (- new-end-height stacks-block-height)) VR-ERR-TIME-LIMIT-EXCEEDED)
    (var-set vr-expiration-height new-end-height)
    (ok true)
  )
)

(define-public (vr-withdraw-tokens (token-contract <vr-token-trait>) (withdrawal-amount uint))
  (let ((active-token-address (unwrap! (var-get vr-selected-token) VR-ERR-TOKEN-NOT-SET)))
    (asserts! (is-eq tx-sender (var-get vr-controller)) VR-ERR-UNAUTHORIZED)
    (asserts! (vr-validate-amount withdrawal-amount) VR-ERR-VALUE-OUT-OF_BOUNDS)
    (asserts! (vr-authenticate-token token-contract) VR-ERR-TOKEN-VERIFICATION-FAILED)
    (asserts! (is-eq (contract-of token-contract) active-token-address) VR-ERR-TOKEN-VERIFICATION-FAILED)
    (as-contract
      (contract-call? token-contract transfer
        withdrawal-amount
        tx-sender
        (var-get vr-controller)
        none
      )
    )
  )
)