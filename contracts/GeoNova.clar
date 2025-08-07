;; GeoNova - Location-Based NFT Minting Contract
;; Allows users to mint NFTs tied to real-world locations and timestamps

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-minted (err u102))
(define-constant err-invalid-coordinates (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant err-zone-not-active (err u105))
(define-constant err-unauthorized (err u106))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var global-mint-cooldown uint u3600) ;; 1 hour in seconds

;; Data Maps
(define-map mintable-zones
  { zone-id: uint }
  {
    name: (string-ascii 64),
    latitude: int,
    longitude: int,
    radius: uint,
    active: bool,
    max-mints: uint,
    current-mints: uint
  }
)

(define-map location-nfts
  { token-id: uint }
  {
    owner: principal,
    zone-id: uint,
    mint-timestamp: uint,
    latitude: int,
    longitude: int,
    metadata-uri: (string-ascii 256)
  }
)

(define-map user-last-mint
  { user: principal }
  { timestamp: uint }
)

(define-map zone-user-mints
  { zone-id: uint, user: principal }
  { minted: bool }
)

;; Private Functions
(define-private (is-within-radius (lat1 int) (lon1 int) (lat2 int) (lon2 int) (radius uint))
  (let (
    (lat-diff (if (>= lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
    (lon-diff (if (>= lon1 lon2) (- lon1 lon2) (- lon2 lon1)))
    (distance-squared (+ (* lat-diff lat-diff) (* lon-diff lon-diff)))
    (radius-squared (* (to-int radius) (to-int radius)))
  )
    (<= distance-squared radius-squared)
  )
)

(define-private (validate-coordinates (latitude int) (longitude int))
  (and 
    (and (>= latitude -900000000) (<= latitude 900000000))
    (and (>= longitude -1800000000) (<= longitude 1800000000))
  )
)

(define-private (check-cooldown (user principal))
  (match (map-get? user-last-mint { user: user })
    last-mint-data 
    (let ((time-diff (- stacks-block-height (get timestamp last-mint-data))))
      (>= time-diff (var-get global-mint-cooldown)))
    true
  )
)

;; Public Functions

;; Add a new mintable zone (owner only)
(define-public (add-mintable-zone 
  (zone-id uint) 
  (name (string-ascii 64)) 
  (latitude int) 
  (longitude int) 
  (radius uint)
  (max-mints uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (> (len name) u0) err-invalid-coordinates)
    (asserts! (> radius u0) err-invalid-coordinates)
    (asserts! (> max-mints u0) err-invalid-coordinates)
    (asserts! (validate-coordinates latitude longitude) err-invalid-coordinates)
    (asserts! (is-none (map-get? mintable-zones { zone-id: zone-id })) err-already-minted)
    (ok (map-set mintable-zones
      { zone-id: zone-id }
      {
        name: name,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        active: true,
        max-mints: max-mints,
        current-mints: u0
      }
    ))
  )
)

;; Toggle zone active status (owner only)
(define-public (toggle-zone-status (zone-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (match (map-get? mintable-zones { zone-id: zone-id })
      zone-data
      (ok (map-set mintable-zones
        { zone-id: zone-id }
        (merge zone-data { active: (not (get active zone-data)) })
      ))
      err-not-found
    )
  )
)

;; Mint location-based NFT
(define-public (mint-location-nft 
  (zone-id uint) 
  (user-latitude int) 
  (user-longitude int)
  (metadata-uri (string-ascii 256)))
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (current-block stacks-block-height)
  )
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (> (len metadata-uri) u0) err-invalid-coordinates)
    (asserts! (validate-coordinates user-latitude user-longitude) err-invalid-coordinates)
    (asserts! (check-cooldown tx-sender) err-cooldown-active)
    
    (match (map-get? mintable-zones { zone-id: zone-id })
      zone-data
      (begin
        (asserts! (get active zone-data) err-zone-not-active)
        (asserts! (< (get current-mints zone-data) (get max-mints zone-data)) err-already-minted)
        (asserts! 
          (is-within-radius 
            user-latitude user-longitude 
            (get latitude zone-data) (get longitude zone-data) 
            (get radius zone-data)
          ) 
          err-invalid-coordinates
        )
        (asserts! 
          (is-none (map-get? zone-user-mints { zone-id: zone-id, user: tx-sender }))
          err-already-minted
        )
        
        ;; Update zone mint count
        (map-set mintable-zones
          { zone-id: zone-id }
          (merge zone-data { current-mints: (+ (get current-mints zone-data) u1) })
        )
        
        ;; Record user mint for this zone
        (map-set zone-user-mints
          { zone-id: zone-id, user: tx-sender }
          { minted: true }
        )
        
        ;; Update user last mint timestamp
        (map-set user-last-mint
          { user: tx-sender }
          { timestamp: current-block }
        )
        
        ;; Create NFT record
        (map-set location-nfts
          { token-id: token-id }
          {
            owner: tx-sender,
            zone-id: zone-id,
            mint-timestamp: current-block,
            latitude: user-latitude,
            longitude: user-longitude,
            metadata-uri: metadata-uri
          }
        )
        
        ;; Update token ID counter
        (var-set last-token-id token-id)
        (ok token-id)
      )
      err-not-found
    )
  )
)

;; Update mint cooldown (owner only)
(define-public (set-mint-cooldown (new-cooldown uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-cooldown u0) err-invalid-coordinates)
    (asserts! (<= new-cooldown u86400) err-invalid-coordinates) ;; Max 24 hours
    (ok (var-set global-mint-cooldown new-cooldown))
  )
)

;; Read-only functions

;; Get zone information
(define-read-only (get-zone-info (zone-id uint))
  (begin
    (asserts! (> zone-id u0) (err u999))
    (ok (map-get? mintable-zones { zone-id: zone-id }))
  )
)

;; Get NFT information
(define-read-only (get-nft-info (token-id uint))
  (begin
    (asserts! (> token-id u0) (err u999))
    (ok (map-get? location-nfts { token-id: token-id }))
  )
)

;; Get user's last mint timestamp
(define-read-only (get-user-last-mint (user principal))
  (map-get? user-last-mint { user: user })
)

;; Check if user can mint (cooldown check)
(define-read-only (can-user-mint (user principal))
  (check-cooldown user)
)

;; Check if user has already minted in a zone
(define-read-only (has-user-minted-in-zone (zone-id uint) (user principal))
  (begin
    (asserts! (> zone-id u0) (err u999))
    (ok (is-some (map-get? zone-user-mints { zone-id: zone-id, user: user })))
  )
)

;; Get current token ID
(define-read-only (get-last-token-id)
  (var-get last-token-id)
)

;; Get current mint cooldown
(define-read-only (get-mint-cooldown)
  (var-get global-mint-cooldown)
)