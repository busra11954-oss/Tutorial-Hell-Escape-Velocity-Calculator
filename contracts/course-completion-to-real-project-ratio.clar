;; Course Completion to Real Project Ratio Contract
;; Tracks the relationship between courses/tutorials completed and actual projects deployed
;; Helps developers identify if they're stuck in "tutorial hell"

;; ============================================
;; Constants
;; ============================================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-DEVELOPER (err u101))
(define-constant ERR-INVALID-COURSE-ID (err u102))
(define-constant ERR-INVALID-PROJECT-ID (err u103))
(define-constant ERR-COURSE-NOT-FOUND (err u104))
(define-constant ERR-PROJECT-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-EXISTS (err u106))
(define-constant ERR-INVALID-INPUT (err u107))
(define-constant ERR-DIVISION-BY-ZERO (err u108))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Thresholds for warning levels
(define-constant WARNING-RATIO u15)  ;; 15:1 ratio triggers warning
(define-constant DANGER-RATIO u20)   ;; 20:1 ratio triggers danger alert
(define-constant HEALTHY-RATIO u10)  ;; 10:1 or better is healthy

;; ============================================
;; Data Maps and Variables
;; ============================================

;; Track developer profiles with course and project counts
(define-map developer-profiles
  principal
  {
    total-courses: uint,
    total-projects: uint,
    last-course-timestamp: uint,
    last-project-timestamp: uint,
    registration-timestamp: uint
  }
)

;; Individual course records
(define-map courses
  { developer: principal, course-id: uint }
  {
    course-name: (string-ascii 100),
    completion-timestamp: uint,
    platform: (string-ascii 50),
    is-certified: bool
  }
)

;; Individual project records
(define-map projects
  { developer: principal, project-id: uint }
  {
    project-name: (string-ascii 100),
    deployment-timestamp: uint,
    repository-url: (string-ascii 200),
    is-live: bool
  }
)

;; Global statistics
(define-data-var total-registered-developers uint u0)
(define-data-var total-courses-recorded uint u0)
(define-data-var total-projects-recorded uint u0)
(define-data-var global-average-ratio uint u0)

;; ============================================
;; Private Helper Functions
;; ============================================

;; Calculate ratio with safe division
(define-private (calculate-ratio (course-count uint) (project-count uint))
  (if (is-eq project-count u0)
    (ok u0)  ;; Return 0 if no projects to avoid division by zero
    (ok (/ course-count project-count))
  )
)

;; Determine warning level based on ratio
(define-private (get-warning-level (ratio uint))
  (if (>= ratio DANGER-RATIO)
    "DANGER"
    (if (>= ratio WARNING-RATIO)
      "WARNING"
      (if (<= ratio HEALTHY-RATIO)
        "HEALTHY"
        "MODERATE"
      )
    )
  )
)

;; Update global statistics
(define-private (update-global-stats)
  (let
    (
      (total-devs (var-get total-registered-developers))
      (total-courses (var-get total-courses-recorded))
      (total-projects (var-get total-projects-recorded))
    )
    (if (> total-projects u0)
      (var-set global-average-ratio (/ total-courses total-projects))
      (var-set global-average-ratio u0)
    )
    (ok true)
  )
)

;; ============================================
;; Public Functions - Registration
;; ============================================

;; Register a new developer profile
(define-public (register-developer)
  (let
    (
      (caller tx-sender)
      (existing-profile (map-get? developer-profiles caller))
    )
    (if (is-some existing-profile)
      ERR-ALREADY-EXISTS
      (begin
        (map-set developer-profiles
          caller
          {
            total-courses: u0,
            total-projects: u0,
            last-course-timestamp: stacks-block-height,
            last-project-timestamp: stacks-block-height,
            registration-timestamp: stacks-block-height
          }
        )
        (var-set total-registered-developers (+ (var-get total-registered-developers) u1))
        (ok true)
      )
    )
  )
)

;; ============================================
;; Public Functions - Course Recording
;; ============================================

;; Record a completed course
(define-public (record-course-completion
  (course-id uint)
  (course-name (string-ascii 100))
  (platform (string-ascii 50))
  (is-certified bool)
)
  (let
    (
      (caller tx-sender)
      (profile-opt (map-get? developer-profiles caller))
      (existing-course (map-get? courses { developer: caller, course-id: course-id }))
    )
    (asserts! (is-some profile-opt) ERR-INVALID-DEVELOPER)
    (asserts! (is-none existing-course) ERR-ALREADY-EXISTS)
    (asserts! (> (len course-name) u0) ERR-INVALID-INPUT)
    
    (let
      (
        (profile (unwrap-panic profile-opt))
        (new-course-count (+ (get total-courses profile) u1))
      )
      ;; Update course record
      (map-set courses
        { developer: caller, course-id: course-id }
        {
          course-name: course-name,
          completion-timestamp: stacks-block-height,
          platform: platform,
          is-certified: is-certified
        }
      )
      
      ;; Update developer profile
      (map-set developer-profiles
        caller
        (merge profile {
          total-courses: new-course-count,
          last-course-timestamp: stacks-block-height
        })
      )
      
      ;; Update global stats
      (var-set total-courses-recorded (+ (var-get total-courses-recorded) u1))
      (unwrap-panic (update-global-stats))
      
      (ok true)
    )
  )
)

;; ============================================
;; Public Functions - Project Recording
;; ============================================

;; Record a deployed project
(define-public (record-project-deployment
  (project-id uint)
  (project-name (string-ascii 100))
  (repository-url (string-ascii 200))
  (is-live bool)
)
  (let
    (
      (caller tx-sender)
      (profile-opt (map-get? developer-profiles caller))
      (existing-project (map-get? projects { developer: caller, project-id: project-id }))
    )
    (asserts! (is-some profile-opt) ERR-INVALID-DEVELOPER)
    (asserts! (is-none existing-project) ERR-ALREADY-EXISTS)
    (asserts! (> (len project-name) u0) ERR-INVALID-INPUT)
    
    (let
      (
        (profile (unwrap-panic profile-opt))
        (new-project-count (+ (get total-projects profile) u1))
      )
      ;; Update project record
      (map-set projects
        { developer: caller, project-id: project-id }
        {
          project-name: project-name,
          deployment-timestamp: stacks-block-height,
          repository-url: repository-url,
          is-live: is-live
        }
      )
      
      ;; Update developer profile
      (map-set developer-profiles
        caller
        (merge profile {
          total-projects: new-project-count,
          last-project-timestamp: stacks-block-height
        })
      )
      
      ;; Update global stats
      (var-set total-projects-recorded (+ (var-get total-projects-recorded) u1))
      (unwrap-panic (update-global-stats))
      
      (ok true)
    )
  )
)

;; ============================================
;; Public Functions - Queries
;; ============================================

;; Get developer profile information
(define-read-only (get-developer-profile (developer principal))
  (ok (map-get? developer-profiles developer))
)

;; Get course information
(define-read-only (get-course-info (developer principal) (course-id uint))
  (ok (map-get? courses { developer: developer, course-id: course-id }))
)

;; Get project information
(define-read-only (get-project-info (developer principal) (project-id uint))
  (ok (map-get? projects { developer: developer, project-id: project-id }))
)

;; Calculate and return developer's current ratio
(define-read-only (get-developer-ratio (developer principal))
  (let
    (
      (profile-opt (map-get? developer-profiles developer))
    )
    (if (is-some profile-opt)
      (let
        (
          (profile (unwrap-panic profile-opt))
          (course-count (get total-courses profile))
          (project-count (get total-projects profile))
        )
        (if (is-eq project-count u0)
          (ok { ratio: u0, courses: course-count, projects: project-count, warning-level: "UNTRACKED" })
          (let
            (
              (ratio (/ course-count project-count))
            )
            (ok {
              ratio: ratio,
              courses: course-count,
              projects: project-count,
              warning-level: (get-warning-level ratio)
            })
          )
        )
      )
      ERR-INVALID-DEVELOPER
    )
  )
)

;; Get global statistics
(define-read-only (get-global-statistics)
  (ok {
    total-developers: (var-get total-registered-developers),
    total-courses: (var-get total-courses-recorded),
    total-projects: (var-get total-projects-recorded),
    global-average-ratio: (var-get global-average-ratio)
  })
)

;; Check if developer is in tutorial hell (ratio above warning threshold)
(define-read-only (is-in-tutorial-hell (developer principal))
  (let
    (
      (ratio-result (get-developer-ratio developer))
    )
    (match ratio-result
      success-data
        (let
          (
            (ratio (get ratio success-data))
          )
          (ok (>= ratio WARNING-RATIO))
        )
      error-val
        (ok false)
    )
  )
)


