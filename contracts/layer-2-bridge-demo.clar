(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_BRIDGE_PAUSED (err u103))
(define-constant ERR_INVALID_CHAIN (err u104))
(define-constant ERR_DEPOSIT_NOT_FOUND (err u105))
(define-constant ERR_ALREADY_WITHDRAWN (err u106))
(define-constant ERR_INVALID_SIGNATURE (err u107))
(define-constant ERR_TRANSACTION_LIMIT_EXCEEDED (err u108))
(define-constant ERR_WITHDRAWAL_LOCKED (err u109))
(define-constant ERR_INVALID_TIMELOCK_PERIOD (err u110))
(define-constant ERR_NO_REBATE_AVAILABLE (err u111))
(define-constant ERR_INVALID_TIER (err u112))

(define-data-var bridge-paused bool false)
(define-data-var bridge-fee uint u1000)
(define-data-var total-locked uint u0)
(define-data-var deposit-nonce uint u0)
(define-data-var transaction-counter uint u0)
(define-data-var withdrawal-timelock-period uint u144)
(define-data-var emergency-timelock-period uint u1008)
(define-data-var total-volume-processed uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var bridge-launch-height uint u0)
(define-data-var rebate-pool uint u0)
(define-data-var rebate-tier-1-threshold uint u1000000)
(define-data-var rebate-tier-2-threshold uint u5000000)
(define-data-var rebate-tier-3-threshold uint u10000000)

(define-map user-balances principal uint)
(define-map transaction-history
  uint
  {
    user: principal,
    tx-type: (string-ascii 20),
    amount: uint,
    timestamp: uint,
    target-chain: (optional (string-ascii 20)),
    target-address: (optional (string-ascii 64)),
    deposit-id: (optional uint),
    status: (string-ascii 20)
  }
)
(define-map user-transaction-lists principal (list 100 uint))
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

(define-map timelock-withdrawals
  uint
  {
    user: principal,
    amount: uint,
    unlock-height: uint,
    withdrawn: bool,
    emergency-override: bool
  }
)

(define-map user-timelock-nonces principal uint)
(define-map daily-volume-tracking uint uint)
(define-map chain-volume-stats (string-ascii 20) uint)
(define-map user-lifetime-volume principal uint)
(define-map user-rebate-balance principal uint)

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

(define-read-only (get-timelock-withdrawal (timelock-id uint))
  (map-get? timelock-withdrawals timelock-id)
)

(define-read-only (get-timelock-settings)
  {
    withdrawal-period: (var-get withdrawal-timelock-period),
    emergency-period: (var-get emergency-timelock-period)
  }
)

(define-read-only (get-bridge-analytics)
  (let (
    (uptime-blocks (if (> (var-get bridge-launch-height) u0) 
                      (- stacks-block-height (var-get bridge-launch-height)) 
                      u0))
    (total-transactions (var-get transaction-counter))
  )
    {
      total-volume: (var-get total-volume-processed),
      total-fees: (var-get total-fees-collected),
      total-locked: (var-get total-locked),
      total-transactions: total-transactions,
      uptime-blocks: uptime-blocks,
      average-tx-size: (if (> total-transactions u0) 
                          (/ (var-get total-volume-processed) total-transactions) 
                          u0)
    }
  )
)

(define-read-only (get-daily-volume (day-offset uint))
  (default-to u0 (map-get? daily-volume-tracking day-offset))
)

(define-read-only (get-chain-volume (chain-name (string-ascii 20)))
  (default-to u0 (map-get? chain-volume-stats chain-name))
)

(define-read-only (get-bridge-performance)
  (let (
    (total-txs (var-get transaction-counter))
    (total-vol (var-get total-volume-processed))
    (uptime (if (> (var-get bridge-launch-height) u0) 
               (- stacks-block-height (var-get bridge-launch-height)) 
               u0))
  )
    {
      utilization-rate: (if (> (var-get total-locked) u0) 
                           (/ (* total-vol u100) (var-get total-locked)) 
                           u0),
      avg-volume-per-block: (if (> uptime u0) (/ total-vol uptime) u0),
      fee-efficiency: (if (> total-vol u0) 
                         (/ (* (var-get total-fees-collected) u100) total-vol) 
                         u0)
    }
  )
)

(define-read-only (get-user-loyalty-tier (user principal))
  (let (
    (lifetime-vol (default-to u0 (map-get? user-lifetime-volume user)))
    (tier-1 (var-get rebate-tier-1-threshold))
    (tier-2 (var-get rebate-tier-2-threshold))
    (tier-3 (var-get rebate-tier-3-threshold))
  )
    {
      tier: (if (>= lifetime-vol tier-3) u3
              (if (>= lifetime-vol tier-2) u2
                (if (>= lifetime-vol tier-1) u1 u0))),
      lifetime-volume: lifetime-vol,
      rebate-rate: (if (>= lifetime-vol tier-3) u15
                     (if (>= lifetime-vol tier-2) u10
                       (if (>= lifetime-vol tier-1) u5 u0))),
      next-tier-volume: (if (>= lifetime-vol tier-3) u0
                          (if (>= lifetime-vol tier-2) (- tier-3 lifetime-vol)
                            (if (>= lifetime-vol tier-1) (- tier-2 lifetime-vol)
                              (- tier-1 lifetime-vol))))
    }
  )
)

(define-read-only (get-user-rebate-info (user principal))
  {
    available-rebate: (default-to u0 (map-get? user-rebate-balance user)),
    lifetime-volume: (default-to u0 (map-get? user-lifetime-volume user)),
    rebate-pool-total: (var-get rebate-pool)
  }
)

(define-read-only (get-rebate-tier-thresholds)
  {
    tier-1: (var-get rebate-tier-1-threshold),
    tier-2: (var-get rebate-tier-2-threshold),
    tier-3: (var-get rebate-tier-3-threshold),
    tier-1-rate: u5,
    tier-2-rate: u10,
    tier-3-rate: u15
  }
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
    (unwrap-panic (update-analytics amount u0 none))
    (try! (record-transaction sender "deposit" amount none none none "completed"))
    
    (ok amount)
  )
)

(define-public (initiate-timelock-withdrawal (amount uint))
  (let (
    (sender tx-sender)
    (current-balance (get-user-balance sender))
    (current-nonce (default-to u0 (map-get? user-timelock-nonces sender)))
    (new-nonce (+ current-nonce u1))
    (unlock-height (+ stacks-block-height (var-get withdrawal-timelock-period)))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)
    
    (map-set user-balances sender (- current-balance amount))
    (map-set timelock-withdrawals new-nonce {
      user: sender,
      amount: amount,
      unlock-height: unlock-height,
      withdrawn: false,
      emergency-override: false
    })
    (map-set user-timelock-nonces sender new-nonce)
    (try! (record-transaction sender "timelock-init" amount none none (some new-nonce) "pending"))
    
    (ok new-nonce)
  )
)

(define-public (complete-timelock-withdrawal (timelock-id uint))
  (let (
    (withdrawal-info (unwrap! (map-get? timelock-withdrawals timelock-id) ERR_DEPOSIT_NOT_FOUND))
    (sender tx-sender)
  )
    (asserts! (is-eq (get user withdrawal-info) sender) ERR_UNAUTHORIZED)
    (asserts! (not (get withdrawn withdrawal-info)) ERR_ALREADY_WITHDRAWN)
    (asserts! (or (>= stacks-block-height (get unlock-height withdrawal-info)) 
                  (get emergency-override withdrawal-info)) ERR_WITHDRAWAL_LOCKED)
    
    (try! (as-contract (stx-transfer? (get amount withdrawal-info) tx-sender sender)))
    (map-set timelock-withdrawals timelock-id (merge withdrawal-info { withdrawn: true }))
    (var-set total-locked (- (var-get total-locked) (get amount withdrawal-info)))
    (try! (record-transaction sender "timelock-complete" (get amount withdrawal-info) none none (some timelock-id) "completed"))
    
    (ok (get amount withdrawal-info))
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
    (unwrap-panic (update-analytics amount u0 none))
    (try! (record-transaction sender "withdraw" amount none none none "completed"))
    
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
    (unwrap-panic (update-analytics amount fee (some target-chain)))
    (unwrap-panic (process-fee-rebate sender fee))
    (try! (record-transaction sender "bridge-to-l2" amount (some target-chain) (some target-address) (some new-nonce) "completed"))
    
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
    (try! (record-transaction original-user "bridge-from-l2" amount none none (some deposit-id) "completed"))
    
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

(define-public (emergency-override-timelock (timelock-id uint))
  (let (
    (withdrawal-info (unwrap! (map-get? timelock-withdrawals timelock-id) ERR_DEPOSIT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get withdrawn withdrawal-info)) ERR_ALREADY_WITHDRAWN)
    
    (map-set timelock-withdrawals timelock-id (merge withdrawal-info { emergency-override: true }))
    (try! (record-transaction (get user withdrawal-info) "emergency-override" (get amount withdrawal-info) none none (some timelock-id) "override"))
    
    (ok timelock-id)
  )
)

(define-public (set-timelock-periods (withdrawal-period uint) (emergency-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> withdrawal-period u0) (> emergency-period u0)) ERR_INVALID_TIMELOCK_PERIOD)
    (asserts! (>= emergency-period withdrawal-period) ERR_INVALID_TIMELOCK_PERIOD)
    
    (var-set withdrawal-timelock-period withdrawal-period)
    (var-set emergency-timelock-period emergency-period)
    
    (ok { withdrawal-period: withdrawal-period, emergency-period: emergency-period })
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

(define-private (record-transaction (user principal) (tx-type (string-ascii 20)) (amount uint) (target-chain (optional (string-ascii 20))) (target-address (optional (string-ascii 64))) (deposit-id (optional uint)) (status (string-ascii 20)))
  (let (
    (current-counter (var-get transaction-counter))
    (new-counter (+ current-counter u1))
    (current-user-txs (default-to (list) (map-get? user-transaction-lists user)))
  )
    (map-set transaction-history new-counter {
      user: user,
      tx-type: tx-type,
      amount: amount,
      timestamp: stacks-block-height,
      target-chain: target-chain,
      target-address: target-address,
      deposit-id: deposit-id,
      status: status
    })
    (map-set user-transaction-lists user (unwrap! (as-max-len? (append current-user-txs new-counter) u100) (err u108)))
    (var-set transaction-counter new-counter)
    (ok new-counter)
  )
)

(define-read-only (get-transaction-history (tx-id uint))
  (map-get? transaction-history tx-id)
)

(define-read-only (get-user-transaction-list (user principal))
  (default-to (list) (map-get? user-transaction-lists user))
)

(define-read-only (get-user-transaction-count (user principal))
  (len (get-user-transaction-list user))
)

(define-read-only (get-last-n-transactions (user principal) (count uint))
  (let (
    (user-txs (get-user-transaction-list user))
    (tx-list-len (len user-txs))
  )
    (if (> count tx-list-len)
      user-txs
      (default-to (list) (slice? user-txs (- tx-list-len count) tx-list-len))
    )
  )
)

(define-private (update-analytics (amount uint) (fee uint) (chain (optional (string-ascii 20))))
  (let (
    (current-volume (var-get total-volume-processed))
    (current-fees (var-get total-fees-collected))
    (day-key (/ stacks-block-height u144))
    (current-daily-volume (default-to u0 (map-get? daily-volume-tracking day-key)))
  )
    (if (is-eq (var-get bridge-launch-height) u0)
      (var-set bridge-launch-height stacks-block-height)
      true
    )
    (var-set total-volume-processed (+ current-volume amount))
    (var-set total-fees-collected (+ current-fees fee))
    (map-set daily-volume-tracking day-key (+ current-daily-volume amount))
    (if (is-some chain)
      (let (
        (chain-name (unwrap-panic chain))
        (current-chain-volume (default-to u0 (map-get? chain-volume-stats chain-name)))
      )
        (map-set chain-volume-stats chain-name (+ current-chain-volume amount))
      )
      true
    )
    (ok true)
  )
)

(define-private (process-fee-rebate (user principal) (fee uint))
  (let (
    (lifetime-vol (default-to u0 (map-get? user-lifetime-volume user)))
    (new-lifetime-vol (+ lifetime-vol fee))
    (tier-1 (var-get rebate-tier-1-threshold))
    (tier-2 (var-get rebate-tier-2-threshold))
    (tier-3 (var-get rebate-tier-3-threshold))
    (rebate-rate (if (>= new-lifetime-vol tier-3) u15
                   (if (>= new-lifetime-vol tier-2) u10
                     (if (>= new-lifetime-vol tier-1) u5 u0))))
    (rebate-amount (/ (* fee rebate-rate) u100))
    (current-rebate (default-to u0 (map-get? user-rebate-balance user)))
    (current-pool (var-get rebate-pool))
  )
    (map-set user-lifetime-volume user new-lifetime-vol)
    (if (> rebate-amount u0)
      (begin
        (map-set user-rebate-balance user (+ current-rebate rebate-amount))
        (var-set rebate-pool (+ current-pool rebate-amount))
      )
      true
    )
    (ok true)
  )
)

(define-public (claim-rebate)
  (let (
    (sender tx-sender)
    (rebate-amount (default-to u0 (map-get? user-rebate-balance sender)))
    (pool-balance (var-get rebate-pool))
  )
    (asserts! (> rebate-amount u0) ERR_NO_REBATE_AVAILABLE)
    (asserts! (>= pool-balance rebate-amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? rebate-amount tx-sender sender)))
    (map-set user-rebate-balance sender u0)
    (var-set rebate-pool (- pool-balance rebate-amount))
    
    (ok rebate-amount)
  )
)

(define-public (set-rebate-tier-threshold (tier uint) (threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= tier u3) ERR_INVALID_TIER)
    (asserts! (> threshold u0) ERR_INVALID_AMOUNT)
    
    (if (is-eq tier u1)
      (var-set rebate-tier-1-threshold threshold)
      (if (is-eq tier u2)
        (var-set rebate-tier-2-threshold threshold)
        (if (is-eq tier u3)
          (var-set rebate-tier-3-threshold threshold)
          false
        )
      )
    )
    (ok threshold)
  )
)

(define-public (fund-rebate-pool (amount uint))
  (let (
    (sender tx-sender)
    (current-pool (var-get rebate-pool))
  )
    (asserts! (is-eq sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (var-set rebate-pool (+ current-pool amount))
    
    (ok amount)
  )
)

(define-public (initialize-bridge-analytics)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get bridge-launch-height) u0) ERR_UNAUTHORIZED)
    (var-set bridge-launch-height stacks-block-height)
    (ok stacks-block-height)
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

(define-read-only (simulate-bridge-impact (amount uint) (chain (optional (string-ascii 20))))
  (let (
    (fee (var-get bridge-fee))
    (total (if (> amount u0) (+ amount fee) u0))
    (new-total-locked (+ (var-get total-locked) amount))
    (new-total-volume (+ (var-get total-volume-processed) amount))
    (new-total-fees (+ (var-get total-fees-collected) fee))
    (day-key (/ stacks-block-height u144))
    (current-daily-volume (default-to u0 (map-get? daily-volume-tracking day-key)))
    (new-daily-volume (+ current-daily-volume amount))
    (new-chain-volume (if (is-some chain)
                         (+ (default-to u0 (map-get? chain-volume-stats (unwrap-panic chain))) amount)
                         u0))
    (projected-tx-count (+ (var-get transaction-counter) u1))
  )
    {
      amount: amount,
      fee: fee,
      total: total,
      new-total-locked: new-total-locked,
      new-total-volume: new-total-volume,
      new-total-fees: new-total-fees,
      new-daily-volume: new-daily-volume,
      new-chain-volume: new-chain-volume,
      projected-average-tx-size: (if (> projected-tx-count u0)
                                   (/ new-total-volume projected-tx-count)
                                   u0)
    }
  )
)
