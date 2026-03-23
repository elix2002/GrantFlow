;; ============================================================
;; GrantFlowDAO.clar
;; Decentralized Research Grant & Milestone Funding DAO
;; Version 2.0 (Refactored & Secured)
;; ============================================================

;; =========================
;; CONSTANTS / ERRORS
;; =========================
(define-constant ERR-NOT-AUTHORIZED (err u403))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID (err u400))
(define-constant ERR-FUNDING-CLOSED (err u405))
(define-constant ERR-NO-CONTRIBUTION (err u406))
(define-constant ERR-NOT-VERIFIER (err u407))

;; =========================
;; CONFIG
;; =========================
(define-data-var owner principal tx-sender)

;; =========================
;; STATE
;; =========================

(define-data-var proposal-id uint u0)

(define-map proposals
  { id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    goal: uint,
    raised: uint,
    milestones: uint,
    completed: uint,
    deadline: uint,
    active: bool,
    refundable: bool
  }
)

(define-map contributions
  { id: uint, user: principal }
  { amount: uint }
)

(define-map verifiers
  { user: principal }
  { allowed: bool }
)

;; =========================
;; READ FUNCTIONS
;; =========================

(define-read-only (get-proposal (id uint))
  (map-get? proposals { id: id })
)

(define-read-only (get-contribution (id uint) (user principal))
  (map-get? contributions { id: id, user: user })
)

(define-read-only (is-verifier (user principal))
  (is-some (map-get? verifiers { user: user }))
)

;; =========================
;; INTERNAL HELPERS
;; =========================

(define-private (is-valid-string-title (title (string-ascii 100)))
  (and (> (len title) u0) (<= (len title) u100))
)

(define-private (is-valid-string-desc (desc (string-ascii 300)))
  (and (> (len desc) u0) (<= (len desc) u300))
)

(define-private (is-valid-principal (principal principal))
  (not (is-eq principal (as-contract tx-sender)))
)

(define-private (update-proposal (id uint) (p (tuple
  (creator principal)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (goal uint)
  (raised uint)
  (milestones uint)
  (completed uint)
  (deadline uint)
  (active bool)
  (refundable bool)
)))
  (map-set proposals { id: id } p)
)

;; =========================
;; PROPOSALS
;; =========================

(define-public (create-proposal
  (title (string-ascii 100))
  (desc (string-ascii 300))
  (goal uint)
  (milestones uint)
  (deadline uint)
)
  (let ((id (+ (var-get proposal-id) u1)))
    (begin
      (asserts! (is-valid-string-title title) ERR-INVALID)
      (asserts! (is-valid-string-desc desc) ERR-INVALID)
      (asserts! (> goal u0) ERR-INVALID)
      (asserts! (> milestones u0) ERR-INVALID)
      (asserts! (> deadline u0) ERR-INVALID)

      (map-set proposals
        { id: id }
        {
          creator: tx-sender,
          title: title,
          description: desc,
          goal: goal,
          raised: u0,
          milestones: milestones,
          completed: u0,
          deadline: deadline,
          active: true,
          refundable: false
        })

      (var-set proposal-id id)

      (print { event: "proposal-created", id: id })
      (ok id)
    )
  )
)

;; =========================
;; FUNDING (REAL STX)
;; =========================

(define-public (fund (id uint) (amount uint))
  (let ((p (map-get? proposals { id: id })))
    (asserts! (is-some p) ERR-NOT-FOUND)
    (asserts! (> id u0) ERR-INVALID)
    (asserts! (> amount u0) ERR-INVALID)

    (let (
          (prop (unwrap! p ERR-NOT-FOUND))
         )
      (begin
        (asserts! (get active prop) ERR-INVALID)
        (asserts! (<= burn-block-height (get deadline prop)) ERR-FUNDING-CLOSED)

        ;; record contribution
        (let ((existing (default-to u0 (get amount (map-get? contributions { id: id, user: tx-sender })))))
          (map-set contributions { id: id, user: tx-sender }
            { amount: (+ existing amount) })
        )

        ;; update proposal
        (update-proposal id
          {
            creator: (get creator prop),
            title: (get title prop),
            description: (get description prop),
            goal: (get goal prop),
            raised: (+ (get raised prop) amount),
            milestones: (get milestones prop),
            completed: (get completed prop),
            deadline: (get deadline prop),
            active: true,
            refundable: (get refundable prop)
          })

        (print { event: "funded", id: id, from: tx-sender, amount: amount })
        (ok amount)
      )
    )
  )
)

;; =========================
;; GOVERNANCE / VERIFIERS
;; =========================

(define-public (add-verifier (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-principal user) ERR-INVALID)
    (map-set verifiers { user: user } { allowed: true })
    (ok true)
  )
)

;; =========================
;; MILESTONE EXECUTION
;; =========================

(define-public (approve (id uint))
  (let ((p (map-get? proposals { id: id })))
    (asserts! (is-some p) ERR-NOT-FOUND)
    (asserts! (> id u0) ERR-INVALID)

    (let ((prop (unwrap! p ERR-NOT-FOUND)))
      (begin
        (asserts!
          (or (is-eq tx-sender (var-get owner)) (is-verifier tx-sender))
          ERR-NOT-VERIFIER)

        (asserts! (> burn-block-height (get deadline prop)) ERR-FUNDING-CLOSED)
        (asserts! (< (get completed prop) (get milestones prop)) ERR-INVALID)

        (let ((payout (/ (get raised prop) (get milestones prop))))
          (asserts! (> payout u0) ERR-INVALID)

          ;; transfer from contract
          (unwrap! 
            (as-contract (stx-transfer? payout tx-sender (get creator prop)))
            ERR-INVALID
          )

          ;; update state
          (update-proposal id
            {
              creator: (get creator prop),
              title: (get title prop),
              description: (get description prop),
              goal: (get goal prop),
              raised: (- (get raised prop) payout),
              milestones: (get milestones prop),
              completed: (+ (get completed prop) u1),
              deadline: (get deadline prop),
              active: true,
              refundable: (get refundable prop)
            })

          (print { event: "milestone-approved", id: id, payout: payout })
          (ok payout)
        )
      )
    )
  )
)

;; =========================
;; CANCEL & REFUND
;; =========================

(define-public (cancel (id uint))
  (let ((p (map-get? proposals { id: id })))
    (asserts! (is-some p) ERR-NOT-FOUND)
    (asserts! (> id u0) ERR-INVALID)

    (let ((prop (unwrap! p ERR-NOT-FOUND)))
      (begin
        (asserts!
          (or (is-eq tx-sender (get creator prop)) (is-eq tx-sender (var-get owner)))
          ERR-NOT-AUTHORIZED)

        (asserts! (is-eq (get completed prop) u0) ERR-INVALID)

        (update-proposal id
          {
            creator: (get creator prop),
            title: (get title prop),
            description: (get description prop),
            goal: (get goal prop),
            raised: (get raised prop),
            milestones: (get milestones prop),
            completed: (get completed prop),
            deadline: (get deadline prop),
            active: false,
            refundable: true
          })

        (ok true)
      )
    )
  )
)

(define-public (refund (id uint))
  (let (
        (c (map-get? contributions { id: id, user: tx-sender }))
        (p (map-get? proposals { id: id }))
       )
    (asserts! (is-some c) ERR-NO-CONTRIBUTION)
    (asserts! (is-some p) ERR-NOT-FOUND)
    (asserts! (> id u0) ERR-INVALID)

    (let (
          (contrib (unwrap! c ERR-NO-CONTRIBUTION))
          (prop (unwrap! p ERR-NOT-FOUND))
          (amt (get amount contrib))
         )
      (begin
        (asserts! (> amt u0) ERR-NO-CONTRIBUTION)
        (asserts! (get refundable prop) ERR-INVALID)

        ;; clear contribution
        (map-set contributions { id: id, user: tx-sender } { amount: u0 })

        ;; transfer back
        (unwrap!
          (as-contract (stx-transfer? amt tx-sender tx-sender))
          ERR-INVALID
        )

        (print { event: "refund", id: id, amount: amt })
        (ok amt)
      )
    )
  )
)

;; =========================
;; ADMIN
;; =========================

(define-public (update-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR-INVALID)
    (var-set owner new-owner)
    (ok true)
  )
)

(define-public (withdraw (amount uint) (to principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID)
    (asserts! (is-valid-principal to) ERR-INVALID)
    (unwrap!
      (as-contract (stx-transfer? amount tx-sender to))
      ERR-INVALID
    )
    (ok true)
  )
)
