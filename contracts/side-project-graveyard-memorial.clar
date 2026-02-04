;; title: side-project-graveyard-memorial
;; version: 1.0.0
;; summary: A memorial for abandoned side projects
;; description: Maintains permanent records of unfinished projects with timestamps,
;;              obituary generation, and inactivity tracking

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-completed (err u202))
(define-constant err-already-retired (err u203))
(define-constant err-unauthorized (err u204))
(define-constant err-invalid-status (err u205))

;; Project status codes
(define-constant status-active u0)
(define-constant status-completed u1)
(define-constant status-abandoned u2)
(define-constant status-retired u3)

;; Blocks per day (assuming 10 minute block times on Stacks)
(define-constant blocks-per-day u144)

;; Data Variables
(define-data-var project-counter uint u0)
(define-data-var total-projects-created uint u0)
(define-data-var total-projects-completed uint u0)
(define-data-var total-projects-abandoned uint u0)
(define-data-var total-commits-recorded uint u0)

;; Data Maps
(define-map projects
  uint
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-ascii 300),
    creation-block: uint,
    last-commit-block: uint,
    completion-block: (optional uint),
    status: uint,
    total-commits: uint,
    days-inactive: uint,
    obituary: (optional (string-ascii 500))
  }
)

(define-map user-project-stats
  principal
  {
    projects-created: uint,
    projects-completed: uint,
    projects-abandoned: uint,
    total-commits: uint,
    graveyard-size: uint
  }
)

(define-map user-project-ids
  { user: principal, index: uint }
  uint
)

(define-map user-project-count
  principal
  uint
)

(define-map project-commits
  { project-id: uint, commit-index: uint }
  {
    stacks-block-height: uint,
    days-since-last: uint
  }
)

;; Private Functions

(define-private (calculate-days-inactive (last-commit-block uint))
  (let
    (
      (blocks-elapsed (- stacks-block-height last-commit-block))
    )
    (/ blocks-elapsed blocks-per-day)
  )
)

(define-private (generate-obituary-text 
  (name (string-ascii 100))
  (days-inactive uint)
  (total-commits uint)
)
  (if (< total-commits u5)
    "Died in infancy, barely made it past the initial commit"
    (if (< days-inactive u30)
      "Recently departed, still warm in our hearts and git logs"
      (if (< days-inactive u90)
        "Abandoned in the prime of development, a tragedy of modern times"
        (if (< days-inactive u180)
          "Long forgotten, now just a distant memory in your GitHub profile"
          "Ancient history, archaeologists will study this one day"
        )
      )
    )
  )
)

(define-private (update-user-stats-on-create (user principal))
  (let
    (
      (current-stats (default-to
        { projects-created: u0, projects-completed: u0, projects-abandoned: u0,
          total-commits: u0, graveyard-size: u0 }
        (map-get? user-project-stats user)
      ))
    )
    (map-set user-project-stats user
      (merge current-stats {
        projects-created: (+ (get projects-created current-stats) u1)
      })
    )
  )
)

(define-private (update-user-stats-on-completion (user principal))
  (let
    (
      (current-stats (unwrap-panic (map-get? user-project-stats user)))
    )
    (map-set user-project-stats user
      (merge current-stats {
        projects-completed: (+ (get projects-completed current-stats) u1)
      })
    )
  )
)

(define-private (update-user-stats-on-abandon (user principal))
  (let
    (
      (current-stats (unwrap-panic (map-get? user-project-stats user)))
    )
    (map-set user-project-stats user
      (merge current-stats {
        projects-abandoned: (+ (get projects-abandoned current-stats) u1),
        graveyard-size: (+ (get graveyard-size current-stats) u1)
      })
    )
  )
)

;; Public Functions

(define-public (register-project (name (string-ascii 100)) (description (string-ascii 300)))
  (let
    (
      (project-id (+ (var-get project-counter) u1))
      (user tx-sender)
      (user-count (default-to u0 (map-get? user-project-count user)))
    )
    (map-set projects project-id
      {
        owner: user,
        name: name,
        description: description,
        creation-block: stacks-block-height,
        last-commit-block: stacks-block-height,
        completion-block: none,
        status: status-active,
        total-commits: u1,
        days-inactive: u0,
        obituary: none
      }
    )
    
    (var-set project-counter project-id)
    (var-set total-projects-created (+ (var-get total-projects-created) u1))
    (var-set total-commits-recorded (+ (var-get total-commits-recorded) u1))
    
    (update-user-stats-on-create user)
    
    (map-set user-project-ids { user: user, index: user-count } project-id)
    (map-set user-project-count user (+ user-count u1))
    
    (map-set project-commits { project-id: project-id, commit-index: u0 }
      {
        stacks-block-height: stacks-block-height,
        days-since-last: u0
      }
    )
    
    (ok project-id)
  )
)

(define-public (record-commit (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) err-not-found))
      (days-since-last (calculate-days-inactive (get last-commit-block project)))
      (new-commit-count (+ (get total-commits project) u1))
      (user tx-sender)
      (current-stats (unwrap! (map-get? user-project-stats user) err-not-found))
    )
    (asserts! (is-eq (get owner project) user) err-unauthorized)
    (asserts! (is-eq (get status project) status-active) err-invalid-status)
    
    (map-set projects project-id
      (merge project {
        last-commit-block: stacks-block-height,
        total-commits: new-commit-count,
        days-inactive: u0
      })
    )
    
    (map-set project-commits { project-id: project-id, commit-index: (get total-commits project) }
      {
        stacks-block-height: stacks-block-height,
        days-since-last: days-since-last
      }
    )
    
    (var-set total-commits-recorded (+ (var-get total-commits-recorded) u1))
    
    (map-set user-project-stats user
      (merge current-stats {
        total-commits: (+ (get total-commits current-stats) u1)
      })
    )
    
    (ok true)
  )
)

(define-public (complete-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) err-not-found))
    )
    (asserts! (is-eq (get owner project) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status project) status-active) err-invalid-status)
    
    (map-set projects project-id
      (merge project {
        completion-block: (some stacks-block-height),
        status: status-completed
      })
    )
    
    (var-set total-projects-completed (+ (var-get total-projects-completed) u1))
    (update-user-stats-on-completion tx-sender)
    
    (ok true)
  )
)

(define-public (abandon-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) err-not-found))
      (days-inactive (calculate-days-inactive (get last-commit-block project)))
      (obituary-text (generate-obituary-text 
        (get name project)
        days-inactive
        (get total-commits project)
      ))
    )
    (asserts! (is-eq (get owner project) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status project) status-active) err-invalid-status)
    
    (map-set projects project-id
      (merge project {
        status: status-abandoned,
        days-inactive: days-inactive,
        obituary: (some obituary-text)
      })
    )
    
    (var-set total-projects-abandoned (+ (var-get total-projects-abandoned) u1))
    (update-user-stats-on-abandon tx-sender)
    
    (ok obituary-text)
  )
)

(define-public (retire-project (project-id uint) (custom-obituary (string-ascii 500)))
  (let
    (
      (project (unwrap! (map-get? projects project-id) err-not-found))
    )
    (asserts! (is-eq (get owner project) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status project) status-active) err-invalid-status)
    
    (map-set projects project-id
      (merge project {
        status: status-retired,
        days-inactive: (calculate-days-inactive (get last-commit-block project)),
        obituary: (some custom-obituary)
      })
    )
    
    (ok true)
  )
)

;; Read-Only Functions

(define-read-only (get-project (project-id uint))
  (ok (map-get? projects project-id))
)

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-project-stats user))
)

(define-read-only (get-global-stats)
  (ok {
    total-created: (var-get total-projects-created),
    total-completed: (var-get total-projects-completed),
    total-abandoned: (var-get total-projects-abandoned),
    total-commits: (var-get total-commits-recorded)
  })
)

(define-read-only (get-project-inactivity (project-id uint))
  (let
    (
      (project (map-get? projects project-id))
    )
    (if (is-some project)
      (ok (some (calculate-days-inactive (get last-commit-block (unwrap-panic project)))))
      (ok none)
    )
  )
)

(define-read-only (generate-obituary (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects project-id) err-not-found))
      (days-inactive (calculate-days-inactive (get last-commit-block project)))
    )
    (ok (generate-obituary-text 
      (get name project)
      days-inactive
      (get total-commits project)
    ))
  )
)

(define-read-only (get-user-project-by-index (user principal) (index uint))
  (let
    (
      (project-id (map-get? user-project-ids { user: user, index: index }))
    )
    (if (is-some project-id)
      (ok (map-get? projects (unwrap-panic project-id)))
      (ok none)
    )
  )
)

(define-read-only (get-user-project-count (user principal))
  (ok (default-to u0 (map-get? user-project-count user)))
)

(define-read-only (get-project-counter)
  (ok (var-get project-counter))
)

(define-read-only (get-commit-info (project-id uint) (commit-index uint))
  (ok (map-get? project-commits { project-id: project-id, commit-index: commit-index }))
)


