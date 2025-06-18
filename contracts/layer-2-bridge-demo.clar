(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_BRIDGE_PAUSED (err u103))
(define-constant ERR_INVALID_CHAIN (err u104))
(define-constant ERR_DEPOSIT_NOT_FOUND (err u105))
(define-constant ERR_ALREADY_WITHDRAWN (err u106))
(define-constant ERR_INVALID_SIGNATURE (err u107))

(define-data-var bridge-paused bool false)
(define-data-var bridge-fee uint u1000)
(define-data-var total-locked uint u0)
(define-data-var deposit-nonce uint u0)

(define-map user-balances principal uint)
(define-map locked-deposits 
  uint 
  {
    user: principal,
    amount: uint,
    target-chain: (string-ascii 20),
    target-address: (string-ascii 64),
    timestamp: uint,
    withdrawn: bool
  }
)

(define-map chain-validators 
  (string-ascii 20) 
  {
    validator: principal,
    active: bool
  }
)

(define-map withdrawal-proofs
  uint
  {
    deposit-id: uint,
    validator: principal,
    verified: bool
  }
)

(define-read-only (get-bridge-status)
  {
    paused: (var-get bridge-paused),
    fee: (var-get bridge-fee),
    total-locked: (var-get total-locked),
    current-nonce: (var-get deposit-nonce)
  }
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-deposit-info (deposit-id uint))
  (map-get? locked-deposits deposit-id)
)

;; (define-read-only (get-chain-validator (chain-id (string-ascii 20)))
;;   (map-get? chain-validators chain-id)
;; )

(define-read-only (get-withdrawal-proof (proof-id uint))
  (map-get? withdrawal-proofs proof-id)
)

(define-public (deposit-tokens (amount uint))
  (let (
    (sender tx-sender)
    (current-balance (get-user-balance sender))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)
    (asserts! (>= (stx-get-balance sender) amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set user-balances sender (+ current-balance amount))
    (var-set total-locked (+ (var-get total-locked) amount))
    
    (ok amount)
  )
)

(define-public (withdraw-tokens (amount uint))
  (let (
    (sender tx-sender)
    (current-balance (get-user-balance sender))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)
    
    (try! (as-contract (stx-transfer? amount tx-sender sender)))
    (map-set user-balances sender (- current-balance amount))
    (var-set total-locked (- (var-get total-locked) amount))
    
    (ok amount)
  )
)

(define-public (bridge-to-l2 (amount uint) (target-chain (string-ascii 20)) (target-address (string-ascii 64)))
  (let (
    (sender tx-sender)
    (current-balance (get-user-balance sender))
    (fee (var-get bridge-fee))
    (total-amount (+ amount fee))
    (current-nonce (var-get deposit-nonce))
    (new-nonce (+ current-nonce u1))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance total-amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)
    (asserts! (> (len target-chain) u0) ERR_INVALID_CHAIN)
    
    (map-set user-balances sender (- current-balance total-amount))
    (map-set locked-deposits new-nonce {
      user: sender,
      amount: amount,
      target-chain: target-chain,
      target-address: target-address,
      timestamp: stacks-block-height,
      withdrawn: false
    })
    (var-set deposit-nonce new-nonce)
    
    (ok new-nonce)
  )
)

(define-public (bridge-from-l2 (deposit-id uint) (original-user principal) (amount uint))
  (let (
    (deposit-info (unwrap! (map-get? locked-deposits deposit-id) ERR_DEPOSIT_NOT_FOUND))
    (current-balance (get-user-balance original-user))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get user deposit-info) original-user) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get amount deposit-info) amount) ERR_INVALID_AMOUNT)
    (asserts! (not (get withdrawn deposit-info)) ERR_ALREADY_WITHDRAWN)
    
    (map-set locked-deposits deposit-id (merge deposit-info { withdrawn: true }))
    (map-set user-balances original-user (+ current-balance amount))
    
    (ok deposit-id)
  )
)

;; (define-public (add-chain-validator (chain-id (string-ascii 20)) (validator principal))
;;   (begin
;;     (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
;;     (asserts! (> (len chain-id) 0) ERR_INVALID_CHAIN)
    
;;     (map-set chain-validators chain-id {
;;       validator: validator,
;;       active: true
;;     })
    
;;     (ok true)
;;   )
;; )

;; (define-public (remove-chain-validator (chain-id (string-ascii 20)))
;;   (begin
;;     (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
;;     (map-delete chain-validators chain-id)
    
;;     (ok true)
;;   )
;; )

(define-public (submit-withdrawal-proof (deposit-id uint) (validator principal))
  (let (
    (deposit-info (unwrap! (map-get? locked-deposits deposit-id) ERR_DEPOSIT_NOT_FOUND))
    (proof-id deposit-id)
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get withdrawn deposit-info)) ERR_ALREADY_WITHDRAWN)
    
    (map-set withdrawal-proofs proof-id {
      deposit-id: deposit-id,
      validator: validator,
      verified: true
    })
    
    (ok proof-id)
  )
)

(define-public (verify-and-release (deposit-id uint))
  (let (
    (deposit-info (unwrap! (map-get? locked-deposits deposit-id) ERR_DEPOSIT_NOT_FOUND))
    (proof-info (unwrap! (map-get? withdrawal-proofs deposit-id) ERR_INVALID_SIGNATURE))
    (user (get user deposit-info))
    (amount (get amount deposit-info))
    (current-balance (get-user-balance user))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get verified proof-info) ERR_INVALID_SIGNATURE)
    (asserts! (not (get withdrawn deposit-info)) ERR_ALREADY_WITHDRAWN)
    
    (map-set locked-deposits deposit-id (merge deposit-info { withdrawn: true }))
    (map-set user-balances user (+ current-balance amount))
    
    (ok amount)
  )
)

(define-public (set-bridge-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set bridge-fee new-fee)
    (ok new-fee)
  )
)

(define-public (pause-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set bridge-paused true)
    (ok true)
  )
)

(define-public (unpause-bridge)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set bridge-paused false)
    (ok true)
  )
)

(define-public (emergency-withdraw (user principal) (amount uint))
  (let (
    (current-balance (get-user-balance user))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender user)))
    (map-set user-balances user (- current-balance amount))
    (var-set total-locked (- (var-get total-locked) amount))
    
    (ok amount)
  )
)

(define-read-only (calculate-bridge-fee (amount uint))
  (let (
    (fee (var-get bridge-fee))
  )
    {
      amount: amount,
      fee: fee,
      total: (+ amount fee)
    }
  )
)

;; (define-private (filter-user-deposits (user principal) (start uint) (end uint))
;;   (if (<= start end)
;;     (let (
;;       (deposit-info (map-get? locked-deposits start))
;;     )
;;       (if (and (is-some deposit-info) (is-eq (get user (unwrap-panic deposit-info)) user))
;;         (append (list start) (filter-user-deposits user (+ start u1) end))
;;         (filter-user-deposits user (+ start u1) end)
;;       )
;;     )
;;     (list)
;;   )
;; )

;; (define-read-only (get-user-deposits (user principal))
;;   (let (
;;     (current-nonce (var-get deposit-nonce))
;;   )
;;     (filter-user-deposits user u1 current-nonce)
;;   )
;; )