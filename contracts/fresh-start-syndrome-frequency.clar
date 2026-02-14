;; Fresh Start Syndrome Frequency Contract
;; Tracks how often developers restart the same project with different frameworks
;; Monitors portfolio rebuilding patterns and framework switching behavior

;; ============================================
;; Constants
;; ============================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-DEVELOPER (err u201))
(define-constant ERR-INVALID-PROJECT-ID (err u202))
(define-constant ERR-INVALID-REBUILD-ID (err u203))
(define-constant ERR-PROJECT-NOT-FOUND (err u204))
(define-constant ERR-REBUILD-NOT-FOUND (err u205))
(define-constant ERR-ALREADY-EXISTS (err u206))
(define-constant ERR-INVALID-INPUT (err u207))
(define-constant ERR-NO-REBUILDS (err u208))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Syndrome severity thresholds
(define-constant MILD-SYNDROME u3)      ;; 3-5 rebuilds: mild case
(define-constant MODERATE-SYNDROME u6)  ;; 6-10 rebuilds: moderate case
(define-constant SEVERE-SYNDROME u11)   ;; 11+ rebuilds: severe case
(define-constant HEALTHY-THRESHOLD u2)  ;; 0-2 rebuilds: normal iteration

;; ============================================
;; Data Maps and Variables
;; ============================================

;; Track developer project portfolios
(define-map developer-portfolios
  principal
  {
    total-projects: uint,
    total-rebuilds: uint,
    total-frameworks-tried: uint,
    most-rebuilt-project: (string-ascii 100),
    registration-timestamp: uint,
    last-rebuild-timestamp: uint
  }
)

;; Track individual project concepts and their iterations
(define-map project-concepts
  { developer: principal, project-id: uint }
  {
    project-concept: (string-ascii 100),
    initial-framework: (string-ascii 50),
    creation-timestamp: uint,
    rebuild-count: uint,
    completion-status: (string-ascii 20),
    is-abandoned: bool
  }
)

;; Track individual rebuild instances
(define-map rebuilds
  { developer: principal, project-id: uint, rebuild-id: uint }
  {
    framework-used: (string-ascii 50),
    rebuild-timestamp: uint,
    reason: (string-ascii 200),
    days-since-last-version: uint
  }
)

;; Framework popularity tracking
(define-map framework-usage
  (string-ascii 50)
  uint  ;; count of how many times used
)

;; Global statistics
(define-data-var total-registered-developers uint u0)
(define-data-var total-projects-tracked uint u0)
(define-data-var total-rebuilds-recorded uint u0)
(define-data-var average-rebuild-frequency uint u0)

;; ============================================
;; Private Helper Functions
;; ============================================

;; Calculate syndrome severity level
(define-private (get-syndrome-level (rebuild-count uint))
  (if (>= rebuild-count SEVERE-SYNDROME)
    "SEVERE"
    (if (>= rebuild-count MODERATE-SYNDROME)
      "MODERATE"
      (if (>= rebuild-count MILD-SYNDROME)
        "MILD"
        "HEALTHY"
      )
    )
  )
)

;; Update framework usage statistics
(define-private (increment-framework-usage (framework (string-ascii 50)))
  (let
    (
      (current-count (default-to u0 (map-get? framework-usage framework)))
    )
    (map-set framework-usage framework (+ current-count u1))
    (ok true)
  )
)

;; Update global statistics
(define-private (update-global-stats)
  (let
    (
      (total-projects (var-get total-projects-tracked))
      (total-rebuilds (var-get total-rebuilds-recorded))
    )
    (if (> total-projects u0)
      (var-set average-rebuild-frequency (/ total-rebuilds total-projects))
      (var-set average-rebuild-frequency u0)
    )
    (ok true)
  )
)

;; ============================================
;; Public Functions - Registration
;; ============================================

;; Register a new developer portfolio
(define-public (register-portfolio)
  (let
    (
      (caller tx-sender)
      (existing-portfolio (map-get? developer-portfolios caller))
    )
    (if (is-some existing-portfolio)
      ERR-ALREADY-EXISTS
      (begin
        (map-set developer-portfolios
          caller
          {
            total-projects: u0,
            total-rebuilds: u0,
            total-frameworks-tried: u0,
            most-rebuilt-project: "",
            registration-timestamp: stacks-block-height,
            last-rebuild-timestamp: stacks-block-height
          }
        )
        (var-set total-registered-developers (+ (var-get total-registered-developers) u1))
        (ok true)
      )
    )
  )
)

;; ============================================
;; Public Functions - Project Tracking
;; ============================================

;; Register a new project concept
(define-public (register-project-concept
  (project-id uint)
  (project-concept (string-ascii 100))
  (initial-framework (string-ascii 50))
)
  (let
    (
      (caller tx-sender)
      (portfolio-opt (map-get? developer-portfolios caller))
      (existing-project (map-get? project-concepts { developer: caller, project-id: project-id }))
    )
    (asserts! (is-some portfolio-opt) ERR-INVALID-DEVELOPER)
    (asserts! (is-none existing-project) ERR-ALREADY-EXISTS)
    (asserts! (> (len project-concept) u0) ERR-INVALID-INPUT)
    (asserts! (> (len initial-framework) u0) ERR-INVALID-INPUT)
    
    (let
      (
        (portfolio (unwrap-panic portfolio-opt))
        (new-project-count (+ (get total-projects portfolio) u1))
      )
      ;; Create project record
      (map-set project-concepts
        { developer: caller, project-id: project-id }
        {
          project-concept: project-concept,
          initial-framework: initial-framework,
          creation-timestamp: stacks-block-height,
          rebuild-count: u0,
          completion-status: "IN_PROGRESS",
          is-abandoned: false
        }
      )
      
      ;; Update portfolio
      (map-set developer-portfolios
        caller
        (merge portfolio { total-projects: new-project-count })
      )
      
      ;; Track framework usage
      (unwrap-panic (increment-framework-usage initial-framework))
      
      ;; Update global stats
      (var-set total-projects-tracked (+ (var-get total-projects-tracked) u1))
      
      (ok true)
    )
  )
)

;; Record a project rebuild
(define-public (record-rebuild
  (project-id uint)
  (rebuild-id uint)
  (new-framework (string-ascii 50))
  (reason (string-ascii 200))
  (days-since-last uint)
)
  (let
    (
      (caller tx-sender)
      (portfolio-opt (map-get? developer-portfolios caller))
      (project-opt (map-get? project-concepts { developer: caller, project-id: project-id }))
      (existing-rebuild (map-get? rebuilds { developer: caller, project-id: project-id, rebuild-id: rebuild-id }))
    )
    (asserts! (is-some portfolio-opt) ERR-INVALID-DEVELOPER)
    (asserts! (is-some project-opt) ERR-PROJECT-NOT-FOUND)
    (asserts! (is-none existing-rebuild) ERR-ALREADY-EXISTS)
    (asserts! (> (len new-framework) u0) ERR-INVALID-INPUT)
    
    (let
      (
        (portfolio (unwrap-panic portfolio-opt))
        (project (unwrap-panic project-opt))
        (new-rebuild-count (+ (get rebuild-count project) u1))
        (total-rebuilds (+ (get total-rebuilds portfolio) u1))
      )
      ;; Record rebuild instance
      (map-set rebuilds
        { developer: caller, project-id: project-id, rebuild-id: rebuild-id }
        {
          framework-used: new-framework,
          rebuild-timestamp: stacks-block-height,
          reason: reason,
          days-since-last-version: days-since-last
        }
      )
      
      ;; Update project record
      (map-set project-concepts
        { developer: caller, project-id: project-id }
        (merge project { rebuild-count: new-rebuild-count })
      )
      
      ;; Update portfolio
      (map-set developer-portfolios
        caller
        (merge portfolio {
          total-rebuilds: total-rebuilds,
          last-rebuild-timestamp: stacks-block-height
        })
      )
      
      ;; Track framework usage
      (unwrap-panic (increment-framework-usage new-framework))
      
      ;; Update global stats
      (var-set total-rebuilds-recorded (+ (var-get total-rebuilds-recorded) u1))
      (unwrap-panic (update-global-stats))
      
      (ok true)
    )
  )
)

;; Mark project as completed
(define-public (mark-project-completed (project-id uint))
  (let
    (
      (caller tx-sender)
      (project-opt (map-get? project-concepts { developer: caller, project-id: project-id }))
    )
    (asserts! (is-some project-opt) ERR-PROJECT-NOT-FOUND)
    
    (let
      (
        (project (unwrap-panic project-opt))
      )
      (map-set project-concepts
        { developer: caller, project-id: project-id }
        (merge project { completion-status: "COMPLETED" })
      )
      (ok true)
    )
  )
)

;; Mark project as abandoned
(define-public (mark-project-abandoned (project-id uint))
  (let
    (
      (caller tx-sender)
      (project-opt (map-get? project-concepts { developer: caller, project-id: project-id }))
    )
    (asserts! (is-some project-opt) ERR-PROJECT-NOT-FOUND)
    
    (let
      (
        (project (unwrap-panic project-opt))
      )
      (map-set project-concepts
        { developer: caller, project-id: project-id }
        (merge project {
          completion-status: "ABANDONED",
          is-abandoned: true
        })
      )
      (ok true)
    )
  )
)

;; ============================================
;; Public Functions - Queries
;; ============================================

;; Get developer portfolio information
(define-read-only (get-developer-portfolio (developer principal))
  (ok (map-get? developer-portfolios developer))
)

;; Get project concept information
(define-read-only (get-project-info (developer principal) (project-id uint))
  (ok (map-get? project-concepts { developer: developer, project-id: project-id }))
)

;; Get rebuild information
(define-read-only (get-rebuild-info (developer principal) (project-id uint) (rebuild-id uint))
  (ok (map-get? rebuilds { developer: developer, project-id: project-id, rebuild-id: rebuild-id }))
)

;; Get framework usage statistics
(define-read-only (get-framework-usage (framework (string-ascii 50)))
  (ok (default-to u0 (map-get? framework-usage framework)))
)

;; Calculate syndrome score for a developer
(define-read-only (get-syndrome-score (developer principal))
  (let
    (
      (portfolio-opt (map-get? developer-portfolios developer))
    )
    (if (is-some portfolio-opt)
      (let
        (
          (portfolio (unwrap-panic portfolio-opt))
          (total-rebuilds (get total-rebuilds portfolio))
          (total-projects (get total-projects portfolio))
        )
        (ok {
          total-rebuilds: total-rebuilds,
          total-projects: total-projects,
          average-rebuilds-per-project: (if (> total-projects u0) (/ total-rebuilds total-projects) u0),
          syndrome-level: (get-syndrome-level total-rebuilds)
        })
      )
      ERR-INVALID-DEVELOPER
    )
  )
)

;; Get global statistics
(define-read-only (get-global-statistics)
  (ok {
    total-developers: (var-get total-registered-developers),
    total-projects: (var-get total-projects-tracked),
    total-rebuilds: (var-get total-rebuilds-recorded),
    average-rebuild-frequency: (var-get average-rebuild-frequency)
  })
)

;; Check if developer has fresh start syndrome
(define-read-only (has-fresh-start-syndrome (developer principal))
  (let
    (
      (portfolio-opt (map-get? developer-portfolios developer))
    )
    (if (is-some portfolio-opt)
      (let
        (
          (portfolio (unwrap-panic portfolio-opt))
          (total-rebuilds (get total-rebuilds portfolio))
        )
        (ok (>= total-rebuilds MILD-SYNDROME))
      )
      (ok false)
    )
  )
)


