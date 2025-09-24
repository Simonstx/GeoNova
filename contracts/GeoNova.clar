;; GeoNova - Location-Based NFT Minting Contract with Dynamic Pricing and Multi-Signature Governance
;; Allows users to mint NFTs tied to real-world locations with variable pricing and community governance

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
(define-constant err-proposal-not-found (err u110))
(define-constant err-proposal-already-signed (err u111))
(define-constant err-proposal-not-approved (err u112))
(define-constant err-proposal-already-executed (err u113))
(define-constant err-invalid-threshold (err u114))
(define-constant err-signer-already-exists (err u115))
(define-constant err-signer-not-found (err u116))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var last-proposal-id uint u0)
(define-data-var global-mint-cooldown uint u3600) ;; 1 hour in seconds
(define-data-var base-mint-price uint u1000000) ;; 1 STX in microSTX
(define-data-var signature-threshold uint u1) ;; Default single signature required

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

;; Multi-signature governance maps
(define-map authorized-signers
  { signer: principal }
  { active: bool }
)

(define-map zone-proposals
  { proposal-id: uint }
  {
    zone-id: uint,
    name: (string-ascii 64),
    latitude: int,
    longitude: int,
    radius: uint,
    max-mints: uint,
    base-price: uint,
    popularity-multiplier: uint,
    time-based-pricing: bool,
    special-event-multiplier: uint,
    signatures-count: uint,
    executed: bool,
    proposer: principal,
    created-at: uint
  }
)

(define-map proposal-signatures
  { proposal-id: uint, signer: principal }
  { signed: bool }
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

(define-private (is-authorized-signer-internal (signer principal))
  (match (map-get? authorized-signers { signer: signer })
    signer-data (get active signer-data)
    false
  )
)

(define-private (validate-zone-proposal-params 
  (zone-id uint)
  (name (string-ascii 64))
  (latitude int)
  (longitude int)
  (radius uint)
  (max-mints uint)
  (base-price uint)
  (popularity-multiplier uint)
  (special-event-multiplier uint))
  (and
    (> zone-id u0)
    (> (len name) u0)
    (<= (len name) u64)
    (validate-coordinates latitude longitude)
    (> radius u0)
    (<= radius u100000) ;; Max 100km radius
    (> max-mints u0)
    (<= max-mints u1000000) ;; Max 1M mints
    (> base-price u0)
    (<= base-price u1000000000000) ;; Max 1M STX
    (> popularity-multiplier u0)
    (<= popularity-multiplier u1000) ;; Max 10x multiplier
    (> special-event-multiplier u0)
    (<= special-event-multiplier u1000) ;; Max 10x multiplier
  )
)

(define-private (increment-proposal-id)
  (let ((current-id (var-get last-proposal-id)))
    (var-set last-proposal-id (+ current-id u1))
    (+ current-id u1)
  )
)

;; Multi-signature governance functions

;; Add authorized signer (owner only)
(define-public (add-authorized-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq signer contract-owner)) err-invalid-coordinates) ;; Owner is implicitly authorized
    (asserts! (is-none (map-get? authorized-signers { signer: signer })) err-signer-already-exists)
    (ok (map-set authorized-signers
      { signer: signer }
      { active: true }
    ))
  )
)

;; Remove authorized signer (owner only)
(define-public (remove-authorized-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq signer contract-owner)) err-invalid-coordinates) ;; Cannot remove owner
    (asserts! (is-some (map-get? authorized-signers { signer: signer })) err-signer-not-found)
    (ok (map-set authorized-signers
      { signer: signer }
      { active: false }
    ))
  )
)

;; Set signature threshold (owner only)
(define-public (set-signature-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> threshold u0) err-invalid-threshold)
    (asserts! (<= threshold u10) err-invalid-threshold) ;; Max 10 signers
    (ok (var-set signature-threshold threshold))
  )
)

;; Create zone proposal with auto-increment ID (authorized signers or owner)
(define-public (create-zone-proposal
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
  (let ((proposal-id (increment-proposal-id)))
    (begin
      (asserts! 
        (or (is-eq tx-sender contract-owner) (is-authorized-signer-internal tx-sender))
        err-unauthorized
      )
      (asserts! (is-none (map-get? mintable-zones { zone-id: zone-id })) err-already-minted)
      (asserts! 
        (validate-zone-proposal-params 
          zone-id name latitude longitude radius max-mints 
          base-price popularity-multiplier special-event-multiplier)
        err-invalid-coordinates
      )
      
      (map-set zone-proposals
        { proposal-id: proposal-id }
        {
          zone-id: zone-id,
          name: name,
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          max-mints: max-mints,
          base-price: base-price,
          popularity-multiplier: popularity-multiplier,
          time-based-pricing: enable-time-pricing,
          special-event-multiplier: special-event-multiplier,
          signatures-count: u0,
          executed: false,
          proposer: tx-sender,
          created-at: stacks-block-height
        }
      )
      (ok proposal-id)
    )
  )
)

;; Propose zone creation with manual proposal ID (authorized signers or owner)
(define-public (propose-zone-creation
  (proposal-id uint)
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
    (asserts! 
      (or (is-eq tx-sender contract-owner) (is-authorized-signer-internal tx-sender))
      err-unauthorized
    )
    (asserts! (> proposal-id u0) err-invalid-coordinates)
    (asserts! (is-none (map-get? zone-proposals { proposal-id: proposal-id })) err-already-minted)
    (asserts! (is-none (map-get? mintable-zones { zone-id: zone-id })) err-already-minted)
    (asserts! 
      (validate-zone-proposal-params 
        zone-id name latitude longitude radius max-mints 
        base-price popularity-multiplier special-event-multiplier)
      err-invalid-coordinates
    )
    
    (ok (map-set zone-proposals
      { proposal-id: proposal-id }
      {
        zone-id: zone-id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        max-mints: max-mints,
        base-price: base-price,
        popularity-multiplier: popularity-multiplier,
        time-based-pricing: enable-time-pricing,
        special-event-multiplier: special-event-multiplier,
        signatures-count: u0,
        executed: false,
        proposer: tx-sender,
        created-at: stacks-block-height
      }
    ))
  )
)

;; Sign zone proposal (authorized signers or owner)
(define-public (sign-zone-proposal (proposal-id uint))
  (begin
    (asserts! 
      (or (is-eq tx-sender contract-owner) (is-authorized-signer-internal tx-sender))
      err-unauthorized
    )
    (asserts! (> proposal-id u0) err-invalid-coordinates)
    (match (map-get? zone-proposals { proposal-id: proposal-id })
      proposal-data
      (begin
        (asserts! (not (get executed proposal-data)) err-proposal-already-executed)
        (asserts! 
          (is-none (map-get? proposal-signatures { proposal-id: proposal-id, signer: tx-sender }))
          err-proposal-already-signed
        )
        
        ;; Record signature
        (map-set proposal-signatures
          { proposal-id: proposal-id, signer: tx-sender }
          { signed: true }
        )
        
        ;; Update signature count
        (ok (map-set zone-proposals
          { proposal-id: proposal-id }
          (merge proposal-data { signatures-count: (+ (get signatures-count proposal-data) u1) })
        ))
      )
      err-proposal-not-found
    )
  )
)

;; Execute approved zone proposal (anyone can trigger)
(define-public (execute-zone-proposal (proposal-id uint))
  (begin
    (asserts! (> proposal-id u0) err-invalid-coordinates)
    (match (map-get? zone-proposals { proposal-id: proposal-id })
      proposal-data
      (begin
        (asserts! (not (get executed proposal-data)) err-proposal-already-executed)
        (asserts! 
          (>= (get signatures-count proposal-data) (var-get signature-threshold))
          err-proposal-not-approved
        )
        (asserts! 
          (is-none (map-get? mintable-zones { zone-id: (get zone-id proposal-data) }))
          err-already-minted
        )
        
        ;; Create the zone
        (map-set mintable-zones
          { zone-id: (get zone-id proposal-data) }
          {
            name: (get name proposal-data),
            latitude: (get latitude proposal-data),
            longitude: (get longitude proposal-data),
            radius: (get radius proposal-data),
            active: true,
            max-mints: (get max-mints proposal-data),
            current-mints: u0,
            base-price: (get base-price proposal-data),
            popularity-multiplier: (get popularity-multiplier proposal-data),
            time-based-pricing: (get time-based-pricing proposal-data),
            special-event-multiplier: (get special-event-multiplier proposal-data)
          }
        )
        
        ;; Mark proposal as executed
        (ok (map-set zone-proposals
          { proposal-id: proposal-id }
          (merge proposal-data { executed: true })
        ))
      )
      err-proposal-not-found
    )
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
    (asserts! 
      (validate-zone-proposal-params 
        zone-id name latitude longitude radius max-mints 
        base-price popularity-multiplier special-event-multiplier)
      err-invalid-coordinates
    )
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
    (asserts! (<= (len metadata-uri) u256) err-invalid-coordinates)
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
          err-transfer-failed
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

;; Multi-signature governance read-only functions

;; Check if principal is authorized signer
(define-read-only (is-authorized-signer (signer principal))
  (is-authorized-signer-internal signer)
)

;; Get signature threshold
(define-read-only (get-signature-threshold)
  (var-get signature-threshold)
)

;; Get zone proposal details
(define-read-only (get-zone-proposal (proposal-id uint))
  (begin
    (asserts! (> proposal-id u0) (err u999))
    (ok (map-get? zone-proposals { proposal-id: proposal-id }))
  )
)

;; Check if signer has signed proposal
(define-read-only (has-signed-proposal (proposal-id uint) (signer principal))
  (begin
    (asserts! (> proposal-id u0) (err u999))
    (ok (is-some (map-get? proposal-signatures { proposal-id: proposal-id, signer: signer })))
  )
)

;; Get last proposal ID
(define-read-only (get-last-proposal-id)
  (var-get last-proposal-id)
)

;; Get authorized signer status
(define-read-only (get-signer-status (signer principal))
  (map-get? authorized-signers { signer: signer })
)

;; Check if proposal meets signature threshold
(define-read-only (is-proposal-approved (proposal-id uint))
  (begin
    (asserts! (> proposal-id u0) (err u999))
    (match (map-get? zone-proposals { proposal-id: proposal-id })
      proposal-data
      (ok (>= (get signatures-count proposal-data) (var-get signature-threshold)))
      (ok false)
    )
  )
)

;; Get proposal execution status
(define-read-only (is-proposal-executed (proposal-id uint))
  (begin
    (asserts! (> proposal-id u0) (err u999))
    (match (map-get? zone-proposals { proposal-id: proposal-id })
      proposal-data
      (ok (get executed proposal-data))
      (ok false)
    )
  )
)

;; Contract information helper
(define-read-only (get-contract-info)
  {
    owner: contract-owner,
    last-token-id: (var-get last-token-id),
    last-proposal-id: (var-get last-proposal-id),
    signature-threshold: (var-get signature-threshold),
    global-mint-cooldown: (var-get global-mint-cooldown),
    base-mint-price: (var-get base-mint-price)
  }
)