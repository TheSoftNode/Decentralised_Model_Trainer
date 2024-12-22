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
