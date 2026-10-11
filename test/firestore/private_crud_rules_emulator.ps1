$ErrorActionPreference = 'Stop'

# This suite uses isolated emulator users and documents, never a live backend.
$projectId = if ($env:GCLOUD_PROJECT) { $env:GCLOUD_PROJECT } else { 'minhascompras-3abbe' }
$firestoreHost = if ($env:FIRESTORE_EMULATOR_HOST) { $env:FIRESTORE_EMULATOR_HOST } else { '127.0.0.1:8080' }
$authHost = if ($env:FIREBASE_AUTH_EMULATOR_HOST) { $env:FIREBASE_AUTH_EMULATOR_HOST } else { '127.0.0.1:9099' }
foreach ($endpoint in @($firestoreHost, $authHost)) {
  if ($endpoint -notmatch '^(127\.0\.0\.1|localhost):\d+$') {
    throw "Only loopback emulator endpoints are permitted: $endpoint"
  }
}
$documentsUrl = "http://$firestoreHost/v1/projects/$projectId/databases/(default)/documents"
$script:passed = 0

function Request-Json {
  param([string]$Method, [string]$Uri, [object]$Body, [string]$Token)
  $parameters = @{ Method = $Method; Uri = $Uri; SkipHttpErrorCheck = $true }
  if ($Token) { $parameters.Headers = @{ Authorization = "Bearer $Token" } }
  if ($null -ne $Body) {
    $parameters.ContentType = 'application/json'
    $parameters.Body = ConvertTo-Json -InputObject $Body -Depth 30 -Compress
  }
  Invoke-WebRequest @parameters
}

function Assert-Response {
  param($Response, [int[]]$Expected, [string]$Case)
  if ([int]$Response.StatusCode -notin $Expected) {
    throw "$Case returned HTTP $($Response.StatusCode): $($Response.Content)"
  }
  $script:passed++
  Write-Host "PASS [$($Response.StatusCode)] $Case"
}

function New-EmulatorUser {
  param([string]$Alias)
  $response = Request-Json -Method POST `
    -Uri "http://$authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key" `
    -Body @{ email = "$Alias-$(New-Guid)@example.test"; password = 'Emulator-only-password-123!'; returnSecureToken = $true }
  Assert-Response $response @(200) "create isolated $Alias user"
  $user = ConvertFrom-Json $response.Content
  @{ uid = $user.localId; token = $user.idToken }
}

function String-Field { param([string]$Value) @{ stringValue = $Value } }
function Null-Field { @{ nullValue = $null } }
function Array-Field { @{ arrayValue = @{ values = @() } } }

function New-EntityFields {
  param([string]$Type, [string]$Id, [string]$Name)
  $date = @{ timestampValue = '2026-10-11T17:00:00.000Z' }
  $fields = @{ id = String-Field $Id }
  switch ($Type) {
    lists {
      $fields.name = String-Field $Name
      $fields.createdAt = $date
      $fields.updatedAt = $date
      $fields.items = Array-Field
      $fields.budget = Null-Field
      $fields.reminder = Null-Field
      $fields.paymentBalances = Array-Field
      $fields.isClosed = @{ booleanValue = $false }
      $fields.closedAt = Null-Field
    }
    purchaseHistory {
      $fields.listId = String-Field 'test-list'
      $fields.listName = String-Field $Name
      $fields.closedAt = $date
      $fields.items = Array-Field
      $fields.budget = Null-Field
      $fields.paymentBalances = Array-Field
    }
    catalog {
      $fields.name = String-Field $Name
      $fields.category = String-Field 'grains_pasta'
      $fields.unitPrice = @{ doubleValue = 10.5 }
      $fields.barcode = Null-Field
      $fields.usageCount = @{ integerValue = '1' }
      $fields.updatedAt = $date
      $fields.priceHistory = Array-Field
    }
    pantry {
      $fields.name = String-Field $Name
      $fields.catalogProductId = Null-Field
      $fields.category = String-Field 'grains_pasta'
      $fields.barcode = Null-Field
      $fields.unitPrice = @{ doubleValue = 10.5 }
      $fields.suggestedQuantity = @{ integerValue = '2' }
      $fields.status = String-Field 'in_stock'
      $fields.updatedAt = $date
      $fields.lastPurchasedAt = Null-Field
    }
    default { throw "Unknown entity type $Type" }
  }
  $fields
}

$owner = New-EmulatorUser owner
$adversary = New-EmulatorUser adversary
foreach ($type in @('lists', 'purchaseHistory', 'catalog', 'pantry')) {
  $collection = if ($type -eq 'purchaseHistory') { 'history' } else { $type }
  $id = "crud-$(New-Guid)"
  $uri = "$documentsUrl/users/$($owner.uid)/$collection/$id"
  $body = @{ fields = New-EntityFields $type $id 'Original' }
  Assert-Response (Request-Json PATCH $uri $body $owner.token) @(200) "$type owner creates"
  Assert-Response (Request-Json GET $uri $null $owner.token) @(200) "$type owner reads"
  Assert-Response (Request-Json GET $uri $null $adversary.token) @(403) "$type adversary cannot read"
  Assert-Response (Request-Json GET $uri $null '') @(403) "$type anonymous cannot read"

  $updated = @{ fields = New-EntityFields $type $id 'Atualizado' }
  Assert-Response (Request-Json PATCH $uri $updated $adversary.token) @(403) "$type adversary cannot update"
  Assert-Response (Request-Json DELETE $uri $null $adversary.token) @(403) "$type adversary cannot delete"
  Assert-Response (Request-Json PATCH $uri $updated $owner.token) @(200) "$type owner updates"
  $read = Request-Json GET $uri $null $owner.token
  Assert-Response $read @(200) "$type updated record is readable"
  $readNameField = if ($type -eq 'purchaseHistory') { 'listName' } else { 'name' }
  $persisted = ConvertFrom-Json $read.Content
  if ($persisted.fields.$readNameField.stringValue -ne 'Atualizado') {
    throw "$type update was acknowledged but not persisted"
  }
  Assert-Response (Request-Json DELETE $uri $null $owner.token) @(200) "$type owner deletes"
  Assert-Response (Request-Json GET $uri $null $owner.token) @(404) "$type deletion persists"

  # A fresh ID may be created normally; the original ID is locked by its marker.
  $markerUri = "$documentsUrl/users/$($owner.uid)/sync_deletions/$($type)_$id"
  $marker = @{ fields = @{
    entityType = String-Field $type
    entityId = String-Field $id
    deletedAt = @{ timestampValue = '2026-10-11T17:00:00.000Z' }
  } }
  Assert-Response (Request-Json PATCH $markerUri $marker $adversary.token) @(403) "$type adversary cannot create deletion marker"
  Assert-Response (Request-Json PATCH $markerUri $marker $owner.token) @(200) "$type owner creates durable deletion marker"
  Assert-Response (Request-Json GET $markerUri $null $owner.token) @(200) "$type owner reads deletion marker"
  Assert-Response (Request-Json GET $markerUri $null $adversary.token) @(403) "$type adversary cannot read marker"
  Assert-Response (Request-Json PATCH $uri $body $owner.token) @(403) "$type stale device cannot recreate permanently deleted ID"
  Assert-Response (Request-Json DELETE $markerUri $null $owner.token) @(403) "$type owner cannot erase deletion protection"
  Assert-Response (Request-Json DELETE $markerUri $null $adversary.token) @(403) "$type adversary cannot erase deletion protection"
  Assert-Response (Request-Json PATCH $uri $body $owner.token) @(403) "$type still protected after rejected marker deletion"

  $freshId = "fresh-$(New-Guid)"
  $freshUri = "$documentsUrl/users/$($owner.uid)/$collection/$freshId"
  $fresh = @{ fields = New-EntityFields $type $freshId 'Novo produto' }
  Assert-Response (Request-Json PATCH $freshUri $fresh $adversary.token) @(403) "$type adversary cannot create owner's record"
  Assert-Response (Request-Json PATCH $freshUri $fresh $owner.token) @(200) "$type owner can create another ID after deletion"

  $badMarkerUri = "$documentsUrl/users/$($owner.uid)/sync_deletions/$($type)_invalid-$(New-Guid)"
  Assert-Response (Request-Json PATCH $badMarkerUri $marker $owner.token) @(403) "$type marker ID must match entity ID"
}
Write-Host "Private CRUD rules: $script:passed assertions passed."
