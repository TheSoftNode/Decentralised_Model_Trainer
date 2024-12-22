;; AI Model Training Platform - Main Contract
;; Handles user registration, compute contributions, token rewards, and platform governance

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-invalid-parameters (err u106))

;; Data Variables
(define-data-var minimum-contribution uint u100)
(define-data-var reward-rate uint u10)  ;; tokens per compute unit
(define-data-var total-compute-power uint u0)
(define-data-var contribution-cooldown uint u144) ;; ~24 hours in blocks
(define-data-var minimum-stake uint u1000) ;; minimum tokens to stake
(define-data-var platform-fee-rate uint u5) ;; 0.5% fee

;; Data Maps
(define-map Users principal 
  {
    compute-power: uint,
    total-rewards: uint,
    is-active: bool,
    registration-time: uint,
    reputation-score: uint,
    staked-amount: uint
  }
)

(define-map Contributions principal 
  {
    last-contribution: uint,
    contribution-count: uint,
    total-compute-contributed: uint,
    last-reward-claim: uint
  }
)

(define-map ModelTrainingJobs uint 
  {
    creator: principal,
    compute-required: uint,
    reward-multiplier: uint,
    participants: (list 50 principal),
    is-active: bool,
    created-at: uint
  }
)


;; Check if user is registered
(define-read-only (is-user-registered (user principal))
  (is-some (map-get? Users user)))

(define-private (update-user-compute-power (user principal) (amount uint))
  (let ((current-data (unwrap-panic (map-get? Users user))))
    (map-set Users user (merge current-data {
      compute-power: (+ (get compute-power current-data) amount)
    }))
    (var-set total-compute-power (+ (var-get total-compute-power) amount))))

(define-read-only (get-contribution-count (user principal))
  (get contribution-count (default-to 
    {last-contribution: u0, contribution-count: u0}
    (map-get? Contributions user))))

(define-read-only (get-user-total-rewards (user principal))
  (get total-rewards (default-to 
    {compute-power: u0, total-rewards: u0, is-active: false, registration-time: u0}
    (map-get? Users user))))

(define-private (update-user-rewards (user principal) (amount uint))
  (let ((current-data (unwrap-panic (map-get? Users user))))
    (map-set Users user (merge current-data {
      total-rewards: (+ (get total-rewards current-data) amount)
    }))))

;; Calculate rewards for contribution
(define-private (calculate-rewards (amount uint))
  (* amount (var-get reward-rate)))

;; Reward user for contribution
(define-private (reward-user (user principal) (amount uint))
  (let ((rewards (calculate-rewards amount)))
    (update-user-rewards user rewards)
    rewards))

;; Get pending rewards
(define-read-only (get-pending-rewards (user principal))
  (let ((user-data (unwrap-panic (map-get? Users user))))
    (if (get is-active user-data)
        (calculate-rewards (get compute-power user-data))
        u0)))

;; Register new user
(define-public (register-user)
  (let ((user tx-sender))
    (if (is-user-registered user)
        err-already-registered
        (begin
          (map-set Users user {
            compute-power: u0,
            total-rewards: u0,
            is-active: true,
            registration-time: block-height,
            reputation-score: u0,
            staked-amount: u0
          })
          (ok true)))))

;; Contribute compute power
(define-public (contribute-compute (amount uint))
  (let ((user tx-sender))
    (if (and (is-user-registered user)
             (>= amount (var-get minimum-contribution)))
        (begin
          (map-set Contributions user {
            last-contribution: block-height,
            contribution-count: (+ (get-contribution-count user) u1),
            total-compute-contributed: (+ (get total-compute-contributed (default-to {total-compute-contributed: u0} (map-get? Contributions user))) amount),
            last-reward-claim: block-height
          })
          (update-user-compute-power user amount)
          (reward-user user amount)
          (ok true))
        err-invalid-amount)))

;; Claim rewards
(define-public (claim-rewards)
  (let ((user tx-sender)
        (current-rewards (get-pending-rewards user)))
    (if (> current-rewards u0)
        (begin
          (try! (as-contract (stx-transfer? current-rewards contract-owner user)))
          (update-user-rewards user current-rewards)
          (ok current-rewards))
        (ok u0))))

;; Stake tokens to increase rewards multiplier
(define-public (stake-tokens (amount uint))
  (let ((user tx-sender)
        (user-data (unwrap-panic (map-get? Users user))))
    (asserts! (>= amount (var-get minimum-stake)) err-insufficient-stake)
    (try! (stx-transfer? amount user contract-owner))
    (map-set Users user (merge user-data {
      staked-amount: (+ (get staked-amount user-data) amount)
    }))
    (ok true)))

;; Get user's effective reward multiplier based on stake
(define-read-only (get-reward-multiplier (user principal))
  (let ((staked-amount (get staked-amount (unwrap-panic (map-get? Users user)))))
    (+ u100 (/ (* staked-amount u10) (var-get minimum-stake)))))

;; Update user reputation based on contribution quality
(define-public (update-reputation (user principal) (quality-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((user-data (unwrap-panic (map-get? Users user))))
      (map-set Users user (merge user-data {
        reputation-score: (+ (get reputation-score user-data) quality-score)
      }))
      (ok true))))

;; Check if user can contribute (cooldown period)
(define-read-only (can-contribute (user principal))
  (let ((last-contribution (get last-contribution 
         (default-to {last-contribution: u0, contribution-count: u0, 
                     total-compute-contributed: u0, last-reward-claim: u0}
         (map-get? Contributions user)))))
    (>= (- block-height last-contribution) (var-get contribution-cooldown))))

;; Update platform parameters (admin only)
(define-public (update-platform-params 
    (new-cooldown uint) 
    (new-minimum-stake uint)
    (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contribution-cooldown new-cooldown)
    (var-set minimum-stake new-minimum-stake)
    (var-set platform-fee-rate new-fee-rate)
    (ok true)))

;; Update minimum contribution requirement
(define-public (set-minimum-contribution (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set minimum-contribution new-minimum)
    (ok true)))