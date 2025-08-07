;; GeoNova - Location-Based NFT Minting Contract with Dynamic Pricing
;; Allows users to mint NFTs tied to real-world locations with variable pricing

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-minted (err u102))
(define-constant err-invalid-coordinates (err u103))
(define-constant err-cooldown-active (err u104))
(define-constant err-zone-not-active (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-insufficient-payment (err u107))
(define-constant err-invalid-pricing (err u108))
(define-constant err-transfer-failed (err u109))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var global-mint-cooldown uint u3600) ;; 1 hour in seconds
(define-data-var base-mint-price uint u1000000) ;; 1 STX in microSTX

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
    current-mints: uint,
    base-price: uint,
    popularity-multiplier: uint,
    time-based-pricing: bool,
    special-event-multiplier: uint
  }
)

(define-map zone-pricing-tiers
  { zone-id: uint, tier: uint }
  {
    mint-threshold: uint,
    price-multiplier: uint
  }
)

(define-map time-based-pricing
  { zone-id: uint, hour: uint }
  {
    multiplier: uint
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
    metadata-uri: (string-ascii 256),
    mint-price: uint
  }
)

(define-map user-last-mint-time
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
  (match (map-get? user-last-mint-time { user: user })
    last-mint-data 
    (let ((time-diff (- stacks-block-height (get timestamp last-mint-data))))
      (>= time-diff (var-get global-mint-cooldown)))
    true
  )
)

(define-private (get-hour-from-timestamp (timestamp uint))
  (mod (/ timestamp u3600) u24)
)

(define-private (calculate-popularity-multiplier (zone-id uint) (current-mints uint))
  (let (
    (tier-1 (map-get? zone-pricing-tiers { zone-id: zone-id, tier: u1 }))
    (tier-2 (map-get? zone-pricing-tiers { zone-id: zone-id, tier: u2 }))
    (tier-3 (map-get? zone-pricing-tiers { zone-id: zone-id, tier: u3 }))
  )
    (if (and (is-some tier-3) (>= current-mints (get mint-threshold (unwrap-panic tier-3))))
      (get price-multiplier (unwrap-panic tier-3))
      (if (and (is-some tier-2) (>= current-mints (get mint-threshold (unwrap-panic tier-2))))
        (get price-multiplier (unwrap-panic tier-2))
        (if (and (is-some tier-1) (>= current-mints (get mint-threshold (unwrap-panic tier-1))))
          (get price-multiplier (unwrap-panic tier-1))
          u100 ;; Default 1.0x multiplier (100 = 100%)
        )
      )
    )
  )
)

(define-private (calculate-time-multiplier (zone-id uint) (timestamp uint))
  (let (
    (hour (get-hour-from-timestamp timestamp))
    (time-pricing-data (map-get? time-based-pricing { zone-id: zone-id, hour: hour }))
  )
    (match time-pricing-data
      pricing-data (get multiplier pricing-data)
      u100 ;; Default 1.0x multiplier
    )
  )
)

(define-private (calculate-mint-price (zone-id uint))
  (match (map-get? mintable-zones { zone-id: zone-id })
    zone-data
    (let (
      (base-price (get base-price zone-data))
      (popularity-mult (calculate-popularity-multiplier zone-id (get current-mints zone-data)))
      (time-mult (if (get time-based-pricing zone-data)
                    (calculate-time-multiplier zone-id stacks-block-height)
                    u100))
      (event-mult (get special-event-multiplier zone-data))
      (final-mult (/ (* (* popularity-mult time-mult) event-mult) u10000))
    )
      (/ (* base-price final-mult) u100)
    )
    u0
  )
)

;; Public Functions

;; Add a new mintable zone with pricing parameters (owner only)
(define-public (add-mintable-zone 
  (zone-id uint) 
  (name (string-ascii 64)) 
  (latitude int) 
  (longitude int) 
  (radius uint)
  (max-mints uint)
  (base-price uint)
  (popularity-multiplier uint)
  (enable-time-pricing bool)
  (special-event-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (> (len name) u0) err-invalid-coordinates)
    (asserts! (> radius u0) err-invalid-coordinates)
    (asserts! (> max-mints u0) err-invalid-coordinates)
    (asserts! (> base-price u0) err-invalid-pricing)
    (asserts! (> popularity-multiplier u0) err-invalid-pricing)
    (asserts! (> special-event-multiplier u0) err-invalid-pricing)
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
        current-mints: u0,
        base-price: base-price,
        popularity-multiplier: popularity-multiplier,
        time-based-pricing: enable-time-pricing,
        special-event-multiplier: special-event-multiplier
      }
    ))
  )
)

;; Set pricing tiers for popularity-based pricing (owner only)
(define-public (set-pricing-tier 
  (zone-id uint) 
  (tier uint) 
  (mint-threshold uint) 
  (price-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (and (> tier u0) (<= tier u3)) err-invalid-pricing)
    (asserts! (> mint-threshold u0) err-invalid-pricing)
    (asserts! (<= mint-threshold u1000000) err-invalid-pricing) ;; Max 1M mints per tier
    (asserts! (> price-multiplier u0) err-invalid-pricing)
    (asserts! (<= price-multiplier u1000) err-invalid-pricing) ;; Max 10x multiplier
    (asserts! (is-some (map-get? mintable-zones { zone-id: zone-id })) err-not-found)
    (ok (map-set zone-pricing-tiers
      { zone-id: zone-id, tier: tier }
      {
        mint-threshold: mint-threshold,
        price-multiplier: price-multiplier
      }
    ))
  )
)

;; Set time-based pricing multiplier (owner only)
(define-public (set-time-based-pricing 
  (zone-id uint) 
  (hour uint) 
  (multiplier uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (< hour u24) err-invalid-pricing)
    (asserts! (> multiplier u0) err-invalid-pricing)
    (asserts! (<= multiplier u1000) err-invalid-pricing) ;; Max 10x multiplier
    (asserts! (is-some (map-get? mintable-zones { zone-id: zone-id })) err-not-found)
    (ok (map-set time-based-pricing
      { zone-id: zone-id, hour: hour }
      { multiplier: multiplier }
    ))
  )
)

;; Update special event multiplier (owner only)
(define-public (set-special-event-multiplier (zone-id uint) (multiplier uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (> multiplier u0) err-invalid-pricing)
    (asserts! (<= multiplier u1000) err-invalid-pricing) ;; Max 10x multiplier
    (match (map-get? mintable-zones { zone-id: zone-id })
      zone-data
      (ok (map-set mintable-zones
        { zone-id: zone-id }
        (merge zone-data { special-event-multiplier: multiplier })
      ))
      err-not-found
    )
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

;; Mint location-based NFT with dynamic pricing
(define-public (mint-location-nft 
  (zone-id uint) 
  (user-latitude int) 
  (user-longitude int)
  (metadata-uri (string-ascii 256)))
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (current-block stacks-block-height)
    (mint-price (calculate-mint-price zone-id))
  )
    (asserts! (> zone-id u0) err-invalid-coordinates)
    (asserts! (> (len metadata-uri) u0) err-invalid-coordinates)
    (asserts! (validate-coordinates user-latitude user-longitude) err-invalid-coordinates)
    (asserts! (check-cooldown tx-sender) err-cooldown-active)
    (asserts! (> mint-price u0) err-invalid-pricing)
    
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
        
        ;; Transfer STX payment to contract owner
        (match (stx-transfer? mint-price tx-sender contract-owner)
          success-transfer
          (begin
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
            (map-set user-last-mint-time
              { user: tx-sender }
              { timestamp: current-block }
            )
            
            ;; Create NFT record with mint price
            (map-set location-nfts
              { token-id: token-id }
              {
                owner: tx-sender,
                zone-id: zone-id,
                mint-timestamp: current-block,
                latitude: user-latitude,
                longitude: user-longitude,
                metadata-uri: metadata-uri,
                mint-price: mint-price
              }
            )
            
            ;; Update token ID counter
            (var-set last-token-id token-id)
            (ok token-id)
          )
          transfer-error
          (err transfer-error)
        )
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

;; Update base mint price (owner only)
(define-public (set-base-mint-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-price u0) err-invalid-pricing)
    (asserts! (<= new-price u1000000000000) err-invalid-pricing) ;; Max 1M STX
    (ok (var-set base-mint-price new-price))
  )
)

;; Read-only functions

;; Get current mint price for a zone
(define-read-only (get-current-mint-price (zone-id uint))
  (begin
    (asserts! (> zone-id u0) (err u999))
    (ok (calculate-mint-price zone-id))
  )
)

;; Get zone information
(define-read-only (get-zone-info (zone-id uint))
  (begin
    (asserts! (> zone-id u0) (err u999))
    (ok (map-get? mintable-zones { zone-id: zone-id }))
  )
)

;; Get pricing tier information
(define-read-only (get-pricing-tier (zone-id uint) (tier uint))
  (begin
    (asserts! (> zone-id u0) (err u999))
    (asserts! (and (> tier u0) (<= tier u3)) (err u999))
    (ok (map-get? zone-pricing-tiers { zone-id: zone-id, tier: tier }))
  )
)

;; Get time-based pricing for specific hour
(define-read-only (get-time-pricing (zone-id uint) (hour uint))
  (begin
    (asserts! (> zone-id u0) (err u999))
    (asserts! (< hour u24) (err u999))
    (ok (map-get? time-based-pricing { zone-id: zone-id, hour: hour }))
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
  (map-get? user-last-mint-time { user: user })
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

;; Get base mint price
(define-read-only (get-base-mint-price)
  (var-get base-mint-price)
)