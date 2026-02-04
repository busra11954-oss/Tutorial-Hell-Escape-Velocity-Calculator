;; title: tutorial-completion-abandonment-tracker
;; version: 1.0.0
;; summary: Tracks tutorial consumption patterns and abandonment behavior
;; description: Records the exact moment developers abandon tutorials, helping identify
;;              problematic learning patterns and calculate completion rates

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-completed (err u102))
(define-constant err-already-abandoned (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-unauthorized (err u105))

;; Tutorial status codes
(define-constant status-in-progress u0)
(define-constant status-completed u1)
(define-constant status-abandoned u2)

;; Data Variables
(define-data-var tutorial-counter uint u0)
(define-data-var total-tutorials-started uint u0)
(define-data-var total-tutorials-completed uint u0)
(define-data-var total-tutorials-abandoned uint u0)

;; Data Maps
(define-map tutorials
  uint
  {
    owner: principal,
    title: (string-ascii 100),
    source: (string-ascii 100),
    start-block: uint,
    end-block: (optional uint),
    status: uint,
    abandonment-reason: (optional (string-ascii 200)),
    minutes-watched: uint
  }
)

(define-map user-stats
  principal
  {
    tutorials-started: uint,
    tutorials-completed: uint,
    tutorials-abandoned: uint,
    total-minutes-watched: uint,
    completion-rate: uint
  }
)

(define-map user-tutorial-ids
  { user: principal, index: uint }
  uint
)

(define-map user-tutorial-count
  principal
  uint
)

;; Private Functions

(define-private (calculate-completion-rate (completed uint) (started uint))
  (if (is-eq started u0)
    u0
    (/ (* completed u100) started)
  )
)

(define-private (update-user-stats (user principal) (status-change uint))
  (let
    (
      (current-stats (default-to
        { tutorials-started: u0, tutorials-completed: u0, tutorials-abandoned: u0, 
          total-minutes-watched: u0, completion-rate: u0 }
        (map-get? user-stats user)
      ))
      (new-completed (if (is-eq status-change status-completed)
        (+ (get tutorials-completed current-stats) u1)
        (get tutorials-completed current-stats)
      ))
      (new-abandoned (if (is-eq status-change status-abandoned)
        (+ (get tutorials-abandoned current-stats) u1)
        (get tutorials-abandoned current-stats)
      ))
      (started (get tutorials-started current-stats))
    )
    (map-set user-stats user
      (merge current-stats {
        tutorials-completed: new-completed,
        tutorials-abandoned: new-abandoned,
        completion-rate: (calculate-completion-rate new-completed started)
      })
    )
  )
)

;; Public Functions

(define-public (start-tutorial (title (string-ascii 100)) (source (string-ascii 100)))
  (let
    (
      (tutorial-id (+ (var-get tutorial-counter) u1))
      (user tx-sender)
      (current-stats (default-to
        { tutorials-started: u0, tutorials-completed: u0, tutorials-abandoned: u0,
          total-minutes-watched: u0, completion-rate: u0 }
        (map-get? user-stats user)
      ))
      (user-count (default-to u0 (map-get? user-tutorial-count user)))
    )
    (map-set tutorials tutorial-id
      {
        owner: user,
        title: title,
        source: source,
        start-block: stacks-block-height,
        end-block: none,
        status: status-in-progress,
        abandonment-reason: none,
        minutes-watched: u0
      }
    )
    (var-set tutorial-counter tutorial-id)
    (var-set total-tutorials-started (+ (var-get total-tutorials-started) u1))
    
    (map-set user-stats user
      (merge current-stats {
        tutorials-started: (+ (get tutorials-started current-stats) u1)
      })
    )
    
    (map-set user-tutorial-ids { user: user, index: user-count } tutorial-id)
    (map-set user-tutorial-count user (+ user-count u1))
    
    (ok tutorial-id)
  )
)

(define-public (complete-tutorial (tutorial-id uint))
  (let
    (
      (tutorial (unwrap! (map-get? tutorials tutorial-id) err-not-found))
    )
    (asserts! (is-eq (get owner tutorial) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status tutorial) status-in-progress) err-invalid-status)
    
    (map-set tutorials tutorial-id
      (merge tutorial {
        end-block: (some stacks-block-height),
        status: status-completed
      })
    )
    
    (var-set total-tutorials-completed (+ (var-get total-tutorials-completed) u1))
    (update-user-stats tx-sender status-completed)
    
    (ok true)
  )
)

(define-public (abandon-tutorial 
  (tutorial-id uint) 
  (reason (string-ascii 200))
  (minutes-watched uint)
)
  (let
    (
      (tutorial (unwrap! (map-get? tutorials tutorial-id) err-not-found))
      (user tx-sender)
      (current-stats (unwrap! (map-get? user-stats user) err-not-found))
    )
    (asserts! (is-eq (get owner tutorial) user) err-unauthorized)
    (asserts! (is-eq (get status tutorial) status-in-progress) err-invalid-status)
    
    (map-set tutorials tutorial-id
      (merge tutorial {
        end-block: (some stacks-block-height),
        status: status-abandoned,
        abandonment-reason: (some reason),
        minutes-watched: minutes-watched
      })
    )
    
    (var-set total-tutorials-abandoned (+ (var-get total-tutorials-abandoned) u1))
    
    (map-set user-stats user
      (merge current-stats {
        total-minutes-watched: (+ (get total-minutes-watched current-stats) minutes-watched)
      })
    )
    
    (update-user-stats user status-abandoned)
    
    (ok true)
  )
)

;; Read-Only Functions

(define-read-only (get-tutorial (tutorial-id uint))
  (ok (map-get? tutorials tutorial-id))
)

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats user))
)

(define-read-only (get-global-stats)
  (ok {
    total-started: (var-get total-tutorials-started),
    total-completed: (var-get total-tutorials-completed),
    total-abandoned: (var-get total-tutorials-abandoned),
    global-completion-rate: (calculate-completion-rate 
      (var-get total-tutorials-completed)
      (var-get total-tutorials-started)
    )
  })
)

(define-read-only (get-user-tutorial-by-index (user principal) (index uint))
  (let
    (
      (tutorial-id (map-get? user-tutorial-ids { user: user, index: index }))
    )
    (if (is-some tutorial-id)
      (ok (map-get? tutorials (unwrap-panic tutorial-id)))
      (ok none)
    )
  )
)

(define-read-only (get-user-tutorial-count (user principal))
  (ok (default-to u0 (map-get? user-tutorial-count user)))
)

(define-read-only (get-tutorial-counter)
  (ok (var-get tutorial-counter))
)


